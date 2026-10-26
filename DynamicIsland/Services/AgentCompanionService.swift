import Foundation
import AppKit
import Network
import Combine

@MainActor
public final class AgentCompanionService: ObservableObject {
    @Published public var selectedAgent: CodeAgentType = .antigravity
    @Published public var status: AgentExecutionStatus = .idle
    @Published public var currentMessage: String = "Connected & Ready"
    @Published public var activePermissionRequest: AgentPermissionRequest? = nil
    @Published public var activityLog: [AgentActivityItem] = []
    @Published public var isServerRunning: Bool = false
    @Published public var usageMetrics: AgentUsageMetrics = AgentUsageMetrics()
    @Published public var turnElapsedSeconds: Int = 0
    
    private var tcpListener: NWListener?
    private var autoDetector: AgentAutoDetectorService?
    private var turnTimer: Timer?
    
    public var onPermissionRequested: ((AgentPermissionRequest) -> Void)?
    public var onTaskCompleted: ((CodeAgentType, String) -> Void)?
    
    public init() {
        startLocalServer()
        setupDistributedNotifications()
        seedInitialLog()
        self.autoDetector = AgentAutoDetectorService(companion: self)
        self.autoDetector?.start()
    }
    
    private func seedInitialLog() {
        activityLog.append(
            AgentActivityItem(
                agent: .antigravity,
                status: .completed,
                message: "Antigravity companion session connected"
            )
        )
    }
    
    // MARK: - Local IPC / HTTP Server (Zero-Dependency NWListener on port 19842)
    public func startLocalServer() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params, on: 19842)
            
            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .main)
                Task { @MainActor [weak self] in
                    self?.receiveRequest(connection: connection)
                }
            }
            
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    switch state {
                    case .ready:
                        self?.isServerRunning = true
                    case .failed, .cancelled:
                        self?.isServerRunning = false
                    default:
                        break
                    }
                }
            }
            
            listener.start(queue: .main)
            self.tcpListener = listener
        } catch {
            self.isServerRunning = false
        }
    }
    
    private func receiveRequest(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, _ in
            if let data = data, let text = String(data: data, encoding: .utf8) {
                Task { @MainActor [weak self] in
                    self?.handleIncomingPayload(text)
                }
            }
            
            // Send simple HTTP 200 OK response
            let response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n{\"status\":\"received\"}\r\n"
            if let resData = response.data(using: .utf8) {
                connection.send(content: resData, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            }
        }
    }
    
    private func handleIncomingPayload(_ raw: String) {
        // Extract JSON body after double newline if HTTP request
        let jsonString: String
        if let range = raw.range(of: "\r\n\r\n") {
            jsonString = String(raw[range.upperBound...])
        } else if let range = raw.range(of: "\n\n") {
            jsonString = String(raw[range.upperBound...])
        } else {
            jsonString = raw
        }
        
        guard let data = jsonString.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return
        }
        
        let agentName = (dict["agent"] as? String)?.lowercased() ?? "antigravity"
        let agent: CodeAgentType
        if agentName.contains("claude") {
            agent = .claude
        } else if agentName.contains("copilot") {
            agent = .copilot
        } else if agentName.contains("cursor") {
            agent = .cursor
        } else {
            agent = .antigravity
        }
        
        let statusString = (dict["status"] as? String)?.lowercased() ?? "working"
        let message = dict["message"] as? String ?? "Processing task..."
        let action = dict["action"] as? String ?? dict["command"] as? String ?? ""
        let detail = dict["detail"] as? String ?? ""
        
        if statusString.contains("permission") || statusString.contains("approval") {
            requestPermission(agent: agent, actionOrTool: action.isEmpty ? message : action, detail: detail)
        } else if statusString.contains("complete") || statusString.contains("finish") {
            completeTask(agent: agent, message: message)
        } else if statusString.contains("error") {
            reportError(agent: agent, message: message)
        } else if statusString.contains("think") {
            setWorking(agent: agent, status: .thinking, message: message)
        } else if statusString.contains("code") {
            setWorking(agent: agent, status: .coding, message: message)
        } else {
            setWorking(agent: agent, status: .executing, message: message)
        }
    }
    
    // MARK: - Distributed Notifications Listener
    private func setupDistributedNotifications() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dynamicisland.agent.event"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo as? [String: Any] else { return }
            Task { @MainActor [weak self] in
                self?.handleNotificationInfo(info)
            }
        }
    }
    
    private func handleNotificationInfo(_ info: [String: Any]) {
        let agentName = (info["agent"] as? String)?.lowercased() ?? "antigravity"
        let agent: CodeAgentType = agentName.contains("claude") ? .claude : (agentName.contains("copilot") ? .copilot : .antigravity)
        let statusString = (info["status"] as? String)?.lowercased() ?? "working"
        let message = info["message"] as? String ?? "Agent update"
        let action = info["action"] as? String ?? ""
        
        if statusString.contains("permission") {
            requestPermission(agent: agent, actionOrTool: action.isEmpty ? message : action)
        } else if statusString.contains("complete") {
            completeTask(agent: agent, message: message)
        } else {
            setWorking(agent: agent, status: .executing, message: message)
        }
    }
    
    // MARK: - Turn Timer & State Updaters
    public var formattedTurnElapsed: String {
        let mins = turnElapsedSeconds / 60
        let secs = turnElapsedSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func startTurnTimer() {
        turnTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.status.isBusy else { return }
                self.turnElapsedSeconds += 1
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.turnTimer = timer
    }
    
    private func stopTurnTimer() {
        turnTimer?.invalidate()
        turnTimer = nil
        turnElapsedSeconds = 0
    }
    
    public func updateSilentStatus(agent: CodeAgentType, status: AgentExecutionStatus, message: String) {
        self.selectedAgent = agent
        self.status = status
        self.currentMessage = message
        if status.isBusy {
            if turnTimer == nil {
                turnElapsedSeconds = 0
                startTurnTimer()
            }
        } else {
            stopTurnTimer()
        }
    }
    
    public func setWorking(agent: CodeAgentType, status: AgentExecutionStatus, message: String) {
        let stateChanged = self.status != status || self.currentMessage != message || self.selectedAgent != agent
        self.selectedAgent = agent
        self.status = status
        self.currentMessage = message
        self.activePermissionRequest = nil
        
        if turnTimer == nil {
            turnElapsedSeconds = 0
            startTurnTimer()
        }
        
        if stateChanged {
            activityLog.insert(
                AgentActivityItem(agent: agent, status: status, message: message),
                at: 0
            )
            if activityLog.count > 30 { activityLog.removeLast() }
            
            // Audio feedback chime on state transition
            NSSound(named: "Tink")?.play()
        }
    }
    
    public func requestPermission(agent: CodeAgentType, actionOrTool: String, detail: String = "") {
        self.selectedAgent = agent
        self.status = .awaitingPermission
        self.currentMessage = "Awaiting Approval: \(actionOrTool)"
        
        let req = AgentPermissionRequest(agent: agent, actionOrTool: actionOrTool, detail: detail)
        self.activePermissionRequest = req
        
        activityLog.insert(
            AgentActivityItem(agent: agent, status: .awaitingPermission, message: "Permission requested: \(actionOrTool)"),
            at: 0
        )
        
        // Audio alert
        NSSound(named: "Submarine")?.play()
        
        // Notify delegate to open Dynamic Island HUD
        onPermissionRequested?(req)
    }
    
    public func completeTask(agent: CodeAgentType, message: String) {
        self.selectedAgent = agent
        self.status = .completed
        self.currentMessage = message
        self.activePermissionRequest = nil
        stopTurnTimer()
        
        activityLog.insert(
            AgentActivityItem(agent: agent, status: .completed, message: message),
            at: 0
        )
        
        // Celebratory chime
        NSSound(named: "Glass")?.play()
        
        // Notify delegate to open Dynamic Island HUD
        onTaskCompleted?(agent, message)
    }
    
    public func reportError(agent: CodeAgentType, message: String) {
        self.selectedAgent = agent
        self.status = .error
        self.currentMessage = message
        self.activePermissionRequest = nil
        stopTurnTimer()
        
        activityLog.insert(
            AgentActivityItem(agent: agent, status: .error, message: message),
            at: 0
        )
        NSSound(named: "Basso")?.play()
    }
    
    public func approveRequest(id: String) {
        guard let req = activePermissionRequest, req.id == id else { return }
        self.activePermissionRequest = nil
        self.status = .executing
        self.currentMessage = "Executing approved command..."
        startTurnTimer()
        
        activityLog.insert(
            AgentActivityItem(agent: req.agent, status: .executing, message: "Approved: \(req.actionOrTool)"),
            at: 0
        )
        NSSound(named: "Hero")?.play()
    }
    
    public func denyRequest(id: String) {
        guard let req = activePermissionRequest, req.id == id else { return }
        self.activePermissionRequest = nil
        self.status = .idle
        self.currentMessage = "Command Denied"
        stopTurnTimer()
        
        activityLog.insert(
            AgentActivityItem(agent: req.agent, status: .error, message: "Denied: \(req.actionOrTool)"),
            at: 0
        )
    }
}
