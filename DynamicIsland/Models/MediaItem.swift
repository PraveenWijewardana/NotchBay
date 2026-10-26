import Foundation
import AppKit
import SwiftUI

public struct MediaTrack: Sendable {
    public var title: String = "No Media Playing"
    public var artist: String = "Open Spotify or Music"
    public var album: String = ""
    public var sourceAppName: String = ""
    public var isPlaying: Bool = false
    public var currentPosition: Double = 0
    public var duration: Double = 0
    public var volume: Double = 0.7
    public var artworkData: Data? = nil
    
    public init(
        title: String = "No Media Playing",
        artist: String = "Open Spotify or Music",
        album: String = "",
        sourceAppName: String = "",
        isPlaying: Bool = false,
        currentPosition: Double = 0,
        duration: Double = 0,
        volume: Double = 0.7,
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.sourceAppName = sourceAppName
        self.isPlaying = isPlaying
        self.currentPosition = currentPosition
        self.duration = duration
        self.volume = volume
        self.artworkData = artworkData
    }
    
    public var elapsedFormatted: String {
        guard duration > 0 else { return "0:00" }
        let mins = Int(currentPosition) / 60
        let secs = Int(currentPosition) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public var remainingFormatted: String {
        guard duration > 0 else { return "-0:00" }
        let rem = max(0, duration - currentPosition)
        let mins = Int(rem) / 60
        let secs = Int(rem) % 60
        return String(format: "-%d:%02d", mins, secs)
    }
    
    public var progressFraction: Double {
        guard duration > 0 else { return 0 }
        return min(1.0, max(0.0, currentPosition / duration))
    }
}

public struct LyricLine: Identifiable, Equatable, Sendable {
    public let id: Int
    public let timestamp: Double? // in seconds, nil if plain
    public let text: String
    
    public init(id: Int, timestamp: Double? = nil, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
    }
}

public enum ShelfItemType: String, Sendable, CaseIterable {
    case all = "All"
    case link = "Links"
    case color = "Colors"
    case image = "Images"
    case code = "Code"
    case text = "Text"
    case file = "Files"
    
    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .link: return "link"
        case .color: return "paintpalette.fill"
        case .image: return "photo.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "line.3.horizontal"
        case .file: return "doc.fill"
        }
    }
    
    public var badgeTitle: String {
        switch self {
        case .all: return "ALL"
        case .link: return "LINK"
        case .color: return "COLOR"
        case .image: return "IMAGE"
        case .code: return "CODE"
        case .text: return "TEXT"
        case .file: return "FILE"
        }
    }
    
    public var badgeColor: Color {
        switch self {
        case .all: return .white
        case .link: return Color(red: 0.10, green: 0.60, blue: 1.0)
        case .color: return Color(red: 1.0, green: 0.20, blue: 0.40)
        case .image: return Color(red: 1.0, green: 0.15, blue: 0.70)
        case .code: return Color(red: 0.75, green: 0.35, blue: 1.0)
        case .text: return Color(red: 0.15, green: 0.82, blue: 0.95)
        case .file: return Color(red: 1.0, green: 0.65, blue: 0.0)
        }
    }
}

public struct ShelfItem: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let path: URL?
    public let stringContent: String?
    public let imageData: Data?
    public let colorHex: String?
    public let dateAdded: Date
    public let fileSizeFormatted: String
    public let itemType: ShelfItemType
    
    public init(
        id: UUID = UUID(),
        name: String,
        path: URL? = nil,
        stringContent: String? = nil,
        imageData: Data? = nil,
        colorHex: String? = nil,
        dateAdded: Date = Date(),
        fileSizeFormatted: String = "",
        itemType: ShelfItemType = .file
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.stringContent = stringContent
        self.imageData = imageData
        self.colorHex = colorHex
        self.dateAdded = dateAdded
        self.fileSizeFormatted = fileSizeFormatted
        self.itemType = itemType
    }
    
    public var timeAgoFormatted: String {
        let sec = max(0, Int(-dateAdded.timeIntervalSinceNow))
        if sec < 60 { return "now" }
        let min = sec / 60
        if min < 60 { return "\(min)m" }
        let hr = min / 60
        if hr < 24 { return "\(hr)h" }
        let day = hr / 24
        return "\(day)d"
    }
}
