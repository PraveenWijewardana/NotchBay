import SwiftUI
import AppKit

// MARK: - Settings Tab Enum
public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case compactEars = "Compact Ears"
    case system = "System & Hardware"
    case dropShelf = "Drop Shelf"
    case mediaHUD = "Media & HUD"
    case aiAgents = "AI Code Agents"
    case timers = "Focus & Timers"
    case about = "About & Reset"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .compactEars: return "capsule.portrait.fill"
        case .system: return "cpu"
        case .dropShelf: return "tray.and.arrow.down.fill"
        case .mediaHUD: return "waveform.badge.magnifyingglass"
        case .aiAgents: return "sparkles"
        case .timers: return "timer"
        case .about: return "info.circle.fill"
        }
    }
}

// MARK: - Settings View Model
@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var selectedTab: SettingsTab = .general
    @Published public var showingResetAlert: Bool = false
    
    public init() {}
}

// MARK: - Main Settings View
@MainActor
public struct SettingsView: View {
    @ObservedObject public var settings: AppSettings = AppSettings.shared
    @ObservedObject public var model: SettingsViewModel
    
    public init() {
        self.model = SettingsViewModel()
    }
    
    public init(model: SettingsViewModel) {
        self.model = model
    }
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar Navigation
            VStack(alignment: .leading, spacing: 6) {
                // Header with App Identity
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [settings.accentColor.color, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 38, height: 38)
                            .shadow(color: settings.accentColor.color.opacity(0.4), radius: 6)
                        
                        Image(systemName: "circle.circle")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("NotchBay")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Preferences")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 12)
                
                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                
                // Tabs List
                List(SettingsTab.allCases, selection: $model.selectedTab) { tab in
                    NavigationLink(value: tab) {
                        HStack(spacing: 10) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 20)
                                .foregroundColor(model.selectedTab == tab ? settings.accentColor.color : .white.opacity(0.75))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: model.selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(model.selectedTab == tab ? .white : .white.opacity(0.85))
                        }
                        .padding(.vertical, 3)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .frame(minWidth: 210, idealWidth: 220, maxWidth: 250)
            .background(Color(red: 0.08, green: 0.085, blue: 0.10).opacity(0.95))
        } detail: {
            // Content Area for Selected Tab
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    tabHeaderView(for: model.selectedTab)
                    
                    switch model.selectedTab {
                    case .general:
                        generalSettingsView
                    case .appearance:
                        appearanceSettingsView
                    case .compactEars:
                        compactEarsSettingsView
                    case .system:
                        systemSettingsView
                    case .dropShelf:
                        dropShelfSettingsView
                    case .mediaHUD:
                        mediaHUDSettingsView
                    case .aiAgents:
                        aiAgentsSettingsView
                    case .timers:
                        timersSettingsView
                    case .about:
                        aboutSettingsView
                    }
                    
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 26)
                .padding(.top, 18)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    
                    Color(red: 0.05, green: 0.055, blue: 0.075)
                        .opacity(0.85)
                }
                .frame(height: 52)
                .overlay(
                    Divider().background(Color.white.opacity(0.08)),
                    alignment: .bottom
                )
            }
            .background(Color(red: 0.05, green: 0.055, blue: 0.075))
        }
        .frame(minWidth: 780, minHeight: 560)
        .preferredColorScheme(.dark)
        .alert("Reset All Settings?", isPresented: $model.showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset to Defaults", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("This will restore all NotchBay settings, layout, and appearance options to their original default values.")
        }
    }
    
    // MARK: - Tab Header
    private func tabHeaderView(for tab: SettingsTab) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tab.iconName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(settings.accentColor.color)
                .shadow(color: settings.accentColor.color.opacity(0.5), radius: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.rawValue)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(tabSubtitle(for: tab))
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(.bottom, 6)
    }
    
    private func tabSubtitle(for tab: SettingsTab) -> String {
        switch tab {
        case .general: return "Startup behavior, window interaction, and dock preferences."
        case .appearance: return "Colors, glass blur style, corner rounding, and floating island."
        case .compactEars: return "Customize real-time status indicators in the left & right ears."
        case .system: return "Telemetry polling frequency, metrics, and hardware thresholds."
        case .dropShelf: return "File swallowing behavior, drag gestures, and shelf retention."
        case .mediaHUD: return "Audio visualizer settings and system volume/brightness overlay."
        case .aiAgents: return "Companion port, tool authorization prompts, and notifications."
        case .timers: return "Pomodoro work/break intervals, tick audio, and chime alerts."
        case .about: return "Version info, keyboard shortcuts, and factory defaults."
        }
    }
    
    // MARK: - 1. General Settings
    private var generalSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Startup & System Integration") {
                VStack(spacing: 12) {
                    toggleRow(
                        title: "Launch at Login",
                        subtitle: "Automatically start NotchBay when your Mac boots up.",
                        isOn: $settings.launchAtLogin
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Show App in Dock",
                        subtitle: "Show NotchBay in the macOS Dock and App Switcher (Cmd+Tab).",
                        isOn: $settings.showInDock
                    )
                }
            }
            
            settingsCard(title: "Notch Expansion & Interaction") {
                VStack(spacing: 14) {
                    toggleRow(
                        title: "Hover to Expand",
                        subtitle: "Expand NotchBay into the Bento dashboard when hovering near the notch.",
                        isOn: $settings.hoverToExpand
                    )
                    
                    if settings.hoverToExpand {
                        Divider().background(Color.white.opacity(0.08))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Hover Expansion Delay")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%.2f seconds", settings.hoverDelay))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(settings.accentColor.color)
                            }
                            
                            Slider(value: $settings.hoverDelay, in: 0.05...0.60, step: 0.05)
                                .tint(settings.accentColor.color)
                            
                            HStack {
                                Text("Instant (0.05s)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                                Spacer()
                                Text("Deliberate (0.60s)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Auto-Collapse on Outside Click",
                        subtitle: "Tuck the island back into the notch when clicking anywhere outside.",
                        isOn: $settings.autoCollapseOnClickOutside
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Keep Open While on Drop Shelf",
                        subtitle: "Prevent auto-collapse on page 4 so you can drag and drop files freely.",
                        isOn: $settings.keepOpenOnDropShelf
                    )
                }
            }
        }
    }
    
    // MARK: - 2. Appearance Settings
    private var appearanceSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Accent Color Theme") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Select your primary neon accent for telemetry highlights, waveforms, and borders:")
                        .font(.system(size: 12.5))
                        .foregroundColor(.white.opacity(0.65))
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                        ForEach(AccentColorChoice.allCases) { choice in
                            Button {
                                settings.accentColor = choice
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(choice.color)
                                        .frame(width: 16, height: 16)
                                        .shadow(color: choice.color.opacity(0.6), radius: 3)
                                    
                                    Text(choice.rawValue)
                                        .font(.system(size: 12, weight: settings.accentColor == choice ? .bold : .medium))
                                        .foregroundColor(settings.accentColor == choice ? .white : .white.opacity(0.75))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(settings.accentColor == choice ? Color.white.opacity(0.14) : Color.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(settings.accentColor == choice ? choice.color : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            settingsCard(title: "Island Style & Glass Finish") {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Background Material")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Frosted glass effect behind the island container.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Spacer()
                        Picker("", selection: $settings.glassMaterial) {
                            ForEach(GlassMaterialChoice.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .frame(width: 200)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Neon Border Glow",
                        subtitle: "Illuminate edges with high-contrast accent color when active or hovering.",
                        isOn: $settings.enableNeonGlow
                    )
                    
                    if settings.enableNeonGlow {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Glow Intensity")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%.0f%%", settings.glowIntensity * 100))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(settings.accentColor.color)
                            }
                            
                            Slider(value: $settings.glowIntensity, in: 0.2...1.5, step: 0.1)
                                .tint(settings.accentColor.color)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Notch Corner Rounding")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.0f pt", settings.notchCornerRadius))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(settings.accentColor.color)
                        }
                        
                        Slider(value: $settings.notchCornerRadius, in: 16...36, step: 1)
                            .tint(settings.accentColor.color)
                    }
                }
            }
            
            settingsCard(title: "External Displays & Non-Notch Macs") {
                VStack(spacing: 14) {
                    toggleRow(
                        title: "Floating Dynamic Island Mode",
                        subtitle: "Detach from the screen bezel with a gap, like the iPhone Dynamic Island (recommended for external monitors or non-notch MacBooks).",
                        isOn: $settings.floatingIslandMode
                    )
                    
                    if settings.floatingIslandMode {
                        Divider().background(Color.white.opacity(0.08))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Top Bezel Gap")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%.0f pt", settings.floatingTopMargin))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(settings.accentColor.color)
                            }
                            
                            Slider(value: $settings.floatingTopMargin, in: 4...28, step: 1)
                                .tint(settings.accentColor.color)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 3. Compact Ears Settings
    private var compactEarsSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Live Compact Island Preview") {
                VStack(spacing: 12) {
                    // Visual simulation
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(settings.accentColor.color.opacity(0.5), lineWidth: 1.2)
                            )
                            .frame(height: 38)
                            .shadow(color: settings.accentColor.color.opacity(0.3), radius: 8)
                        
                        HStack {
                            // Left Preview
                            HStack(spacing: 4) {
                                Image(systemName: "cpu")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(settings.accentColor.color)
                                Text("18%")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .frame(width: CGFloat(settings.compactEarWidth), alignment: .leading)
                            .padding(.leading, 12)
                            
                            Spacer()
                            
                            // Physical notch cutout mock
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 80, height: 16)
                            
                            Spacer()
                            
                            // Right Preview
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.green)
                                Text("48.2 MB/s")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .frame(width: CGFloat(settings.compactEarWidth), alignment: .trailing)
                            .padding(.trailing, 12)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Text("The compact pill sits symmetrically around your camera notch, displaying continuous background live activity.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            settingsCard(title: "Status Indicators") {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Left Ear Indicator")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Shown on the left side of the camera notch.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Spacer()
                        Picker("", selection: $settings.leftEarContent) {
                            ForEach(LeftEarIndicator.allCases) { ind in
                                Text(ind.rawValue).tag(ind)
                            }
                        }
                        .frame(width: 200)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Right Ear Indicator")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Shown on the right side of the camera notch.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Spacer()
                        Picker("", selection: $settings.rightEarContent) {
                            ForEach(RightEarIndicator.allCases) { ind in
                                Text(ind.rawValue).tag(ind)
                            }
                        }
                        .frame(width: 200)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Show Active Caffeine Badge",
                        subtitle: "Display the glowing cup icon and remaining sleep-prevention countdown in compact view.",
                        isOn: $settings.showCaffeineInCompact
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Ear Width (Breathing Room)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.0f pt", settings.compactEarWidth))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(settings.accentColor.color)
                        }
                        
                        Slider(value: $settings.compactEarWidth, in: 60...100, step: 2)
                            .tint(settings.accentColor.color)
                    }
                }
            }
        }
    }
    
    // MARK: - 4. System Settings
    private var systemSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Telemetry Performance") {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Background Polling Frequency")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Higher rate provides smoother graphs; lower rate conserves battery.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Spacer()
                        Picker("", selection: $settings.telemetryRate) {
                            ForEach(TelemetryRate.allCases) { rate in
                                Text(rate.title).tag(rate)
                            }
                        }
                        .frame(width: 220)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Temperature Units")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Display units for CPU/GPU thermal sensors.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Spacer()
                        Picker("", selection: $settings.temperatureUnit) {
                            ForEach(TemperatureUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .frame(width: 170)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Track Apple Silicon Metal GPU",
                        subtitle: "Monitor GPU accelerator load alongside CPU cores in the System Overview card.",
                        isOn: $settings.showMetalGPU
                    )
                }
            }
            
            settingsCard(title: "Alert Thresholds") {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("High CPU Warning Threshold")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(settings.highCPUThreshold)%")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        Slider(value: Binding(
                            get: { Double(settings.highCPUThreshold) },
                            set: { settings.highCPUThreshold = Int($0) }
                        ), in: 50...95, step: 5)
                        .tint(.orange)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Low Battery Alert Level")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(settings.lowBatteryThreshold)%")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                        }
                        Slider(value: Binding(
                            get: { Double(settings.lowBatteryThreshold) },
                            set: { settings.lowBatteryThreshold = Int($0) }
                        ), in: 10...35, step: 5)
                        .tint(.red)
                    }
                }
            }
        }
    }
    
    // MARK: - 5. Drop Shelf Settings
    private var dropShelfSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Notch File Shelf Behavior") {
                VStack(spacing: 14) {
                    toggleRow(
                        title: "Auto-Open Shelf on Drag-In",
                        subtitle: "Elastic expansion opens Drop Bay immediately when dragging items toward the camera notch.",
                        isOn: $settings.autoOpenShelfOnDrag
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Retain Files After Dragging Out",
                        subtitle: "Keep files safely in the shelf even after dragging a copy into another app.",
                        isOn: $settings.retainFilesAfterDragOut
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Show File Size Badges",
                        subtitle: "Display human-readable MB / KB tags on stored items.",
                        isOn: $settings.showFileSizeBadge
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Maximum Shelf Capacity")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Number of items held in memory before older items roll off.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Spacer()
                        Picker("", selection: $settings.shelfCapacity) {
                            Text("5 items").tag(5)
                            Text("10 items (Default)").tag(10)
                            Text("20 items").tag(20)
                            Text("30 items").tag(30)
                        }
                        .frame(width: 170)
                    }
                }
            }
        }
    }
    
    // MARK: - 6. Media & HUD Settings
    private var mediaHUDSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Now Playing & Visualizer") {
                VStack(spacing: 14) {
                    toggleRow(
                        title: "Show Dynamic HUD on Track Change",
                        subtitle: "Flash a sleek album art pill from the notch when song advances in Apple Music or Spotify.",
                        isOn: $settings.hudOnTrackChange
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Equalizer Visualizer Bars")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Number of audio-reactive bouncing frequency bars.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Spacer()
                        Picker("", selection: $settings.visualizerBarsCount) {
                            Text("3 Bars (Compact)").tag(3)
                            Text("5 Bars (Classic)").tag(5)
                            Text("8 Bars (Detailed)").tag(8)
                        }
                        .frame(width: 170)
                    }
                }
            }
            
            settingsCard(title: "macOS Native System HUD Overrides") {
                VStack(spacing: 14) {
                    toggleRow(
                        title: "Volume Change HUD",
                        subtitle: "Smooth audio indicator popping from the notch instead of the center-screen bezel.",
                        isOn: $settings.enableVolumeHUD
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Display Brightness HUD",
                        subtitle: "Brightness slider animation rendered directly around the notch.",
                        isOn: $settings.enableBrightnessHUD
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Caps Lock Indicator",
                        subtitle: "Discrete green icon alert when Caps Lock is enabled.",
                        isOn: $settings.enableCapsLockHUD
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "AirDrop Receipt HUD",
                        subtitle: "Notify when genuine AirDrop transfers arrive (requires AirDrop to be enabled).",
                        isOn: $settings.enableAirDropAlerts
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Auto-Detect Incoming & Active Calls",
                        subtitle: "Detect and display Phone, FaceTime, WhatsApp, Zoom, Teams, and Slack calls in the Dynamic Island.",
                        isOn: $settings.enableCallDetection
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("HUD Banner Duration")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.1f seconds", settings.hudDuration))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(settings.accentColor.color)
                        }
                        
                        Slider(value: $settings.hudDuration, in: 1.0...4.5, step: 0.5)
                            .tint(settings.accentColor.color)
                    }
                }
            }
        }
    }
    
    // MARK: - 7. AI Code Agents Settings
    private var aiAgentsSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Active AI Companions (Dynamic Island Display)") {
                VStack(spacing: 14) {
                    Text("Select which AI models and code assistants to monitor. All selected companions will be displayed simultaneously side-by-side in the notch without filtering, showing real-time 5-hour rolling quotas and 7-day limits.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    agentToggleRow(
                        title: "Antigravity (Google DeepMind)",
                        subtitle: "Gemini 2.5 Pro / Flash with live 5-hour rolling session and 7-day weekly quota.",
                        icon: "sparkles",
                        iconColor: .cyan,
                        isOn: $settings.showAntigravityAgent
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    agentToggleRow(
                        title: "Claude Code (Anthropic)",
                        subtitle: "Claude 3.7 Sonnet / Opus with 5-hour rolling session and 7-day weekly allowance.",
                        icon: "cpu",
                        iconColor: Color(red: 0.95, green: 0.45, blue: 0.3),
                        isOn: $settings.showClaudeAgent
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    agentToggleRow(
                        title: "Cursor AI",
                        subtitle: "Fast requests quota, rolling burst limits, and active agent generation telemetry.",
                        icon: "terminal.fill",
                        iconColor: .green,
                        isOn: $settings.showCursorAgent
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    agentToggleRow(
                        title: "GitHub Copilot",
                        subtitle: "Copilot completions and chat quota with weekly cycle and rate-limit tracking.",
                        icon: "chevron.left.forwardslash.chevron.right",
                        iconColor: Color(red: 0.5, green: 0.4, blue: 0.95),
                        isOn: $settings.showCopilotAgent
                    )
                }
            }
            
            settingsCard(title: "Quota Metric Display Mode") {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Limit Display Metric")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Choose whether quota meters display Left Limit (% remaining) or Usage Limit (% consumed).")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Spacer()
                        Picker("", selection: $settings.quotaDisplayMode) {
                            ForEach(QuotaDisplayMode.allCases) { mode in
                                Text(mode.shortTitle).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }
                }
            }
            
            settingsCard(title: "AI Companion Connection") {
                VStack(spacing: 14) {
                    toggleRow(
                        title: "Auto-Detect Local Agent Sessions",
                        subtitle: "Listen on localhost for CLI agent events (Claude Code, Antigravity, Cursor, Gemini, Cline, Copilot).",
                        isOn: $settings.autoDetectAgents
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Agent Listener Port")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("HTTP webhook server port on 127.0.0.1.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Spacer()
                        TextField("Port", value: $settings.agentPort, format: .number)
                            .frame(width: 90)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Auto-Expand on Tool Approval Request",
                        subtitle: "Drop the notch down instantly when an AI agent requests terminal command execution permissions.",
                        isOn: $settings.autoExpandOnToolPermission
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Play Sound on Prompt / Tool Approval",
                        subtitle: "Audible chime when agent reaches completion or requires developer attention.",
                        isOn: $settings.playAgentSoundNotification
                    )
                }
            }
        }
    }
    
    // MARK: - 8. Focus & Timers Settings
    private var timersSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Pomodoro Focus Intervals") {
                VStack(spacing: 14) {
                    stepperRow(title: "Focus Work Session", value: $settings.pomodoroWorkMinutes, range: 10...90, unit: "minutes")
                    Divider().background(Color.white.opacity(0.08))
                    stepperRow(title: "Short Break", value: $settings.pomodoroShortBreakMinutes, range: 2...20, unit: "minutes")
                    Divider().background(Color.white.opacity(0.08))
                    stepperRow(title: "Long Break", value: $settings.pomodoroLongBreakMinutes, range: 10...45, unit: "minutes")
                }
            }
            
            settingsCard(title: "Audio Feedback & Tactile Ticks") {
                VStack(spacing: 14) {
                    toggleRow(
                        title: "Sound on Timer Completion",
                        subtitle: "Chime when a countdown, lap, or focus cycle completes.",
                        isOn: $settings.soundOnTimerFinished
                    )
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    toggleRow(
                        title: "Tactile Ruler Dial Tick Sounds",
                        subtitle: "Play subtle mechanical haptic clicks while scrubbing the timer ruler dial.",
                        isOn: $settings.rulerTickSounds
                    )
                }
            }
        }
    }
    
    // MARK: - 9. About & Reset Settings
    private var aboutSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "About NotchBay") {
                VStack(spacing: 14) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 54, height: 54)
                            Image(systemName: "circle.circle")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("NotchBay for macOS")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("Version 1.0 (Universal Apple Silicon & Intel)")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                            Text("100% Native SwiftUI & AppKit • Zero Dependencies")
                                .font(.system(size: 11))
                                .foregroundColor(settings.accentColor.color)
                        }
                        
                        Spacer()
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    HStack {
                        Text("Keyboard Shortcuts")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    VStack(spacing: 6) {
                        shortcutRow(label: "Open Settings Window", keys: "Cmd + ,")
                        shortcutRow(label: "Toggle NotchBay", keys: "Menu Bar → Toggle")
                        shortcutRow(label: "Lock Screen Instantly", keys: "Lock Icon in Island")
                        shortcutRow(label: "Switch Pages", keys: "1 - 8 in Quick Switch")
                    }
                }
            }
            
            settingsCard(title: "Restore Defaults") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Reset All Preferences")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Revert all visual styles, indicator choices, and thresholds to factory default.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    
                    Spacer()
                    
                    Button("Reset All Settings...") {
                        model.showingResetAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red.opacity(0.8))
                }
            }
        }
    }
    
    // MARK: - Reusable UI Components
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 2)
            
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
    }
    
    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(settings.accentColor.color)
        }
    }
    
    private func agentToggleRow(title: String, subtitle: String, icon: String, iconColor: Color, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11.5))
                            .foregroundColor(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(iconColor)
        }
    }
    
    private func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue) \(unit)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(settings.accentColor.color)
            }
        }
    }
    
    private func shortcutRow(label: String, keys: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.75))
            Spacer()
            Text(keys)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
