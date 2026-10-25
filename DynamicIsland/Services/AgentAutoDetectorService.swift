import Foundation
import AppKit
import Darwin
import Combine

/// AgentAutoDetectorService automatically monitors local coding assistant processes
/// (Antigravity, Claude Code, Cursor, GitHub Copilot) and local session logs
/// without requiring manual terminal curl commands — similar to CodeNotch.
@MainActor
public final class AgentAutoDetectorService: ObservableObject {
    private weak var companion: AgentCompanionService?
    
    private var monitorTimer: Timer?
    private var usageTimer: Timer?
    private var lastAntigravityStepIndex: Int = -1
    private var lastAntigravityStatus: String = ""
    private var lastActiveAgent: CodeAgentType?
    private var isScanningUsage: Bool = false
    
    // Process CPU history to detect active vs. idle state
    private var previousCpuTimes: [pid_t: UInt64] = [:]
    private var consecutiveIdleTicks: [CodeAgentType: Int] = [:]
    
    // File paths
    private let homeDir = FileManager.default.homeDirectoryForCurrentUser
    private var lastBrainFolderUrl: URL?
    private var lastTranscriptModDate: Date?
    private var lastBrainFolderModDate: Date?
    
    public init(companion: AgentCompanionService) {
        self.companion = companion
    }
    
    public func start() {
        stop()
        
        // Poll process & transcript state every 2.0 seconds with low overhead
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performMonitoringTick()
            }
        }
        
        // Scan AI Usage every 6.0 seconds in background
        usageTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scanUsageMetrics()
            }
        }
        
        performMonitoringTick()
        scanUsageMetrics()
    }
    
    public func stop() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        usageTimer?.invalidate()
        usageTimer = nil
    }
    
    // MARK: - Main Monitoring Tick
    private func performMonitoringTick() {
        // 1. Check Antigravity live transcript / brain logs
        let antigravityDetected = checkAntigravityBrainLogs()
        
        // 2. Scan running process table for Claude, Cursor, Copilot, Antigravity
        checkRunningAgentProcesses(antigravityHandledByLogs: antigravityDetected)
    }
    
    // MARK: - 1. Antigravity Brain Logs Monitor
    private func checkAntigravityBrainLogs() -> Bool {
        let brainUrl = homeDir.appendingPathComponent(".gemini/antigravity/brain")
        guard FileManager.default.fileExists(atPath: brainUrl.path) else { return false }
        
        let brainAttrs = try? FileManager.default.attributesOfItem(atPath: brainUrl.path)
        let brainModDate = brainAttrs?[.modificationDate] as? Date
        
        if let brainModDate = brainModDate, let lastBrainMod = lastBrainFolderModDate, brainModDate <= lastBrainMod, let cachedConv = lastBrainFolderUrl {
            let transcriptUrl = cachedConv.appendingPathComponent(".system_generated/logs/transcript.jsonl")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: transcriptUrl.path),
               let modDate = attrs[.modificationDate] as? Date {
                if lastTranscriptModDate == nil || modDate > lastTranscriptModDate! {
                    lastTranscriptModDate = modDate
                    parseTranscriptTail(url: transcriptUrl)
                    return true
                }
            }
            return true
        }
        lastBrainFolderModDate = brainModDate
        
        // Find most recently modified conversation folder
        guard let conversations = try? FileManager.default.contentsOfDirectory(
            at: brainUrl,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return false }
        
        let sorted = conversations.compactMap { url -> (URL, Date)? in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let date = values.contentModificationDate else { return nil }
            return (url, date)
        }.sorted { $0.1 > $1.1 }
        
        guard let (latestConvUrl, _) = sorted.first else { return false }
        lastBrainFolderUrl = latestConvUrl
        
        let transcriptUrl = latestConvUrl.appendingPathComponent(".system_generated/logs/transcript.jsonl")
        guard FileManager.default.fileExists(atPath: transcriptUrl.path) else { return false }
        
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: transcriptUrl.path),
              let modDate = attrs[.modificationDate] as? Date else { return false }
        
        if lastTranscriptModDate == nil || modDate > lastTranscriptModDate! {
            lastTranscriptModDate = modDate
            parseTranscriptTail(url: transcriptUrl)
            return true
        }
        
        return true
    }
    
    private func parseTranscriptTail(url: URL) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        
        let fileSize = handle.seekToEndOfFile()
        guard fileSize > 0 else { return }
        
        // Read up to last 16KB of the transcript
        let readLen = min(fileSize, 16384)
        handle.seek(toFileOffset: fileSize - readLen)
        let data = handle.readDataToEndOfFile()
        
        guard let string = String(data: data, encoding: .utf8) else { return }
        let lines = string.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let lastLine = lines.last,
              let lineData = lastLine.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: lineData)) as? [String: Any] else { return }
        
        let stepIndex = json["step_index"] as? Int ?? 0
        let type = json["type"] as? String ?? ""
        let status = json["status"] as? String ?? ""
        
        // Avoid duplicate triggers for identical step index & status
        if stepIndex == lastAntigravityStepIndex && status == lastAntigravityStatus {
            return
        }
        lastAntigravityStepIndex = stepIndex
        lastAntigravityStatus = status
        
        if type == "PLANNER_RESPONSE" {
            let toolCalls = json["tool_calls"] as? [[String: Any]] ?? []
            let content = (json["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if status == "DONE" && toolCalls.isEmpty && !content.isEmpty {
                // Genuine final task completion -> FINISH state
                let shortMsg = String(content.prefix(120))
                companion?.completeTask(agent: .antigravity, message: shortMsg)
            } else if let firstTool = toolCalls.first {
                let toolAction = firstTool["toolAction"] as? String
                let toolSummary = firstTool["toolSummary"] as? String
                let toolName = firstTool["name"] as? String ?? "tool"
                let actionText = toolAction ?? toolSummary ?? "Executing \(toolName)"
                
                // If interactive confirmation/decision is needed -> REQUEST PERMISSION state
                if toolName.contains("ask_question") || toolName.contains("permission") {
                    companion?.requestPermission(agent: .antigravity, actionOrTool: actionText, detail: "User approval requested")
                } else {
                    // Tool is running -> WAIT / EXECUTING state
                    companion?.setWorking(agent: .antigravity, status: .executing, message: actionText)
                }
            } else {
                // Thinking / generating -> WAIT / THINKING state
                companion?.setWorking(agent: .antigravity, status: .thinking, message: "Synthesizing solution...")
            }
        } else if type == "USER_INPUT" {
            // User submitted message -> WAIT / THINKING state
            companion?.setWorking(agent: .antigravity, status: .thinking, message: "Analyzing user prompt...")
        }
    }
    
    // MARK: - 2. AI Usage Scanner (CodeNotch Implementation)
    public func scanUsageMetrics() {
        guard !isScanningUsage else { return }
        isScanningUsage = true
        
        let home = self.homeDir
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            defer {
                Task { @MainActor [weak self] in
                    self?.isScanningUsage = false
                }
            }
            
            let geminiDir = home.appendingPathComponent(".gemini")
            let names = (try? FileManager.default.contentsOfDirectory(atPath: geminiDir.path)) ?? []
            let brainRoots = names
                .filter { $0.hasPrefix("antigravity") }
                .map { geminiDir.appendingPathComponent($0).appendingPathComponent("brain") }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            
            var todayCount = 0
            var totalTrajCount = 0
            var latestDate: Date?
            var activeTodaySessions = 0
            let calendar = Calendar.current
            let now = Date()
            
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            let fracFormatter = ISO8601DateFormatter()
            fracFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            for root in brainRoots {
                guard let trajectories = try? FileManager.default.contentsOfDirectory(
                    at: root, includingPropertiesForKeys: [.contentModificationDateKey]
                ) else { continue }
                
                totalTrajCount += trajectories.count
                
                for traj in trajectories {
                    guard let vals = try? traj.resourceValues(forKeys: [.contentModificationDateKey]),
                          let mdate = vals.contentModificationDate else { continue }
                    
                    // Fast filter: only examine trajectories modified today
                    if calendar.isDate(mdate, inSameDayAs: now) {
                        activeTodaySessions += 1
                        let transcript = traj.appendingPathComponent(".system_generated/logs/transcript.jsonl")
                        guard let text = try? String(contentsOf: transcript, encoding: .utf8) else { continue }
                        
                        for line in text.split(separator: "\n") {
                            guard line.contains("\"MODEL\"") else { continue }
                            guard let data = line.data(using: .utf8),
                                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                                  json["source"] as? String == "MODEL" else { continue }
                            
                            todayCount += 1
                            if let atStr = json["created_at"] as? String {
                                let parsed = isoFormatter.date(from: atStr) ?? fracFormatter.date(from: atStr)
                                if let parsed = parsed {
                                    if latestDate == nil || parsed > latestDate! {
                                        latestDate = parsed
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Task { @MainActor [weak self] in
                guard let self = self, let comp = self.companion else { return }
                var metrics = comp.usageMetrics
                metrics.requestsToday = todayCount
                metrics.totalRequests = totalTrajCount
                if let latest = latestDate {
                    metrics.lastRequestDate = latest
                }
                metrics.activeSessionsCount = activeTodaySessions
                metrics.dailyTarget = max(500, ((todayCount / 100) + 1) * 100)
                comp.usageMetrics = metrics
            }
        }
    }
    
    // MARK: - 3. Running Process Table Scanner
    private func checkRunningAgentProcesses(antigravityHandledByLogs: Bool) {
        var pids = [pid_t](repeating: 0, count: 2048)
        let bytesUsed = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(MemoryLayout<pid_t>.size * pids.count))
        guard bytesUsed > 0 else { return }
        let count = Int(bytesUsed) / MemoryLayout<pid_t>.size
        
        var detectedAgents: Set<CodeAgentType> = []
        var activeAgentRunning: (CodeAgentType, String)? = nil
        
        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0 else { continue }
            
            var nameBuffer = [CChar](repeating: 0, count: 256)
            let nameLen = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            guard nameLen > 0 else { continue }
            
            let name = String(cString: nameBuffer).lowercased()
            
            let agent: CodeAgentType?
            if name == "claude" {
                agent = .claude
            } else if name.contains("cursor") {
                agent = .cursor
            } else if name.contains("copilot-runtime") || name.contains("copilot") {
                agent = .copilot
            } else if !antigravityHandledByLogs && (name.contains("antigravity") || name == "agy") {
                agent = .antigravity
            } else {
                agent = nil
            }
            
            guard let matchedAgent = agent else { continue }
            detectedAgents.insert(matchedAgent)
            
            // Check process CPU usage to detect active coding / thinking
            let currentCpu = getProcessCpuTime(pid: pid)
            let prevCpu = previousCpuTimes[pid] ?? currentCpu
            previousCpuTimes[pid] = currentCpu
            
            let delta = currentCpu > prevCpu ? currentCpu - prevCpu : 0
            
            // If delta > 0, process consumed CPU in the last interval
            if delta > 15_000_000 { // ~15ms of CPU time in 2.0s interval
                let activityDesc: String
                switch matchedAgent {
                case .claude:
                    activityDesc = "Claude Code is executing..."
                case .cursor:
                    activityDesc = "Cursor AI generating edits..."
                case .copilot:
                    activityDesc = "Copilot runtime predicting code..."
                case .antigravity:
                    activityDesc = "Antigravity generating response..."
                }
                activeAgentRunning = (matchedAgent, activityDesc)
                consecutiveIdleTicks[matchedAgent] = 0
            }
        }
        
        // Clean up old PIDs from cpu history
        if previousCpuTimes.count > 100 {
            previousCpuTimes.removeAll(keepingCapacity: true)
        }
        
        // If an agent is actively computing:
        if let (activeAgent, desc) = activeAgentRunning {
            if companion?.status != .awaitingPermission {
                companion?.setWorking(agent: activeAgent, status: .executing, message: desc)
            }
            lastActiveAgent = activeAgent
        } else if let prev = lastActiveAgent {
            let idleCount = (consecutiveIdleTicks[prev] ?? 0) + 1
            consecutiveIdleTicks[prev] = idleCount
            
            // Mark idle silently in dashboard after active session ends
            if idleCount >= 2 {
                companion?.updateSilentStatus(agent: prev, status: .idle, message: "Idle & Ready")
                lastActiveAgent = nil
            }
        }
    }
    
    private func getProcessCpuTime(pid: pid_t) -> UInt64 {
        var taskInfo = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.stride
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))
        if result == size {
            return taskInfo.pti_total_user + taskInfo.pti_total_system
        }
        return 0
    }
}
