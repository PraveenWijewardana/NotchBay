import Foundation
import SwiftUI

public enum CallAppType: String, Codable, Sendable, CaseIterable {
    case normal = "Phone"
    case facetime = "FaceTime"
    case whatsApp = "WhatsApp"
    case zoom = "Zoom"
    case teams = "Teams"
    case telegram = "Telegram"
    case slack = "Slack"
    case meet = "Google Meet"
    case other = "Call"
    
    public var iconName: String {
        switch self {
        case .normal: return "phone.fill"
        case .facetime: return "video.fill"
        case .whatsApp: return "phone.bubble.fill"
        case .zoom: return "video.badge.waveform.fill"
        case .teams: return "person.2.fill"
        case .telegram: return "paperplane.fill"
        case .slack: return "number"
        case .meet: return "video.fill"
        case .other: return "phone.fill"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .normal: return Color(red: 0.25, green: 0.85, blue: 0.45) // iOS Green
        case .facetime: return Color(red: 0.2, green: 0.75, blue: 1.0)  // FaceTime Cyan
        case .whatsApp: return Color(red: 0.15, green: 0.82, blue: 0.40) // WhatsApp Emerald
        case .zoom: return Color(red: 0.18, green: 0.52, blue: 1.0)    // Zoom Blue
        case .teams: return Color(red: 0.42, green: 0.42, blue: 0.95)   // Teams Indigo
        case .telegram: return Color(red: 0.20, green: 0.65, blue: 0.95) // Telegram Sky
        case .slack: return Color(red: 0.90, green: 0.35, blue: 0.45)   // Slack Berry
        case .meet: return Color(red: 0.05, green: 0.68, blue: 0.45)    // Meet Green
        case .other: return Color(red: 0.30, green: 0.80, blue: 0.50)
        }
    }
}

public enum CallCategory: String, Codable, Sendable, CaseIterable {
    case cellular = "iPhone Cellular"
    case facetimeAudio = "FaceTime Audio"
    case facetimeVideo = "FaceTime Video"
    case whatsAppAudio = "WhatsApp Audio"
    case whatsAppVideo = "WhatsApp Video"
    case zoomMeeting = "Zoom Meeting"
    case teamsMeeting = "Teams Meeting"
    case telegramCall = "Telegram Call"
    case slackHuddle = "Slack Huddle"
    case webMeeting = "Online Meeting"
    case other = "Voice Call"
    
    public var appType: CallAppType {
        switch self {
        case .cellular: return .normal
        case .facetimeAudio, .facetimeVideo: return .facetime
        case .whatsAppAudio, .whatsAppVideo: return .whatsApp
        case .zoomMeeting: return .zoom
        case .teamsMeeting: return .teams
        case .telegramCall: return .telegram
        case .slackHuddle: return .slack
        case .webMeeting: return .meet
        case .other: return .other
        }
    }
    
    public var isVideo: Bool {
        switch self {
        case .facetimeVideo, .whatsAppVideo, .zoomMeeting, .teamsMeeting, .webMeeting:
            return true
        default:
            return false
        }
    }
    
    public var displayTitle: String {
        switch self {
        case .cellular: return "Normal / Cellular Call"
        case .facetimeAudio: return "FaceTime Audio"
        case .facetimeVideo: return "FaceTime Video"
        case .whatsAppAudio: return "WhatsApp Audio"
        case .whatsAppVideo: return "WhatsApp Video"
        case .zoomMeeting: return "Zoom Meeting"
        case .teamsMeeting: return "Microsoft Teams"
        case .telegramCall: return "Telegram Call"
        case .slackHuddle: return "Slack Huddle"
        case .webMeeting: return "Online Meeting"
        case .other: return "Voice Call"
        }
    }
}

public enum CallStatus: String, Codable, Sendable {
    case incoming = "Incoming"
    case active = "Active"
    case ended = "Ended"
}

public struct CallContact: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let numberOrHandle: String
    public let avatarImageData: Data?
    public let avatarColorHex: String
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        numberOrHandle: String = "",
        avatarImageData: Data? = nil,
        avatarColorHex: String = "#34C759"
    ) {
        self.id = id
        self.name = name
        self.numberOrHandle = numberOrHandle
        self.avatarImageData = avatarImageData
        self.avatarColorHex = avatarColorHex
    }
    
    public var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        if !trimmed.isEmpty {
            return String(trimmed.prefix(2)).uppercased()
        }
        return "📞"
    }
}

public struct ActiveCallSession: Identifiable, Sendable {
    public let id: String
    public let contact: CallContact
    public let category: CallCategory
    public var status: CallStatus
    public let startedAt: Date?
    public var durationSeconds: Int
    public var isMuted: Bool
    public var isSpeaker: Bool
    public var appPID: pid_t?
    
    public init(
        id: String = UUID().uuidString,
        contact: CallContact,
        category: CallCategory,
        status: CallStatus = .incoming,
        startedAt: Date? = nil,
        durationSeconds: Int = 0,
        isMuted: Bool = false,
        isSpeaker: Bool = false,
        appPID: pid_t? = nil
    ) {
        self.id = id
        self.contact = contact
        self.category = category
        self.status = status
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.isMuted = isMuted
        self.isSpeaker = isSpeaker
        self.appPID = appPID
    }
    
    public var durationFormatted: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
