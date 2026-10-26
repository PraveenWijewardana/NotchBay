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

// MARK: - Antigravity Language Server Bridge (CodeNotch Architecture - Cached & Low Overhead)
final class AntigravityLanguageServerBridge: @unchecked Sendable {
    struct Endpoint: Equatable {
        let ports: [Int]
        let csrfToken: String?
    }
    
    private let session: URLSession
    private let lock = NSLock()
    private var cachedEndpoint: Endpoint?
    private var lastProbeTime: Date = .distantPast
    private var cachedResult: (buckets: [QuotaBucket], plan: String)? = nil
    private var lastResultTime: Date = .distantPast
    
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 4
        self.session = URLSession(configuration: config, delegate: LocalhostTrustDelegate(), delegateQueue: nil)
    }
    
    /// Discovers language server PID and CSRF token via `ps`, then discovers listening ports via `lsof`.
    /// Cached to avoid repetitive process spawning.
    func discoverEndpoint() -> Endpoint? {
        lock.lock()
        if let cached = cachedEndpoint {
            lock.unlock()
            return cached
        }
        // Rate-limit discovery attempts to at most once every 30 seconds if failed
        if Date().timeIntervalSince(lastProbeTime) < 30 {
            lock.unlock()
            return nil
        }
        lastProbeTime = Date()
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
    func fetchQuota(force: Bool = false) async -> (buckets: [QuotaBucket], plan: String)? {
        lock.lock()
        if !force, let cached = cachedResult, Date().timeIntervalSince(lastResultTime) < 45 {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
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
                request.timeoutInterval = 3
                
                guard let (data, response) = try? await session.data(for: request),
                      (response as? HTTPURLResponse)?.statusCode == 200 else {
                    continue
                }
                
                if let parsed = parseQuotaResponse(data: data) {
                    lock.lock()
                    self.cachedResult = parsed
                    self.lastResultTime = Date()
                    lock.unlock()
                    return parsed
                }
            }
        }
        
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

// MARK: - Agent Auto-Detector Service (Ultra-Low CPU Architecture)
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
    
    // Fast path cached transcript
    private let homeDir = FileManager.default.homeDirectoryForCurrentUser
    private var cachedNewestTranscriptPath: String?
    private var cachedNewestConvId: String?
    private var lastTranscriptModDate: Date?
    private var lastFullScanDate: Date = .distantPast
    
    public init(companion: AgentCompanionService) {
        self.companion = companion
    }
    
    public func start() {
        stop()
        
        // 1. Monitor active session & processes every 3.0 seconds (with 0.5s tolerance for OS power-coalescing)
        let mTimer = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performMonitoringTick()
            }
        }
        mTimer.tolerance = 0.5
        RunLoop.main.add(mTimer, forMode: .common)
        monitorTimer = mTimer
        
        // 2. Scan AI Usage every 60.0 seconds (with 5.0s tolerance)
        let uTimer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scanUsageMetrics()
            }
        }
        uTimer.tolerance = 5.0
        RunLoop.main.add(uTimer, forMode: .common)
        usageTimer = uTimer
        
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
        let antigravityDetected = checkAntigravityBrainLogs()
        checkRunningAgentProcesses(antigravityHandledByLogs: antigravityDetected)
    }
    
    // MARK: - 1. Fast Antigravity Transcript Monitor (<0.1ms per tick)
    private func checkAntigravityBrainLogs() -> Bool {
        let now = Date()
        
        // Fast-path: Check our cached active transcript directly (1 single stat syscall)
        if let cachedPath = cachedNewestTranscriptPath, let convId = cachedNewestConvId {
            var cachedInfo = stat()
            if stat(cachedPath, &cachedInfo) == 0 {
                let mtime = Date(timeIntervalSince1970:
                    TimeInterval(cachedInfo.st_mtimespec.tv_sec) +
                    TimeInterval(cachedInfo.st_mtimespec.tv_nsec) / 1_000_000_000
                )
                let elapsed = now.timeIntervalSince(mtime)
                if elapsed <= 45 {
                    if lastTranscriptModDate == nil || mtime > lastTranscriptModDate! {
                        lastTranscriptModDate = mtime
                        parseTranscriptTail(path: cachedPath, convId: convId, modifiedDate: mtime)
                    }
                    return true
                } else if elapsed > 45, companion?.status.isBusy == true {
                    companion?.updateSilentStatus(agent: .antigravity, status: .idle, message: "Connected & Ready")
                    lastTranscriptModDate = nil
                }
            }
        }
        
        // Full directory scan is only executed at most once every 10 seconds when no active turn is in flight
        guard now.timeIntervalSince(lastFullScanDate) >= 10 else {
            return false
        }
        lastFullScanDate = now
        
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
        cachedNewestTranscriptPath = newest.path
        cachedNewestConvId = newest.convId
        
        let elapsed = now.timeIntervalSince(newest.modified)
        if elapsed <= 45 {
            if lastTranscriptModDate == nil || newest.modified > lastTranscriptModDate! {
                lastTranscriptModDate = newest.modified
                parseTranscriptTail(path: newest.path, convId: newest.convId, modifiedDate: newest.modified)
            }
            return true
        }
        
        return false
    }
    
    private func parseTranscriptTail(path: String, convId: String, modifiedDate: Date) {
        guard let handle = FileHandle(forReadingAtPath: path) else { return }
        defer { try? handle.close() }
        
        let fileSize = handle.seekToEndOfFile()
        guard fileSize > 0 else { return }
        
        // Read only the last 16KB of transcript to minimize heap allocation
        let readLen = min(fileSize, 16384)
        handle.seek(toFileOffset: fileSize - readLen)
        let data = handle.readDataToEndOfFile()
        
        guard let string = String(data: data, encoding: .utf8) else { return }
        let lines = string.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Check conversations/<convId>.db for pending permission (status == 2 in steps)
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
    
    // MARK: - 2. AI Usage Scanner (Low Memory & Low CPU)
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
            _ = semaphore.wait(timeout: .now() + 3.0)
            
            // Step 2: Accurate stat()-based transcript scanner using streaming chunk reading
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
                    
                    // If transcript was modified today, count model turns with low memory buffer
                    if calendar.isDate(mtime, inSameDayAs: now) {
                        activeTodaySessions += 1
                        
                        guard let handle = FileHandle(forReadingAtPath: transcriptPath) else { continue }
                        let size = handle.seekToEndOfFile()
                        let readBytes = min(size, 65536) // Read up to 64KB
                        handle.seek(toFileOffset: size - readBytes)
                        let data = handle.readDataToEndOfFile()
                        try? handle.close()
                        
                        if let text = String(data: data, encoding: .utf8) {
                            for line in text.split(separator: "\n") {
                                if line.contains("\"MODEL\"") {
                                    todayCount += 1
                                }
                            }
                        }
                    }
                }
            }
            
            let fiveHourBucket = quotaBuckets.first(where: { $0.id.contains("5h") || $0.id.contains("hourly") })
            let weeklyBucket = quotaBuckets.first(where: { $0.id.contains("weekly") })
            
            Task { @MainActor [weak self] in
                guard let self = self, let comp = self.companion else { return }
                var metrics = comp.usageMetrics
                metrics.requestsToday = max(metrics.requestsToday, todayCount)
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
                
                metrics.dailyTarget = max(500, ((metrics.requestsToday / 100) + 1) * 100)
                comp.usageMetrics = metrics
            }
        }
    }
    
    // MARK: - 3. Targeted Running Process Table Scanner (Zero PID Loop)
    private func checkRunningAgentProcesses(antigravityHandledByLogs: Bool) {
        // Fast path: inspect only running GUI applications via NSWorkspace (0 system calls)
        let runningApps = NSWorkspace.shared.runningApplications
        
        var activeAgentRunning: (CodeAgentType, String)? = nil
        
        for app in runningApps {
            let id = app.bundleIdentifier?.lowercased() ?? ""
            let name = app.localizedName?.lowercased() ?? ""
            
            let agent: CodeAgentType?
            if id.contains("claude") || name == "claude" {
                agent = .claude
            } else if id.contains("cursor") || name.contains("cursor") {
                agent = .cursor
            } else if id.contains("copilot") || name.contains("copilot") {
                agent = .copilot
            } else if !antigravityHandledByLogs && (name.contains("antigravity") || name == "agy") {
                agent = .antigravity
            } else {
                agent = nil
            }
            
            guard let matchedAgent = agent else { continue }
            let pid = app.processIdentifier
            
            let currentCpu = getProcessCpuTime(pid: pid)
            let prevCpu = previousCpuTimes[pid] ?? currentCpu
            previousCpuTimes[pid] = currentCpu
            
            let delta = currentCpu > prevCpu ? currentCpu - prevCpu : 0
            
            if delta > 20_000_000 { // ~20ms CPU in 3s
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
                break
            }
        }
        
        if previousCpuTimes.count > 50 {
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
