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
    private var lastAntigravityStepIndex: Int = -1
    private var lastAntigravityStatus: String = ""
    private var lastActiveAgent: CodeAgentType?
    
    // Process CPU history to detect active vs. idle state
    private var previousCpuTimes: [pid_t: UInt64] = [:]
    private var consecutiveIdleTicks: [CodeAgentType: Int] = [:]
    
    // File paths
    private let homeDir = FileManager.default.homeDirectoryForCurrentUser
    private var lastBrainFolderUrl: URL?
    private var lastTranscriptModDate: Date?
    
    public init(companion: AgentCompanionService) {
        self.companion = companion
    }
    
    public func start() {
        stop()
        // Poll every 1.5 seconds for instant response with <0.1% CPU overhead
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performMonitoringTick()
            }
        }
        performMonitoringTick()
    }
    
    public func stop() {
        monitorTimer?.invalidate()
        monitorTimer = nil
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
        
        let transcriptUrl = latestConvUrl.appendingPathComponent(".system_generated/logs/transcript.jsonl")
        guard FileManager.default.fileExists(atPath: transcriptUrl.path) else { return false }
        
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: transcriptUrl.path),
              let modDate = attrs[.modificationDate] as? Date else { return false }
        
        // If file was modified recently or date changed
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
        
        // Read up to last 8KB of the transcript
        let readLen = min(fileSize, 8192)
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
        
        // Avoid duplicate triggers for same step & status
        if stepIndex == lastAntigravityStepIndex && status == lastAntigravityStatus {
            return
        }
        lastAntigravityStepIndex = stepIndex
        lastAntigravityStatus = status
        
        if type == "PLANNER_RESPONSE" {
            let toolCalls = json["tool_calls"] as? [[String: Any]] ?? []
            let content = (json["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if status == "DONE" && toolCalls.isEmpty && !content.isEmpty {
                // Genuine final task completion
                let shortMsg = String(content.prefix(120))
                companion?.completeTask(agent: .antigravity, message: shortMsg)
            } else if let firstTool = toolCalls.first {
                let toolAction = firstTool["toolAction"] as? String
                let toolSummary = firstTool["toolSummary"] as? String
                let toolName = firstTool["name"] as? String ?? "tool"
                let actionText = toolAction ?? toolSummary ?? "Executing \(toolName)"
                
                // ONLY notify if user action/decision is required
                if toolName.contains("ask_question") {
                    companion?.requestPermission(agent: .antigravity, actionOrTool: actionText, detail: "User action needed")
                } else {
                    // Update silently in background for dashboard log — NO HUD notification for command runs
                    companion?.updateSilentStatus(agent: .antigravity, status: .coding, message: actionText)
                }
            } else {
                companion?.updateSilentStatus(agent: .antigravity, status: .thinking, message: "Synthesizing solution...")
            }
        } else if type == "USER_INPUT" {
            companion?.updateSilentStatus(agent: .antigravity, status: .thinking, message: "Analyzing user request...")
        }
    }
    
    // MARK: - 2. Running Process Table Scanner
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
            } else if !antigravityHandledByLogs && name.contains("antigravity") {
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
            
            // If delta > 0, process consumed CPU in the last 1.5s
            if delta > 15_000_000 { // ~15ms of CPU time in 1.5s interval
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
                companion?.updateSilentStatus(agent: activeAgent, status: .executing, message: desc)
            }
            lastActiveAgent = activeAgent
        } else if let prev = lastActiveAgent {
            let idleCount = (consecutiveIdleTicks[prev] ?? 0) + 1
            consecutiveIdleTicks[prev] = idleCount
            
            // Mark idle silently in dashboard without triggering false completion popups
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
