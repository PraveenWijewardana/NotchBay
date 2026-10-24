import Foundation
import SwiftUI

public struct CalendarEventItem: Identifiable, Sendable, Codable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let calendarTitle: String
    public let colorHex: String
    public let location: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        calendarTitle: String = "Calendar",
        colorHex: String = "#0A84FF",
        location: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
        self.colorHex = colorHex
        self.location = location
    }
    
    public var calendarColor: Color {
        Color(hex: colorHex)
    }
    
    public var timeFormatted: String {
        if isAllDay {
            return "All Day"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) - \(end)"
    }
    
    public var shortTime: String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }
    
    public var isHappeningNow: Bool {
        let now = Date()
        return startDate <= now && endDate >= now
    }
}

public struct CalendarDayItem: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let dayNumber: Int
    public let isCurrentMonth: Bool
    public let isToday: Bool
    public let hasEvents: Bool
    
    public init(
        date: Date,
        dayNumber: Int,
        isCurrentMonth: Bool,
        isToday: Bool,
        hasEvents: Bool = false
    ) {
        self.date = date
        self.dayNumber = dayNumber
        self.isCurrentMonth = isCurrentMonth
        self.isToday = isToday
        self.hasEvents = hasEvents
    }
}

extension Color {
    public init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 10, 132, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
