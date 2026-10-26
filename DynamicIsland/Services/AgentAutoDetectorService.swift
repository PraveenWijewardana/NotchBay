import Foundation
import AppKit
import Darwin
import Combine
import SQLite3

// MARK: - Localhost SSL Trust Delegate
final class LocalhostTrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let host = challenge.protectionSpace.host
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              host == "127.0.0.1" || host == "localhost" || host == "::1",
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

// MARK: - Antigravity Language Server Bridge (CodeNotch Architecture)
final class AntigravityLanguageServerBridge: @unchecked Sendable {
    struct Endpoint: Equatable {
        let ports: [Int]
        let csrfToken: String?
    }
    
    private let session: URLSession
    private let lock = NSLock()
    private var cachedEndpoint: Endpoint?
    
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.timeoutIntervalForResource = 6
        self.session = URLSession(configuration: config, delegate: LocalhostTrustDelegate(), delegateQueue: nil)
    }
    
    /// Discovers language server PID and CSRF token via `ps`, then discovers listening ports via `lsof`.
    func discoverEndpoint() -> Endpoint? {
        lock.lock()
        if let cached = cachedEndpoint {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        // 1. Run /bin/ps -Ao pid,command to locate language_server
        let psProcess = Process()
        let psPipe = Pipe()
        psProcess.executableURL = URL(fileURLWithPath: "/bin/ps")
        psProcess.arguments = ["-Ao", "pid,command"]
        psProcess.standardOutput = psPipe
        psProcess.standardError = FileHandle.nullDevice
        
        guard (try? psProcess.run()) != nil else { return nil }
        let psData = psPipe.fileHandleForReading.readDataToEndOfFile()
        psProcess.waitUntilExit()
        
        guard let psOutput = String(data: psData, encoding: .utf8) else { return nil }
        let lines = psOutput.components(separatedBy: .newlines)
        
        var targetPid: Int?
        var csrfToken: String?
        
        for line in lines {
            if line.contains("language_server") && line.contains("--csrf_token") {
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ")
                if let pidStr = parts.first, let pid = Int(pidStr) {
                    targetPid = pid
                }
                if let idx = parts.firstIndex(of: "--csrf_token"), idx + 1 < parts.count {
                    csrfToken = String(parts[idx + 1])
                }
                break
            }
        }
        
        guard let pid = targetPid else { return nil }
        
        // 2. Run /usr/sbin/lsof -nP -a -p <pid> -iTCP -sTCP:LISTEN
        let lsofProcess = Process()
        let lsofPipe = Pipe()
        lsofProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsofProcess.arguments = ["-nP", "-a", "-p", "\(pid)", "-iTCP", "-sTCP:LISTEN"]
        lsofProcess.standardOutput = lsofPipe
        lsofProcess.standardError = FileHandle.nullDevice
        
        guard (try? lsofProcess.run()) != nil else { return nil }
        let lsofData = lsofPipe.fileHandleForReading.readDataToEndOfFile()
        lsofProcess.waitUntilExit()
        
        var ports: [Int] = []
        if let lsofOutput = String(data: lsofData, encoding: .utf8) {
            for line in lsofOutput.components(separatedBy: .newlines) {
                if let lastColon = line.split(separator: " ").last(where: { $0.contains(":") }),
                   let portStr = lastColon.split(separator: ":").last,
                   let port = Int(portStr) {
                    if !ports.contains(port) {
                        ports.append(port)
                    }
                }
            }
        }
        
        guard !ports.isEmpty else { return nil }
        let ep = Endpoint(ports: ports, csrfToken: csrfToken)
        
        lock.lock()
        self.cachedEndpoint = ep
        lock.unlock()
        return ep
    }
    
    /// Sends RPC POST to /exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary
    func fetchQuota() async -> (buckets: [QuotaBucket], plan: String)? {
        guard let endpoint = discoverEndpoint() else { return nil }
        
        let path = "/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary"
        
        for port in endpoint.ports {
            for scheme in ["https", "http"] {
                guard let url = URL(string: "\(scheme)://127.0.0.1:\(port)\(path)") else { continue }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token = endpoint.csrfToken {
                    request.setValue(token, forHTTPHeaderField: "x-codeium-csrf-token")
                }
                request.httpBody = Data(#"{"forceRefresh":true}"#.utf8)
                request.timeoutInterval = 4
                
                guard let (data, response) = try? await session.data(for: request),
                      (response as? HTTPURLResponse)?.statusCode == 200 else {
                    continue
                }
                
                if let parsed = parseQuotaResponse(data: data) {
                    return parsed
                }
            }
        }
        
        // If all candidate ports failed, invalidate cached endpoint to rediscover next time
        lock.lock()
        cachedEndpoint = nil
        lock.unlock()
        return nil
    }
    
    /// Parses the JSON response into QuotaBucket items and Plan Name
    private func parseQuotaResponse(data: Data) -> (buckets: [QuotaBucket], plan: String)? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        
        var planName = "Gemini 2.5 Pro"
        if let userStatus = json["userStatus"] as? [String: Any],
           let planStatus = userStatus["planStatus"] as? [String: Any],
           let plan = planStatus["planName"] as? String, !plan.isEmpty {
            planName = plan
        }
        
        // Find quota groups or buckets across varying RPC response shapes
        var rawGroups: [[String: Any]] = []
        if let userStatus = json["userStatus"] as? [String: Any],
           let quotaGroup = userStatus["quotaGroup"] as? [String: Any],
           let groups = quotaGroup["quotaGroups"] as? [[String: Any]] {
            rawGroups = groups
        } else if let resp = json["response"] as? [String: Any],
                  let groups = resp["groups"] as? [[String: Any]] {
            rawGroups = groups
        } else if let groups = json["groups"] as? [[String: Any]] {
            rawGroups = groups
        } else if let groups = json["quotaGroups"] as? [[String: Any]] {
            rawGroups = groups
        }
        
        var buckets: [QuotaBucket] = []
        let now = Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let fracFormatter = ISO8601DateFormatter()
        fracFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for group in rawGroups {
            let groupName = group["displayName"] as? String ?? "Gemini Models"
            guard let rawBuckets = group["buckets"] as? [[String: Any]] else { continue }
            
            for b in rawBuckets {
                let remainingFraction: Double?
                if let rem = b["remainingFraction"] as? Double {
                    remainingFraction = rem
                } else if let remDict = b["remaining"] as? [String: Any], let f = remDict["fraction"] as? Double {
                    remainingFraction = f
                } else {
                    remainingFraction = nil
                }
                
                guard let rem = remainingFraction, (0...1).contains(rem) else { continue }
                
                var resetDate: Date? = nil
                if let resetStr = b["resetTime"] as? String {
                    resetDate = isoFormatter.date(from: resetStr) ?? fracFormatter.date(from: resetStr)
                }
                
                let windowStr = (b["window"] as? String)?.lowercased() ?? ""
                let bucketId = (b["bucketId"] as? String)?.lowercased() ?? ""
                let isWeekly: Bool
                if windowStr.contains("week") || bucketId.contains("week") {
                    isWeekly = true
                } else if let resetDate = resetDate {
                    isWeekly = resetDate.timeIntervalSince(now) > 24 * 3600
                } else {
                    isWeekly = false
                }
                
                let id = isWeekly ? "gemini-weekly" : "gemini-5h"
                let label = isWeekly ? "Weekly Limit" : "5-hour Limit"
                let duration: TimeInterval = isWeekly ? 7 * 86400 : 5 * 3600
                let used = max(0.0, min(1.0, 1.0 - rem))
                
                buckets.append(
                    QuotaBucket(
                        id: id,
                        modelGroup: groupName,
                        label: label,
                        usedFraction: used,
                        remainingFraction: rem,
                        resetsAt: resetDate,
                        duration: duration
                    )
                )
            }
        }
        
        return (buckets, planName)
    }
}

// MARK: - Agent Auto-Detector Service
@MainActor
public final class AgentAutoDetectorService: ObservableObject {
    private weak var companion: AgentCompanionService?
    
    private var monitorTimer: Timer?
    private var usageTimer: Timer?
    private var lastAntigravityStepIndex: Int = -1
    private var lastAntigravityStatus: String = ""
    private var lastActiveAgent: CodeAgentType?
    private var isScanningUsage: Bool = false
    
    // Language Server loopback RPC bridge
    private let languageServerBridge = AntigravityLanguageServerBridge()
    
    // Process CPU history to detect active vs. idle state
    private var previousCpuTimes: [pid_t: UInt64] = [:]
    private var consecutiveIdleTicks: [CodeAgentType: Int] = [:]
    
    // File paths
    private let homeDir = FileManager.default.homeDirectoryForCurrentUser
    private var lastTranscriptModDate: Date?
    
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
    
    // MARK: - 1. Antigravity Brain Logs Monitor (CodeNotch stat() Architecture)
    private func checkAntigravityBrainLogs() -> Bool {
        let brainUrl = homeDir.appendingPathComponent(".gemini/antigravity/brain")
        guard FileManager.default.fileExists(atPath: brainUrl.path) else { return false }
        
        guard let conversations = try? FileManager.default.contentsOfDirectory(
            at: brainUrl,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return false }
        
        var newestTranscript: (path: String, convId: String, modified: Date)?
        
        for conv in conversations {
            let path = conv.path + "/.system_generated/logs/transcript.jsonl"
            var info = stat()
            guard stat(path, &info) == 0 else { continue }
            
            let mtime = Date(timeIntervalSince1970:
                TimeInterval(info.st_mtimespec.tv_sec) +
                TimeInterval(info.st_mtimespec.tv_nsec) / 1_000_000_000
            )
            
            if newestTranscript == nil || mtime > newestTranscript!.modified {
                newestTranscript = (path, conv.lastPathComponent, mtime)
            }
        }
        
        guard let newest = newestTranscript else { return false }
        let now = Date()
        let elapsed = now.timeIntervalSince(newest.modified)
        
        // If modified within the last 45 seconds, inspect state
        if elapsed <= 45 {
            if lastTranscriptModDate == nil || newest.modified > lastTranscriptModDate! {
                lastTranscriptModDate = newest.modified
                parseTranscriptTail(path: newest.path, convId: newest.convId, modifiedDate: newest.modified)
            }
            return true
        } else if let prevMod = lastTranscriptModDate, elapsed > 45, companion?.status.isBusy == true {
            // Idle transition after run finishes
            companion?.updateSilentStatus(agent: .antigravity, status: .idle, message: "Connected & Ready")
            lastTranscriptModDate = nil
        }
        
        return false
    }
    
    private func parseTranscriptTail(path: String, convId: String, modifiedDate: Date) {
        guard let handle = FileHandle(forReadingAtPath: path) else { return }
        defer { try? handle.close() }
        
        let fileSize = handle.seekToEndOfFile()
        guard fileSize > 0 else { return }
        
        // Read up to last 32KB of transcript
        let readLen = min(fileSize, 32768)
        handle.seek(toFileOffset: fileSize - readLen)
        let data = handle.readDataToEndOfFile()
        
        guard let string = String(data: data, encoding: .utf8) else { return }
        let lines = string.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Also check conversations/<convId>.db for pending permission (status == 2 in steps)
        let dbUrl = homeDir.appendingPathComponent(".gemini/antigravity/conversations/\(convId).db")
        if FileManager.default.fileExists(atPath: dbUrl.path) {
            var db: OpaquePointer?
            if sqlite3_open_v2(dbUrl.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                defer { sqlite3_close(db) }
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, "SELECT status FROM steps ORDER BY idx DESC LIMIT 1", -1, &stmt, nil) == SQLITE_OK {
                    if sqlite3_step(stmt) == SQLITE_ROW {
                        let stepStatus = sqlite3_column_int(stmt, 0)
                        if stepStatus == 2 {
                            companion?.requestPermission(agent: .antigravity, actionOrTool: "Action Approval", detail: "Approval required to proceed")
                            sqlite3_finalize(stmt)
                            return
                        }
                    }
                    sqlite3_finalize(stmt)
                }
            }
        }
        
        guard let lastLine = lines.last,
              let lineData = lastLine.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: lineData)) as? [String: Any] else { return }
        
        let stepIndex = json["step_index"] as? Int ?? 0
        let type = json["type"] as? String ?? ""
        let status = json["status"] as? String ?? ""
        
        if stepIndex == lastAntigravityStepIndex && status == lastAntigravityStatus {
            return
        }
        lastAntigravityStepIndex = stepIndex
        lastAntigravityStatus = status
        
        if type == "PLANNER_RESPONSE" {
            let toolCalls = json["tool_calls"] as? [[String: Any]] ?? []
            let content = (json["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if status == "DONE" && toolCalls.isEmpty && !content.isEmpty {
                let shortMsg = String(content.prefix(120))
                companion?.completeTask(agent: .antigravity, message: shortMsg)
            } else if let firstTool = toolCalls.first {
                let toolAction = firstTool["toolAction"] as? String
                let toolSummary = firstTool["toolSummary"] as? String
                let toolName = firstTool["name"] as? String ?? "tool"
                let actionText = toolAction ?? toolSummary ?? "Executing \(toolName)"
                
                // Permission detection
                var needsApproval = toolName.contains("ask_question") || toolName.contains("permission")
                if !needsApproval, let args = firstTool["arguments"] as? [String: Any],
                   let meta = args["ArtifactMetadata"] as? [String: Any],
                   meta["RequestFeedback"] as? Bool == true {
                    needsApproval = true
                }
                
                if needsApproval {
                    companion?.requestPermission(agent: .antigravity, actionOrTool: actionText, detail: "User approval requested")
                } else {
                    companion?.setWorking(agent: .antigravity, status: .executing, message: actionText)
                }
            } else {
                companion?.setWorking(agent: .antigravity, status: .thinking, message: "Synthesizing solution...")
            }
        } else if type == "USER_INPUT" {
            companion?.setWorking(agent: .antigravity, status: .thinking, message: "Analyzing user prompt...")
        }
    }
    
    // MARK: - 2. AI Usage Scanner (CodeNotch Bridge + stat() Implementation)
    public func scanUsageMetrics() {
        guard !isScanningUsage else { return }
        isScanningUsage = true
        
        let home = self.homeDir
        let bridge = self.languageServerBridge
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            defer {
                Task { @MainActor [weak self] in
                    self?.isScanningUsage = false
                }
            }
            
            // Step 1: Query Language Server RPC for live quota buckets
            var quotaBuckets: [QuotaBucket] = []
            var detectedPlan = "Gemini 2.5 Pro"
            
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                if let result = await bridge.fetchQuota() {
                    quotaBuckets = result.buckets
                    detectedPlan = result.plan
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 4.5)
            
            // Step 2: Accurate stat()-based transcript scanner for today's model turns
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
                    atPath: root.path
                ) else { continue }
                
                for trajName in trajectories {
                    let transcriptPath = root.appendingPathComponent(trajName).appendingPathComponent(".system_generated/logs/transcript.jsonl").path
                    var info = stat()
                    guard stat(transcriptPath, &info) == 0 else { continue }
                    
                    totalTrajCount += 1
                    
                    let mtime = Date(timeIntervalSince1970:
                        TimeInterval(info.st_mtimespec.tv_sec) +
                        TimeInterval(info.st_mtimespec.tv_nsec) / 1_000_000_000
                    )
                    
                    if latestDate == nil || mtime > latestDate! {
                        latestDate = mtime
                    }
                    
                    // If transcript was modified today:
                    if calendar.isDate(mtime, inSameDayAs: now) {
                        activeTodaySessions += 1
                        
                        guard let text = try? String(contentsOfFile: transcriptPath, encoding: .utf8) else { continue }
                        for line in text.split(separator: "\n") {
                            guard line.contains("\"MODEL\"") else { continue }
                            guard let data = line.data(using: .utf8),
                                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                                  json["source"] as? String == "MODEL" else { continue }
                            
                            todayCount += 1
                            if let atStr = json["created_at"] as? String {
                                let parsed = isoFormatter.date(from: atStr) ?? fracFormatter.date(from: atStr)
                                if let parsed = parsed, (latestDate == nil || parsed > latestDate!) {
                                    latestDate = parsed
                                }
                            }
                        }
                    }
                }
            }
            
            // Step 3: Extract 5-hour and weekly quota buckets
            let fiveHourBucket = quotaBuckets.first(where: { $0.id.contains("5h") || $0.id.contains("hourly") })
            let weeklyBucket = quotaBuckets.first(where: { $0.id.contains("weekly") })
            
            Task { @MainActor [weak self] in
                guard let self = self, let comp = self.companion else { return }
                var metrics = comp.usageMetrics
                metrics.requestsToday = todayCount
                metrics.totalRequests = totalTrajCount
                if let latest = latestDate {
                    metrics.lastRequestDate = latest
                }
                metrics.activeSessionsCount = activeTodaySessions
                metrics.quotaBuckets = quotaBuckets
                metrics.planName = detectedPlan
                
                if let fh = fiveHourBucket {
                    metrics.fiveHourRemainingFraction = fh.remainingFraction
                    metrics.fiveHourUsedFraction = fh.usedFraction
                    metrics.fiveHourResetDate = fh.resetsAt
                }
                if let wb = weeklyBucket {
                    metrics.weeklyRemainingFraction = wb.remainingFraction
                    metrics.weeklyUsedFraction = wb.usedFraction
                    metrics.weeklyResetDate = wb.resetsAt
                }
                
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
            
            let currentCpu = getProcessCpuTime(pid: pid)
            let prevCpu = previousCpuTimes[pid] ?? currentCpu
            previousCpuTimes[pid] = currentCpu
            
            let delta = currentCpu > prevCpu ? currentCpu - prevCpu : 0
            
            if delta > 15_000_000 { // ~15ms CPU time in 2.0s
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
        
        if previousCpuTimes.count > 100 {
            previousCpuTimes.removeAll(keepingCapacity: true)
        }
        
        if let (activeAgent, desc) = activeAgentRunning {
            if companion?.status != .awaitingPermission {
                companion?.setWorking(agent: activeAgent, status: .executing, message: desc)
            }
            lastActiveAgent = activeAgent
        } else if let prev = lastActiveAgent {
            let idleCount = (consecutiveIdleTicks[prev] ?? 0) + 1
            consecutiveIdleTicks[prev] = idleCount
            
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
