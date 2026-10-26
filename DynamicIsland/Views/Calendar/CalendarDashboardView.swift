import SwiftUI

public struct CalendarDashboardView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var calendarService: CalendarService
    
    private let weekDays = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.calendarService = viewModel.calendarService
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - Header: Fixed-Position Month Nav & Open in Calendar App
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.red)
                    
                    // Month & Year Menu Title with fixed width so buttons never shift
                    Menu {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                calendarService.goToToday()
                            }
                        } label: {
                            Label("Jump to Today", systemImage: "clock.arrow.circlepath")
                        }
                        
                        Divider()
                        
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                calendarService.previousYear()
                            }
                        } label: {
                            Label("Previous Year (-1 Year)", systemImage: "chevron.backward.2")
                        }
                        
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                calendarService.nextYear()
                            }
                        } label: {
                            Label("Next Year (+1 Year)", systemImage: "chevron.forward.2")
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(calendarService.monthTitle)
                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 7.5, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 142, alignment: .leading)
                    
                    // Fixed-Location Month Navigation Stepper (STATIONARY - NEVER MOVES ON CLICK)
                    HStack(spacing: 1) {
                        Button {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                calendarService.previousMonth()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 26, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Previous Month")
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 1, height: 12)
                        
                        Button {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                calendarService.nextMonth()
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 26, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Next Month")
                    }
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    
                    // Quick "Today" jump button (appears when navigated away from current month)
                    if !calendarService.isViewingCurrentMonth {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                calendarService.goToToday()
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 4, height: 4)
                                Text("Today")
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.2))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Spacer()
                
                // Open Apple Calendar app
                Button {
                    calendarService.openCalendarApp()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Open Calendar")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
            
            // MARK: - Main Area: Mini Calendar Grid + Day Agenda
            HStack(spacing: 10) {
                // Left Card: Interactive Month Grid
                VStack(spacing: 4) {
                    // Weekday headers
                    HStack(spacing: 2) {
                        ForEach(weekDays.indices, id: \.self) { idx in
                            Text(weekDays[idx])
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(idx == 0 || idx == 6 ? .secondary.opacity(0.6) : .secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.bottom, 1)
                    
                    // Month Matrix Days Grid
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(calendarService.currentMonthDays) { day in
                            let isSelected = Calendar.current.isDate(day.date, inSameDayAs: calendarService.selectedDate)
                            Button {
                                calendarService.selectDate(day.date)
                            } label: {
                                ZStack {
                                    if day.isToday {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 17, height: 17)
                                    } else if isSelected {
                                        Circle()
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 17, height: 17)
                                    }
                                    
                                    Text("\(day.dayNumber)")
                                        .font(.system(size: 9, weight: day.isToday || isSelected ? .bold : .medium, design: .rounded))
                                        .foregroundColor(
                                            day.isToday ? .white :
                                            (day.isCurrentMonth ? (isSelected ? .white : .white.opacity(0.85)) : .white.opacity(0.25))
                                        )
                                    
                                    if day.hasEvents && !day.isToday {
                                        Circle()
                                            .fill(Color.cyan)
                                            .frame(width: 2.5, height: 2.5)
                                            .offset(y: 7)
                                    }
                                }
                                .frame(height: 18)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.12)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
                .gesture(
                    DragGesture(minimumDistance: 25)
                        .onEnded { value in
                            if value.translation.width < -25 {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    calendarService.nextMonth()
                                }
                            } else if value.translation.width > 25 {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    calendarService.previousMonth()
                                }
                            }
                        }
                )
                
                // Right Card: Agenda / Event List
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 5, height: 5)
                            Text("AGENDA")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            Text("•")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text(calendarService.selectedDateTitle)
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)
                        }
                        
                        Spacer()
                        
                        Text("\(calendarService.todayEvents.count) Events")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    if calendarService.todayEvents.isEmpty {
                        VStack(spacing: 6) {
                            Spacer()
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.35))
                            Text("No events for \(calendarService.selectedDateTitle)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            quickAddBar
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 5) {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 4) {
                                    ForEach(calendarService.todayEvents) { event in
                                        eventRow(event)
                                    }
                                }
                            }
                            
                            quickAddBar
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.12)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .frame(height: 146)
        }
    }
    
    // MARK: - Quick Add Bar
    private var quickAddBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.cyan)
            
            TextField("Add item to \(calendarService.selectedDateTitle)...", text: $calendarService.newEventTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .onSubmit {
                    submitNewEvent()
                }
            
            if !calendarService.newEventTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: submitNewEvent) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    private func submitNewEvent() {
        let trimmed = calendarService.newEventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        calendarService.addEvent(title: trimmed)
        calendarService.newEventTitle = ""
    }
    
    // MARK: - Event Row
    private func eventRow(_ event: CalendarEventItem) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.calendarColor)
                .frame(width: 3, height: 22)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(event.timeFormatted)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    if let loc = event.location, !loc.isEmpty {
                        Text("•")
                            .font(.system(size: 7))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(loc)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundColor(.cyan.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            if event.isHappeningNow {
                Text("NOW")
                    .font(.system(size: 7, weight: .heavy, design: .rounded))
                    .foregroundColor(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            Button {
                calendarService.deleteEvent(id: event.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(3)
            }
            .buttonStyle(.plain)
            .help("Delete event")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
    }
}
