import Foundation
import SwiftUI

public enum CallAppType: String, Codable, Sendable, CaseIterable {
    case normal = "Phone"
    case facetime = "FaceTime"
    case whatsApp = "WhatsApp"
    
    public var iconName: String {
        switch self {
        case .normal: return "phone.fill"
        case .facetime: return "video.fill"
        case .whatsApp: return "phone.bubble.fill"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .normal: return Color(red: 0.25, green: 0.85, blue: 0.45) // iOS Green
        case .facetime: return Color(red: 0.2, green: 0.75, blue: 1.0)  // FaceTime Cyan
        case .whatsApp: return Color(red: 0.15, green: 0.82, blue: 0.40) // WhatsApp Emerald
        }
    }
}

public enum CallCategory: String, Codable, Sendable, CaseIterable {
    case cellular = "iPhone Cellular"
    case facetimeAudio = "FaceTime Audio"
    case facetimeVideo = "FaceTime Video"
    case whatsAppAudio = "WhatsApp Audio"
    case whatsAppVideo = "WhatsApp Video"
    
    public var appType: CallAppType {
        switch self {
        case .cellular: return .normal
        case .facetimeAudio, .facetimeVideo: return .facetime
        case .whatsAppAudio, .whatsAppVideo: return .whatsApp
        }
    }
    
    public var isVideo: Bool {
        return self == .facetimeVideo || self == .whatsAppVideo
    }
    
    public var displayTitle: String {
        switch self {
        case .cellular: return "Normal / Cellular Call"
        case .facetimeAudio: return "FaceTime Audio"
        case .facetimeVideo: return "FaceTime Video"
        case .whatsAppAudio: return "WhatsApp Audio"
        case .whatsAppVideo: return "WhatsApp Video"
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
    public let avatarColorHex: String
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        numberOrHandle: String = "",
        avatarColorHex: String = "#34C759"
    ) {
        self.id = id
        self.name = name
        self.numberOrHandle = numberOrHandle
        self.avatarColorHex = avatarColorHex
    }
    
    public var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
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
    
    public init(
        id: String = UUID().uuidString,
        contact: CallContact,
        category: CallCategory,
        status: CallStatus = .incoming,
        startedAt: Date? = nil,
        durationSeconds: Int = 0,
        isMuted: Bool = false,
        isSpeaker: Bool = false
    ) {
        self.id = id
        self.contact = contact
        self.category = category
        self.status = status
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.isMuted = isMuted
        self.isSpeaker = isSpeaker
    }
    
    public var durationFormatted: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
