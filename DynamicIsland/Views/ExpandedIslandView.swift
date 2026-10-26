import SwiftUI
import AppKit
import Darwin

public struct ExpandedIslandView: View {
    @ObservedObject public var viewModel: NotchViewModel
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }
    

    
    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - Top Bar (Balanced Navigation Across Left & Right Ears)
            HStack(alignment: .center, spacing: 6) {
                // Left Ear: Dashboard & Workflow Tabs (Home, System, Timers, Music, Drop Shelf, AI Agents)
                HStack(spacing: 4) {
                    topTabButton(index: 0, icon: "house.fill", title: "Home")
                    topTabButton(index: 1, icon: "gauge.with.needle.fill", title: "System")
                    topTabButton(index: 2, icon: "timer", title: "Timers & Stopwatch")
                    topTabButton(index: 3, icon: "music.note", title: "Now Playing")
                    topTabButton(index: 4, icon: "tray.fill", title: "Drop Shelf")
                    topTabButton(index: 5, icon: "sparkles", title: "Code Agents (AI)")
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
                
                // Camera Notch Clearance Spacer
                Spacer(minLength: max(20, min(80, viewModel.physicalNotchWidth - 120)))
                
                // Right Ear: Calendar & Weather Tabs
                HStack(spacing: 4) {
                    topTabButton(index: 6, icon: "calendar", title: "Calendar")
                    topTabButton(index: 7, icon: "cloud.sun.fill", title: "Weather")
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
                
                // Utility Actions Capsule (Caffeine, Lock Screen, Settings)
                HStack(spacing: 4) {
                    // Caffeine Sleep Prevention Button with Presets Menu
                    Menu {
                        Button("Keep Awake Indefinitely") {
                            viewModel.caffeineService.activate(preset: .indefinite)
                        }
                        Button("15 Minutes") {
                            viewModel.caffeineService.activate(preset: .minutes15)
                        }
                        Button("30 Minutes") {
                            viewModel.caffeineService.activate(preset: .minutes30)
                        }
                        Button("1 Hour") {
                            viewModel.caffeineService.activate(preset: .hours1)
                        }
                        Button("2 Hours") {
                            viewModel.caffeineService.activate(preset: .hours2)
                        }
                        if viewModel.caffeineService.isActive {
                            Divider()
                            Button("Turn Off Caffeine") {
                                viewModel.caffeineService.deactivate()
                            }
                        }
                    } label: {
                        HStack(spacing: 2.5) {
                            Image(systemName: viewModel.caffeineService.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(viewModel.caffeineService.isActive ? .orange : .white.opacity(0.85))
                                .shadow(color: viewModel.caffeineService.isActive ? .orange.opacity(0.7) : .clear, radius: 2)
                            
                            if viewModel.caffeineService.isActive {
                                Text(viewModel.caffeineService.formattedRemainingTime)
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal, viewModel.caffeineService.isActive ? 4 : 2)
                        .frame(height: 22)
                        .background(viewModel.caffeineService.isActive ? Color.orange.opacity(0.18) : Color.clear)
                        .clipShape(Capsule())
                    }
                    .menuStyle(.borderlessButton)
                    .help("Caffeine: Prevent Mac Sleep")
                    
                    // Settings Window Button (Opens independent macOS window and closes notch)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.setExpanded(false)
                        }
                        SettingsWindowController.shared.showWindow()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Open Settings Window (⌘,)")
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
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
            
            // MARK: - Bottom Grabber / Lock Open Indicator Line (Shows on every page)
            bottomLockGrabberLine
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }
    
    // MARK: - Top Tab Capsule Button
    private func topTabButton(index: Int, icon: String, title: String) -> some View {
        let isSelected = (viewModel.selectedPageIndex == index)
        let isAgentTab = (index == 5)
        let hasActiveAgent = isAgentTab && (viewModel.agentService.status == .thinking || viewModel.agentService.status == .coding || viewModel.agentService.status == .executing || viewModel.agentService.status == .awaitingPermission)
        
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
                    .foregroundColor(isSelected ? .black : (hasActiveAgent ? .cyan : .white.opacity(0.65)))
                
                if hasActiveAgent && !isSelected {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 4.5, height: 4.5)
                        .offset(x: 7, y: -7)
                }
            }
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
    
    // MARK: - Bottom Lock Open Grabber Indicator (Every Page)
    private var bottomLockGrabberLine: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                viewModel.isPinned.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Capsule()
                    .fill(
                        viewModel.isPinned
                            ? LinearGradient(
                                colors: [Color(red: 0.20, green: 0.85, blue: 0.45), Color(red: 0.15, green: 0.75, blue: 0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(viewModel.isGrabberHovered ? 0.45 : 0.22), Color.white.opacity(viewModel.isGrabberHovered ? 0.45 : 0.22)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .frame(width: viewModel.isPinned ? 48 : (viewModel.isGrabberHovered ? 42 : 36), height: 3.5)
                    .shadow(
                        color: viewModel.isPinned ? Color(red: 0.20, green: 0.85, blue: 0.45).opacity(0.85) : (viewModel.isGrabberHovered ? Color.white.opacity(0.2) : Color.clear),
                        radius: viewModel.isPinned ? 5 : 2,
                        x: 0,
                        y: 0
                    )
            }
            .frame(width: 70, height: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.isGrabberHovered = hovering
            }
        }
        .help(viewModel.isPinned ? "Notch is Locked Open (Won't minimize when clicking other apps — Click to unlock)" : "Lock Notch Open (Keep expanded when clicking other apps)")
    }
}
