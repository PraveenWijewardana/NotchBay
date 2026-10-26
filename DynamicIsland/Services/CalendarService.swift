import Foundation
import Combine
import EventKit
import AppKit

@MainActor
public final class CalendarService: ObservableObject {
    @Published public var todayEvents: [CalendarEventItem] = []
    @Published public var upcomingEvents: [CalendarEventItem] = []
    @Published public var selectedDate: Date = Date()
    @Published public var monthTitle: String = ""
    @Published public var currentMonthDays: [CalendarDayItem] = []
    @Published public var hasPermission: Bool = false
    @Published public var userEvents: [CalendarEventItem] = []
    @Published public var newEventTitle: String = ""
    
    private let eventStore = EKEventStore()
    private var refreshTimer: Timer?
    private let userEventsKey = "DynamicIsland_UserCalendarEvents"
    
    public init() {
        loadUserEvents()
        updateMonthMatrix(for: Date())
        checkAndFetchEvents()
        
        // Refresh every 5 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchEvents()
            }
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    public var selectedDateTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) {
            return "Today"
        } else if cal.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else if cal.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MMM d"
            return df.string(from: selectedDate)
        }
    }
    
    public func selectDate(_ date: Date) {
        self.selectedDate = date
        updateMonthMatrix(for: date)
        fetchEvents()
    }
    
    public func nextMonth() {
        if let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) {
            selectDate(next)
        }
    }
    
    public func previousMonth() {
        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) {
            selectDate(prev)
        }
    }
    
    public func nextYear() {
        if let next = Calendar.current.date(byAdding: .year, value: 1, to: selectedDate) {
            selectDate(next)
        }
    }
    
    public func previousYear() {
        if let prev = Calendar.current.date(byAdding: .year, value: -1, to: selectedDate) {
            selectDate(prev)
        }
    }
    
    public func goToToday() {
        selectDate(Date())
    }
    
    public var isViewingCurrentMonth: Bool {
        Calendar.current.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
    }
    
    public func openCalendarApp() {
        if let url = URL(string: "calshow:") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        }
    }
    
    // MARK: - Add Custom Event to Selected Date
    public func addEvent(title: String, location: String? = nil, colorHex: String = "#0A84FF") {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: selectedDate)
        
        // Default time: if selected date is today, start at next hour; else start at 9:00 AM
        let currentHour = cal.component(.hour, from: Date())
        let targetHour = cal.isDateInToday(selectedDate) ? min(currentHour + 1, 23) : 9
        let startDate = cal.date(bySettingHour: targetHour, minute: 0, second: 0, of: startOfDay) ?? startOfDay
        let endDate = cal.date(byAdding: .hour, value: 1, to: startDate) ?? startDate.addingTimeInterval(3600)
        
        let newEvent = CalendarEventItem(
            id: UUID().uuidString,
            title: trimmedTitle,
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            calendarTitle: "NotchBay",
            colorHex: colorHex,
            location: location?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? location : nil
        )
        
        // Save to local user events
        userEvents.append(newEvent)
        saveUserEvents()
        
        // Try saving to Apple Calendar if permissions granted
        if hasPermission {
            let ekEvent = EKEvent(eventStore: eventStore)
            ekEvent.title = trimmedTitle
            ekEvent.startDate = startDate
            ekEvent.endDate = endDate
            ekEvent.calendar = eventStore.defaultCalendarForNewEvents
            if let loc = location, !loc.isEmpty {
                ekEvent.location = loc
            }
            try? eventStore.save(ekEvent, span: .thisEvent)
        }
        
        // Refresh views
        fetchEvents()
        updateMonthMatrix(for: selectedDate)
    }
    
    // MARK: - Delete Event
    public func deleteEvent(id: String) {
        userEvents.removeAll(where: { $0.id == id })
        saveUserEvents()
        
        if hasPermission {
            if let ekEvent = eventStore.event(withIdentifier: id) {
                try? eventStore.remove(ekEvent, span: .thisEvent)
            }
        }
        
        fetchEvents()
        updateMonthMatrix(for: selectedDate)
    }
    
    public func checkAndFetchEvents() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            if status == .fullAccess {
                self.hasPermission = true
                self.fetchEvents()
            } else if status == .notDetermined {
                eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.hasPermission = granted
                        self.fetchEvents()
                    }
                }
            } else {
                fetchEvents()
            }
        } else {
            if status == .authorized {
                self.hasPermission = true
                self.fetchEvents()
            } else if status == .notDetermined {
                eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.hasPermission = granted
                        self.fetchEvents()
                    }
                }
            } else {
                fetchEvents()
            }
        }
    }
    
    public func fetchEvents() {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: selectedDate)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay),
              let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfDay) else {
            return
        }
        
        var combinedToday: [CalendarEventItem] = []
        var combinedUpcoming: [CalendarEventItem] = []
        
        // 1. Fetch real events from Apple Calendar
        if hasPermission {
            let dayPredicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
            let weekPredicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfWeek, calendars: nil)
            
            let dayEK = eventStore.events(matching: dayPredicate)
            let weekEK = eventStore.events(matching: weekPredicate)
            
            combinedToday.append(contentsOf: dayEK.map { ek in
                CalendarEventItem(
                    id: ek.eventIdentifier ?? UUID().uuidString,
                    title: ek.title ?? "Event",
                    startDate: ek.startDate,
                    endDate: ek.endDate,
                    isAllDay: ek.isAllDay,
                    calendarTitle: ek.calendar?.title ?? "Calendar",
                    colorHex: ek.calendar?.cgColor?.toHex() ?? "#0A84FF",
                    location: ek.location
                )
            })
            
            combinedUpcoming.append(contentsOf: weekEK.map { ek in
                CalendarEventItem(
                    id: ek.eventIdentifier ?? UUID().uuidString,
                    title: ek.title ?? "Event",
                    startDate: ek.startDate,
                    endDate: ek.endDate,
                    isAllDay: ek.isAllDay,
                    calendarTitle: ek.calendar?.title ?? "Calendar",
                    colorHex: ek.calendar?.cgColor?.toHex() ?? "#30D158",
                    location: ek.location
                )
            })
        }
        
        // 2. Include user-added events matching the date
        let matchingUserToday = userEvents.filter { cal.isDate($0.startDate, inSameDayAs: selectedDate) }
        let matchingUserUpcoming = userEvents.filter { $0.startDate >= startOfDay && $0.startDate <= endOfWeek }
        
        for item in matchingUserToday {
            if !combinedToday.contains(where: { $0.id == item.id || ($0.title == item.title && cal.isDate($0.startDate, inSameDayAs: item.startDate)) }) {
                combinedToday.append(item)
            }
        }
        
        for item in matchingUserUpcoming {
            if !combinedUpcoming.contains(where: { $0.id == item.id || ($0.title == item.title && cal.isDate($0.startDate, inSameDayAs: item.startDate)) }) {
                combinedUpcoming.append(item)
            }
        }
        
        self.todayEvents = combinedToday.sorted(by: { $0.startDate < $1.startDate })
        self.upcomingEvents = combinedUpcoming.sorted(by: { $0.startDate < $1.startDate })
    }
    
    public func updateMonthMatrix(for date: Date) {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        self.monthTitle = formatter.string(from: date)
        
        guard let monthInterval = cal.dateInterval(of: .month, for: date) else { return }
        
        let firstDayOfMonth = monthInterval.start
        let weekdayOfFirstDay = cal.component(.weekday, from: firstDayOfMonth) // 1 = Sun, 7 = Sat
        
        var days: [CalendarDayItem] = []
        let today = Date()
        
        // Gather all known dates with events
        var eventDates: [Date] = userEvents.map { $0.startDate }
        if hasPermission {
            let startOfGrid = cal.date(byAdding: .day, value: -7, to: firstDayOfMonth) ?? firstDayOfMonth
            let endOfGrid = cal.date(byAdding: .day, value: 42, to: firstDayOfMonth) ?? firstDayOfMonth
            let pred = eventStore.predicateForEvents(withStart: startOfGrid, end: endOfGrid, calendars: nil)
            let ekDates = eventStore.events(matching: pred).compactMap { $0.startDate }
            eventDates.append(contentsOf: ekDates)
        }
        
        // Days before start of month to fill the first row
        let daysBefore = weekdayOfFirstDay - 1
        if daysBefore > 0 {
            for i in (1...daysBefore).reversed() {
                if let prevDate = cal.date(byAdding: .day, value: -i, to: firstDayOfMonth) {
                    let dayNum = cal.component(.day, from: prevDate)
                    let hasEvent = eventDates.contains(where: { cal.isDate($0, inSameDayAs: prevDate) })
                    days.append(CalendarDayItem(date: prevDate, dayNumber: dayNum, isCurrentMonth: false, isToday: cal.isDate(prevDate, inSameDayAs: today), hasEvents: hasEvent))
                }
            }
        }
        
        // Days of current month
        let daysInMonth = cal.range(of: .day, in: .month, for: date)?.count ?? 30
        for i in 0..<daysInMonth {
            if let curDate = cal.date(byAdding: .day, value: i, to: firstDayOfMonth) {
                let dayNum = i + 1
                let isToday = cal.isDate(curDate, inSameDayAs: today)
                let hasEvent = eventDates.contains(where: { cal.isDate($0, inSameDayAs: curDate) })
                days.append(CalendarDayItem(date: curDate, dayNumber: dayNum, isCurrentMonth: true, isToday: isToday, hasEvents: hasEvent))
            }
        }
        
        // Trailing days to complete the grid cells
        let remaining = (7 - (days.count % 7)) % 7
        if remaining > 0, let endOfMonth = cal.date(byAdding: .day, value: daysInMonth, to: firstDayOfMonth) {
            for i in 0..<remaining {
                if let nextDate = cal.date(byAdding: .day, value: i, to: endOfMonth) {
                    let dayNum = cal.component(.day, from: nextDate)
                    let hasEvent = eventDates.contains(where: { cal.isDate($0, inSameDayAs: nextDate) })
                    days.append(CalendarDayItem(date: nextDate, dayNumber: dayNum, isCurrentMonth: false, isToday: cal.isDate(nextDate, inSameDayAs: today), hasEvents: hasEvent))
                }
            }
        }
        
        self.currentMonthDays = days
    }
    
    // MARK: - Persistence
    private func saveUserEvents() {
        if let encoded = try? JSONEncoder().encode(userEvents) {
            UserDefaults.standard.set(encoded, forKey: userEventsKey)
        }
    }
    
    private func loadUserEvents() {
        if let data = UserDefaults.standard.data(forKey: userEventsKey),
           let decoded = try? JSONDecoder().decode([CalendarEventItem].self, from: data) {
            // Remove any legacy dummy placeholder events
            let cleaned = decoded.filter { $0.title != "Good Friday" }
            self.userEvents = cleaned
            if cleaned.count != decoded.count {
                saveUserEvents()
            }
        } else {
            self.userEvents = []
        }
    }
}

extension CGColor {
    func toHex() -> String {
        guard let components = self.components, components.count >= 3 else {
            return "#0A84FF"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
