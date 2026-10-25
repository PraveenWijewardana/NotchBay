import Foundation
import SwiftUI

public enum CodeAgentType: String, CaseIterable, Identifiable, Sendable {
    case antigravity = "Antigravity"
    case claude = "Claude Code"
    case copilot = "GitHub Copilot"
    case cursor = "Cursor"
    
    public var id: String { rawValue }
    public var displayName: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .antigravity: return "sparkles"
        case .claude: return "cpu"
        case .copilot: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "terminal.fill"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .antigravity: return Color.cyan
        case .claude: return Color(red: 0.95, green: 0.45, blue: 0.3)
        case .copilot: return Color(red: 0.5, green: 0.4, blue: 0.95)
        case .cursor: return Color.green
        }
    }
}

public enum AgentExecutionStatus: String, CaseIterable, Sendable {
    case idle = "Idle"
    case thinking = "Thinking"
    case coding = "Coding"
    case executing = "Running Tool"
    case awaitingPermission = "Needs Approval"
    case completed = "Finished"
    case error = "Error"
    
    public var icon: String {
        switch self {
        case .idle: return "sleep"
        case .thinking: return "brain.head.profile"
        case .coding: return "curlybraces"
        case .executing: return "terminal.fill"
        case .awaitingPermission: return "exclamationmark.shield.fill"
        case .completed: return "checkmark.seal.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .idle: return .secondary
        case .thinking: return .cyan
        case .coding: return .blue
        case .executing: return .orange
        case .awaitingPermission: return .yellow
        case .completed: return .green
        case .error: return .red
        }
    }
    
    public var isBusy: Bool {
        self == .thinking || self == .coding || self == .executing
    }
}

public struct AgentPermissionRequest: Identifiable, Sendable {
    public let id: String
    public let agent: CodeAgentType
    public let actionOrTool: String
    public let detail: String
    public let date: Date
    
    public init(
        id: String = UUID().uuidString,
        agent: CodeAgentType,
        actionOrTool: String,
        detail: String = "",
        date: Date = Date()
    ) {
        self.id = id
        self.agent = agent
        self.actionOrTool = actionOrTool
        self.detail = detail
        self.date = date
    }
}

public struct AgentActivityItem: Identifiable, Sendable {
    public let id: UUID
    public let agent: CodeAgentType
    public let status: AgentExecutionStatus
    public let message: String
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        agent: CodeAgentType,
        status: AgentExecutionStatus,
        message: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.agent = agent
        self.status = status
        self.message = message
        self.timestamp = timestamp
    }
    
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - AI Agent Usage Metrics (Inspired by CodeNotch)
public struct AgentUsageMetrics: Equatable, Sendable {
    public var requestsToday: Int
    public var totalRequests: Int
    public var lastRequestDate: Date?
    public var activeSessionsCount: Int
    public var currentTurnDuration: TimeInterval
    public var dailyTarget: Int // Soft daily benchmark for gauge ring (e.g. 500)
    
    public init(
        requestsToday: Int = 0,
        totalRequests: Int = 0,
        lastRequestDate: Date? = nil,
        activeSessionsCount: Int = 0,
        currentTurnDuration: TimeInterval = 0,
        dailyTarget: Int = 500
    ) {
        self.requestsToday = requestsToday
        self.totalRequests = totalRequests
        self.lastRequestDate = lastRequestDate
        self.activeSessionsCount = activeSessionsCount
        self.currentTurnDuration = currentTurnDuration
        self.dailyTarget = dailyTarget
    }
    
    public var gaugeFraction: Double {
        guard dailyTarget > 0 else { return 0.0 }
        return min(max(Double(requestsToday) / Double(dailyTarget), 0.0), 1.0)
    }
    
    public var formattedLastActive: String {
        guard let date = lastRequestDate else { return "Never" }
        let elapsed = max(0, Date().timeIntervalSince(date))
        if elapsed < 60 {
            return "Just now"
        } else if elapsed < 3600 {
            return "\(Int(elapsed / 60))m ago"
        } else if elapsed < 86400 {
            return "\(Int(elapsed / 3600))h ago"
        } else {
            return "\(Int(elapsed / 86400))d ago"
        }
    }
}
