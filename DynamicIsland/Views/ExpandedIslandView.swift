import SwiftUI
import AppKit
import Darwin

public struct ExpandedIslandView: View {
    @ObservedObject public var viewModel: NotchViewModel
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Clock Formatted Properties
    private var timeHourMinute: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: viewModel.currentDate)
    }
    
    private var timeAmPm: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: viewModel.currentDate)
    }
    
    private var batteryIconName: String {
        let pct = viewModel.systemService.powerMetrics.batteryLevel
        if pct > 80 { return "battery.100" }
        if pct > 50 { return "battery.75" }
        if pct > 25 { return "battery.50" }
        return "battery.25"
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - Top Bar (Full Navigation on Left, Notch Clearance in Center, Clock & Utilities on Right)
            HStack(alignment: .center) {
                // Left Ear: All 8 Dynamic Island Navigation Tabs (Smooth Scrollable Capsule)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        topTabButton(index: 0, icon: "house.fill", title: "Home")
                        topTabButton(index: 1, icon: "gauge.with.needle.fill", title: "System")
                        topTabButton(index: 2, icon: "timer", title: "Timers & Stopwatch")
                        topTabButton(index: 3, icon: "music.note", title: "Now Playing")
                        topTabButton(index: 4, icon: "tray.fill", title: "Drop Shelf")
                        topTabButton(index: 5, icon: "sparkles", title: "Code Agents")
                        topTabButton(index: 6, icon: "calendar", title: "Calendar")
                        topTabButton(index: 7, icon: "cloud.sun.fill", title: "Weather")
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3.5)
                }
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .frame(maxWidth: 215)
                
                Spacer(minLength: max(130, viewModel.physicalNotchWidth - 30))
                
                // Right Ear: Live Clock + 4 Utility Buttons (Lock, Battery, Bell, Settings)
                HStack(spacing: 7) {
                    // Live Digital Clock Button (jumps to Timers / Clock page)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.selectedPageIndex = 2 // Timers / Clock
                        }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(timeHourMinute)
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.white)
                            Text(timeAmPm)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Open Clock & Timers")
                    
                    // Lock Screen Button (Instant SACLockScreenImmediate)
                    Button {
                        lockScreen()
                    } label: {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Lock Screen (Instant)")
                    
                    // Battery Overview Button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.selectedPageIndex = 1 // System & Power
                        }
                    } label: {
                        Image(systemName: batteryIconName)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Battery & Power Metrics (\(viewModel.systemService.powerMetrics.batteryLevel)%)")
                    
                    // Notification / Bell Button
                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Notifications")
                    
                    // Collapse / Settings Gear Button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.setExpanded(false)
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Collapse to Notch")
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            
            // MARK: - Main Content Area
            Group {
                switch viewModel.selectedPageIndex {
                case 0:
                    HomeView(viewModel: viewModel)
                case 1:
                    SystemOverviewView(viewModel: viewModel)
                case 2:
                    TimerDashboardView(viewModel: viewModel)
                case 3:
                    NowPlayingView(viewModel: viewModel)
                case 4:
                    DropShelfView(viewModel: viewModel)
                case 5:
                    AgentDashboardView(viewModel: viewModel)
                case 6:
                    CalendarDashboardView(viewModel: viewModel)
                case 7:
                    WeatherDashboardView(viewModel: viewModel)
                default:
                    HomeView(viewModel: viewModel)
                }
            }
            .frame(maxHeight: .infinity)
            .transition(.opacity)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }
    
    // MARK: - Top Tab Capsule Button
    private func topTabButton(index: Int, icon: String, title: String) -> some View {
        let isSelected = (viewModel.selectedPageIndex == index)
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                viewModel.selectedPageIndex = index
                if index != 1 {
                    viewModel.systemDetailMode = nil
                }
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                }
                
                Image(systemName: icon)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .black : .white.opacity(0.65))
            }
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
    
    // MARK: - Working Native Mac Lock Screen Action
    private func lockScreen() {
        // Method 1: Instant native private framework call (standard macOS Lock Screen API)
        let loginLibPath = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        if let handle = dlopen(loginLibPath, RTLD_LAZY) {
            defer { dlclose(handle) }
            if let sym = dlsym(handle, "SACLockScreenImmediate") {
                typealias LockFn = @convention(c) () -> Void
                let lock = unsafeBitCast(sym, to: LockFn.self)
                lock()
                return
            }
        }
        
        // Method 2: Fallback via AppleScript standard Lock Screen keystroke (Control + Command + Q)
        let appleScript = """
        tell application "System Events"
            key code 12 using {control down, command down}
        end tell
        """
        var err: NSDictionary?
        NSAppleScript(source: appleScript)?.executeAndReturnError(&err)
    }
}
