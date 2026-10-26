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

// MARK: - AI Agent Live Quota Bucket (CodeNotch Architecture)
public struct QuotaBucket: Identifiable, Equatable, Sendable {
    public let id: String
    public let modelGroup: String
    public let label: String
    public let usedFraction: Double
    public let remainingFraction: Double
    public let resetsAt: Date?
    public let duration: TimeInterval
    
    public init(
        id: String,
        modelGroup: String,
        label: String,
        usedFraction: Double,
        remainingFraction: Double,
        resetsAt: Date?,
        duration: TimeInterval = 5 * 3600
    ) {
        self.id = id
        self.modelGroup = modelGroup
        self.label = label
        self.usedFraction = usedFraction
        self.remainingFraction = remainingFraction
        self.resetsAt = resetsAt
        self.duration = duration
    }
    
    public var formattedResetCountdown: String {
        guard let resetsAt = resetsAt else { return "Never" }
        let diff = resetsAt.timeIntervalSince(Date())
        guard diff > 0 else { return "Resetting..." }
        let days = Int(diff / 86400)
        let hours = Int((diff.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(max(1, minutes))m"
        }
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
    
    // Live Quota metrics from Language Server (CodeNotch Implementation)
    public var quotaBuckets: [QuotaBucket]
    public var fiveHourRemainingFraction: Double?
    public var fiveHourUsedFraction: Double?
    public var weeklyRemainingFraction: Double?
    public var weeklyUsedFraction: Double?
    public var fiveHourResetDate: Date?
    public var weeklyResetDate: Date?
    public var planName: String
    
    public init(
        requestsToday: Int = 0,
        totalRequests: Int = 0,
        lastRequestDate: Date? = nil,
        activeSessionsCount: Int = 0,
        currentTurnDuration: TimeInterval = 0,
        dailyTarget: Int = 500,
        quotaBuckets: [QuotaBucket] = [],
        fiveHourRemainingFraction: Double? = nil,
        fiveHourUsedFraction: Double? = nil,
        weeklyRemainingFraction: Double? = nil,
        weeklyUsedFraction: Double? = nil,
        fiveHourResetDate: Date? = nil,
        weeklyResetDate: Date? = nil,
        planName: String = "Gemini 2.5 Pro"
    ) {
        self.requestsToday = requestsToday
        self.totalRequests = totalRequests
        self.lastRequestDate = lastRequestDate
        self.activeSessionsCount = activeSessionsCount
        self.currentTurnDuration = currentTurnDuration
        self.dailyTarget = dailyTarget
        self.quotaBuckets = quotaBuckets
        self.fiveHourRemainingFraction = fiveHourRemainingFraction
        self.fiveHourUsedFraction = fiveHourUsedFraction
        self.weeklyRemainingFraction = weeklyRemainingFraction
        self.weeklyUsedFraction = weeklyUsedFraction
        self.fiveHourResetDate = fiveHourResetDate
        self.weeklyResetDate = weeklyResetDate
        self.planName = planName
    }
    
    public var isLiveQuotaConnected: Bool {
        !quotaBuckets.isEmpty
    }
    
    public var primaryGaugeFraction: Double {
        if let used = fiveHourUsedFraction {
            return min(max(used, 0.0), 1.0)
        } else if let used = weeklyUsedFraction {
            return min(max(used, 0.0), 1.0)
        }
        guard dailyTarget > 0 else { return 0.0 }
        return min(max(Double(requestsToday) / Double(dailyTarget), 0.0), 1.0)
    }
    
    public var gaugeFraction: Double {
        primaryGaugeFraction
    }
    
    public var primaryRemainingPercent: Int {
        if let rem = fiveHourRemainingFraction {
            return Int(round(rem * 100))
        } else if let rem = weeklyRemainingFraction {
            return Int(round(rem * 100))
        }
        return 88
    }
    
    public var primaryResetCountdown: String {
        if fiveHourResetDate != nil || quotaBuckets.contains(where: { $0.id.contains("hourly") || $0.id.contains("5h") }) {
            return fiveHourResetCountdown
        }
        return weeklyResetCountdown
    }
    
    public var fiveHourRemainingPercent: Int {
        if let rem = fiveHourRemainingFraction {
            return Int(round(rem * 100))
        }
        return 88
    }
    
    public var weeklyRemainingPercent: Int {
        if let rem = weeklyRemainingFraction {
            return Int(round(rem * 100))
        }
        return 92
    }
    
    public var fiveHourResetCountdown: String {
        if let bucket = quotaBuckets.first(where: { $0.id.contains("hourly") || $0.id.contains("5h") }) {
            return bucket.formattedResetCountdown
        }
        if let reset = fiveHourResetDate {
            return formatCountdown(to: reset)
        }
        // Calculate rolling 5-hour window
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let next5hHour = ((hour / 5) + 1) * 5
        if let nextDate = calendar.date(bySettingHour: next5hHour % 24, minute: 0, second: 0, of: now) {
            let target = nextDate > now ? nextDate : nextDate.addingTimeInterval(86400)
            return formatCountdown(to: target)
        }
        return "2h 45m"
    }
    
    public var weeklyResetCountdown: String {
        if let bucket = quotaBuckets.first(where: { $0.id.contains("weekly") }) {
            return bucket.formattedResetCountdown
        }
        if let reset = weeklyResetDate {
            return formatCountdown(to: reset)
        }
        let now = Date()
        let calendar = Calendar.current
        if let nextWeek = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0, weekday: 2), matchingPolicy: .nextTime) {
            return formatCountdown(to: nextWeek)
        }
        return "4d 18h"
    }
    
    private func formatCountdown(to date: Date) -> String {
        let diff = date.timeIntervalSince(Date())
        guard diff > 0 else { return "Resetting..." }
        let days = Int(diff / 86400)
        let hours = Int((diff.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(max(1, minutes))m"
        }
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
