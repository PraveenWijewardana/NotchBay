import Foundation
import SwiftUI

public enum HUDEventType: Equatable, Sendable {
    case volume(level: Double, isMuted: Bool)
    case battery(level: Int, isCharging: Bool, isPluggedIn: Bool)
    case track(title: String, artist: String)
    case agentPermission(agent: CodeAgentType, requestId: String, action: String)
    case agentFinished(agent: CodeAgentType, message: String)
    case agentError(agent: CodeAgentType, message: String)
    case caffeine(isActive: Bool, presetTitle: String)
    case magSafe(level: Int, isPluggedIn: Bool, timeRemaining: String?)
    case fileTransfer(name: String, progress: Double, isAirDrop: Bool, isCompleted: Bool, currentBytes: Int64 = 0, totalBytes: Int64 = -1, speedStr: String = "")
    case focus(isActive: Bool, sessionTitle: String, duration: String)
}

public struct HUDAlert: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let type: HUDEventType
    public let title: String
    public let subtitle: String
    public let icon: String
    public let progress: Double?
    public let isMuted: Bool
    public let duration: TimeInterval
    
    public init(
        id: UUID = UUID(),
        type: HUDEventType,
        title: String,
        subtitle: String,
        icon: String,
        progress: Double? = nil,
        isMuted: Bool = false,
        duration: TimeInterval = 2.4
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.progress = progress
        self.isMuted = isMuted
        self.duration = duration
    }
}
