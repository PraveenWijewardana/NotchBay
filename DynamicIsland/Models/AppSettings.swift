import Foundation
import SwiftUI
import Combine

// MARK: - Accent Color Choices
public enum AccentColorChoice: String, CaseIterable, Identifiable, Codable {
    case cyan = "Electric Cyan"
    case emerald = "Mint Emerald"
    case orange = "Neon Orange"
    case magenta = "Hot Magenta"
    case purple = "Cyber Purple"
    case blue = "Apple Blue"
    case gold = "Solar Gold"
    case white = "Frost White"
    
    public var id: String { rawValue }
    
    public var color: Color {
        switch self {
        case .cyan: return Color(red: 0.15, green: 0.88, blue: 1.0)
        case .emerald: return Color(red: 0.25, green: 0.95, blue: 0.55)
        case .orange: return Color(red: 1.0, green: 0.55, blue: 0.15)
        case .magenta: return Color(red: 1.0, green: 0.25, blue: 0.65)
        case .purple: return Color(red: 0.72, green: 0.35, blue: 1.0)
        case .blue: return Color(red: 0.25, green: 0.55, blue: 1.0)
        case .gold: return Color(red: 1.0, green: 0.82, blue: 0.2)
        case .white: return Color(white: 0.95)
        }
    }
}

// MARK: - Glass Material Choices
public enum GlassMaterialChoice: String, CaseIterable, Identifiable, Codable {
    case trueBlack = "OLED True Black"
    case frostedDark = "Frosted Dark Glass"
    case neonCyber = "Neon Cyberpunk Tint"
    case ultraThin = "Ultra-Thin Crystal"
    
    public var id: String { rawValue }
}

// MARK: - Compact Ear Content Choices
public enum LeftEarIndicator: String, CaseIterable, Identifiable, Codable {
    case cpuLoad = "CPU Usage (%)"
    case memoryUsage = "Memory / RAM"
    case clock = "Digital Clock"
    case weatherTemp = "Weather Temp"
    case batteryPercent = "Battery Level"
    case musicVisualizer = "Music Equalizer (Auto)"
    case hidden = "Hidden"
    
    public var id: String { rawValue }
}

public enum RightEarIndicator: String, CaseIterable, Identifiable, Codable {
    case networkSpeed = "Network Speed (Auto)"
    case downloadOnly = "Download Speed Only"
    case uploadOnly = "Upload Speed Only"
    case activeAgents = "AI Code Agents"
    case timers = "Running Timers"
    case batteryPercent = "Battery Level"
    case hidden = "Hidden"
    
    public var id: String { rawValue }
}

// MARK: - Temperature Unit
public enum TemperatureUnit: String, CaseIterable, Identifiable, Codable {
    case celsius = "Celsius (°C)"
    case fahrenheit = "Fahrenheit (°F)"
    
    public var id: String { rawValue }
}

// MARK: - Telemetry Refresh Rate
public enum TelemetryRate: Double, CaseIterable, Identifiable, Codable {
    case fast = 0.5
    case normal = 1.0
    case relaxed = 2.0
    case eco = 5.0
    
    public var id: Double { rawValue }
    
    public var title: String {
        switch self {
        case .fast: return "0.5s (Ultra Smooth)"
        case .normal: return "1.0s (Recommended)"
        case .relaxed: return "2.0s (Battery Friendly)"
        case .eco: return "5.0s (Eco Saver)"
        }
    }
}

// MARK: - AppSettings Observable Singleton
@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - General Settings
    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "nb_launchAtLogin") }
    }
    @Published public var showInDock: Bool {
        didSet {
            defaults.set(showInDock, forKey: "nb_showInDock")
            updateActivationPolicy()
        }
    }
    @Published public var hoverToExpand: Bool {
        didSet { defaults.set(hoverToExpand, forKey: "nb_hoverToExpand") }
    }
    @Published public var hoverDelay: Double {
        didSet { defaults.set(hoverDelay, forKey: "nb_hoverDelay") }
    }
    @Published public var autoCollapseOnClickOutside: Bool {
        didSet { defaults.set(autoCollapseOnClickOutside, forKey: "nb_autoCollapseOnClickOutside") }
    }
    @Published public var keepOpenOnDropShelf: Bool {
        didSet { defaults.set(keepOpenOnDropShelf, forKey: "nb_keepOpenOnDropShelf") }
    }
    
    // MARK: - Appearance & Theme
    @Published public var accentColor: AccentColorChoice {
        didSet { defaults.set(accentColor.rawValue, forKey: "nb_accentColor") }
    }
    @Published public var glassMaterial: GlassMaterialChoice {
        didSet { defaults.set(glassMaterial.rawValue, forKey: "nb_glassMaterial") }
    }
    @Published public var enableNeonGlow: Bool {
        didSet { defaults.set(enableNeonGlow, forKey: "nb_enableNeonGlow") }
    }
    @Published public var glowIntensity: Double {
        didSet { defaults.set(glowIntensity, forKey: "nb_glowIntensity") }
    }
    @Published public var notchCornerRadius: Double {
        didSet { defaults.set(notchCornerRadius, forKey: "nb_notchCornerRadius") }
    }
    @Published public var floatingIslandMode: Bool {
        didSet { defaults.set(floatingIslandMode, forKey: "nb_floatingIslandMode") }
    }
    @Published public var floatingTopMargin: Double {
        didSet { defaults.set(floatingTopMargin, forKey: "nb_floatingTopMargin") }
    }
    @Published public var islandWidthExpanded: Double {
        didSet { defaults.set(islandWidthExpanded, forKey: "nb_islandWidthExpanded") }
    }
    @Published public var islandHeightExpanded: Double {
        didSet { defaults.set(islandHeightExpanded, forKey: "nb_islandHeightExpanded") }
    }
    
    // MARK: - Compact Ears
    @Published public var leftEarContent: LeftEarIndicator {
        didSet { defaults.set(leftEarContent.rawValue, forKey: "nb_leftEarContent") }
    }
    @Published public var rightEarContent: RightEarIndicator {
        didSet { defaults.set(rightEarContent.rawValue, forKey: "nb_rightEarContent") }
    }
    @Published public var showCaffeineInCompact: Bool {
        didSet { defaults.set(showCaffeineInCompact, forKey: "nb_showCaffeineInCompact") }
    }
    @Published public var compactEarWidth: Double {
        didSet { defaults.set(compactEarWidth, forKey: "nb_compactEarWidth") }
    }
    
    // MARK: - System Telemetry
    @Published public var telemetryRate: TelemetryRate {
        didSet { defaults.set(telemetryRate.rawValue, forKey: "nb_telemetryRate") }
    }
    @Published public var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: "nb_temperatureUnit") }
    }
    @Published public var highCPUThreshold: Int {
        didSet { defaults.set(highCPUThreshold, forKey: "nb_highCPUThreshold") }
    }
    @Published public var lowBatteryThreshold: Int {
        didSet { defaults.set(lowBatteryThreshold, forKey: "nb_lowBatteryThreshold") }
    }
    @Published public var showMetalGPU: Bool {
        didSet { defaults.set(showMetalGPU, forKey: "nb_showMetalGPU") }
    }
    
    // MARK: - Drop Shelf
    @Published public var autoOpenShelfOnDrag: Bool {
        didSet { defaults.set(autoOpenShelfOnDrag, forKey: "nb_autoOpenShelfOnDrag") }
    }
    @Published public var retainFilesAfterDragOut: Bool {
        didSet { defaults.set(retainFilesAfterDragOut, forKey: "nb_retainFilesAfterDragOut") }
    }
    @Published public var showFileSizeBadge: Bool {
        didSet { defaults.set(showFileSizeBadge, forKey: "nb_showFileSizeBadge") }
    }
    @Published public var shelfCapacity: Int {
        didSet { defaults.set(shelfCapacity, forKey: "nb_shelfCapacity") }
    }
    
    // MARK: - Media & HUD
    @Published public var hudOnTrackChange: Bool {
        didSet { defaults.set(hudOnTrackChange, forKey: "nb_hudOnTrackChange") }
    }
    @Published public var visualizerBarsCount: Int {
        didSet { defaults.set(visualizerBarsCount, forKey: "nb_visualizerBarsCount") }
    }
    @Published public var hudDuration: Double {
        didSet { defaults.set(hudDuration, forKey: "nb_hudDuration") }
    }
    @Published public var enableVolumeHUD: Bool {
        didSet { defaults.set(enableVolumeHUD, forKey: "nb_enableVolumeHUD") }
    }
    @Published public var enableBrightnessHUD: Bool {
        didSet { defaults.set(enableBrightnessHUD, forKey: "nb_enableBrightnessHUD") }
    }
    @Published public var enableCapsLockHUD: Bool {
        didSet { defaults.set(enableCapsLockHUD, forKey: "nb_enableCapsLockHUD") }
    }
    @Published public var enableAirDropAlerts: Bool {
        didSet { defaults.set(enableAirDropAlerts, forKey: "nb_enableAirDropAlerts") }
    }
    @Published public var enableCallDetection: Bool {
        didSet { defaults.set(enableCallDetection, forKey: "nb_enableCallDetection") }
    }
    
    // MARK: - AI Code Agents
    @Published public var agentPort: Int {
        didSet { defaults.set(agentPort, forKey: "nb_agentPort") }
    }
    @Published public var autoDetectAgents: Bool {
        didSet { defaults.set(autoDetectAgents, forKey: "nb_autoDetectAgents") }
    }
    @Published public var autoExpandOnToolPermission: Bool {
        didSet { defaults.set(autoExpandOnToolPermission, forKey: "nb_autoExpandOnToolPermission") }
    }
    @Published public var playAgentSoundNotification: Bool {
        didSet { defaults.set(playAgentSoundNotification, forKey: "nb_playAgentSoundNotification") }
    }
    
    // MARK: - Focus & Timers
    @Published public var pomodoroWorkMinutes: Int {
        didSet { defaults.set(pomodoroWorkMinutes, forKey: "nb_pomodoroWorkMinutes") }
    }
    @Published public var pomodoroShortBreakMinutes: Int {
        didSet { defaults.set(pomodoroShortBreakMinutes, forKey: "nb_pomodoroShortBreakMinutes") }
    }
    @Published public var pomodoroLongBreakMinutes: Int {
        didSet { defaults.set(pomodoroLongBreakMinutes, forKey: "nb_pomodoroLongBreakMinutes") }
    }
    @Published public var soundOnTimerFinished: Bool {
        didSet { defaults.set(soundOnTimerFinished, forKey: "nb_soundOnTimerFinished") }
    }
    @Published public var rulerTickSounds: Bool {
        didSet { defaults.set(rulerTickSounds, forKey: "nb_rulerTickSounds") }
    }
    
    // MARK: - Initializer with Defaults
    private init() {
        self.launchAtLogin = defaults.object(forKey: "nb_launchAtLogin") as? Bool ?? false
        self.showInDock = defaults.object(forKey: "nb_showInDock") as? Bool ?? false
        self.hoverToExpand = defaults.object(forKey: "nb_hoverToExpand") as? Bool ?? true
        self.hoverDelay = defaults.object(forKey: "nb_hoverDelay") as? Double ?? 0.15
        self.autoCollapseOnClickOutside = defaults.object(forKey: "nb_autoCollapseOnClickOutside") as? Bool ?? true
        self.keepOpenOnDropShelf = defaults.object(forKey: "nb_keepOpenOnDropShelf") as? Bool ?? true
        
        let savedAccent = defaults.string(forKey: "nb_accentColor") ?? AccentColorChoice.cyan.rawValue
        self.accentColor = AccentColorChoice(rawValue: savedAccent) ?? .cyan
        
        let savedGlass = defaults.string(forKey: "nb_glassMaterial") ?? GlassMaterialChoice.trueBlack.rawValue
        self.glassMaterial = GlassMaterialChoice(rawValue: savedGlass) ?? .trueBlack
        
        self.enableNeonGlow = defaults.object(forKey: "nb_enableNeonGlow") as? Bool ?? true
        self.glowIntensity = defaults.object(forKey: "nb_glowIntensity") as? Double ?? 0.8
        self.notchCornerRadius = defaults.object(forKey: "nb_notchCornerRadius") as? Double ?? 26.0
        self.floatingIslandMode = defaults.object(forKey: "nb_floatingIslandMode") as? Bool ?? false
        self.floatingTopMargin = defaults.object(forKey: "nb_floatingTopMargin") as? Double ?? 12.0
        self.islandWidthExpanded = defaults.object(forKey: "nb_islandWidthExpanded") as? Double ?? 570.0
        self.islandHeightExpanded = defaults.object(forKey: "nb_islandHeightExpanded") as? Double ?? 270.0
        
        let savedLeftEar = defaults.string(forKey: "nb_leftEarContent") ?? LeftEarIndicator.musicVisualizer.rawValue
        self.leftEarContent = LeftEarIndicator(rawValue: savedLeftEar) ?? .musicVisualizer
        
        let savedRightEar = defaults.string(forKey: "nb_rightEarContent") ?? RightEarIndicator.networkSpeed.rawValue
        self.rightEarContent = RightEarIndicator(rawValue: savedRightEar) ?? .networkSpeed
        
        self.showCaffeineInCompact = defaults.object(forKey: "nb_showCaffeineInCompact") as? Bool ?? true
        self.compactEarWidth = defaults.object(forKey: "nb_compactEarWidth") as? Double ?? 74.0
        
        let savedRate = defaults.double(forKey: "nb_telemetryRate")
        self.telemetryRate = TelemetryRate(rawValue: savedRate > 0 ? savedRate : 1.0) ?? .normal
        
        let savedTemp = defaults.string(forKey: "nb_temperatureUnit") ?? TemperatureUnit.celsius.rawValue
        self.temperatureUnit = TemperatureUnit(rawValue: savedTemp) ?? .celsius
        
        self.highCPUThreshold = defaults.object(forKey: "nb_highCPUThreshold") as? Int ?? 80
        self.lowBatteryThreshold = defaults.object(forKey: "nb_lowBatteryThreshold") as? Int ?? 20
        self.showMetalGPU = defaults.object(forKey: "nb_showMetalGPU") as? Bool ?? true
        
        self.autoOpenShelfOnDrag = defaults.object(forKey: "nb_autoOpenShelfOnDrag") as? Bool ?? true
        self.retainFilesAfterDragOut = defaults.object(forKey: "nb_retainFilesAfterDragOut") as? Bool ?? false
        self.showFileSizeBadge = defaults.object(forKey: "nb_showFileSizeBadge") as? Bool ?? true
        self.shelfCapacity = defaults.object(forKey: "nb_shelfCapacity") as? Int ?? 10
        
        self.hudOnTrackChange = defaults.object(forKey: "nb_hudOnTrackChange") as? Bool ?? true
        self.visualizerBarsCount = defaults.object(forKey: "nb_visualizerBarsCount") as? Int ?? 5
        self.hudDuration = defaults.object(forKey: "nb_hudDuration") as? Double ?? 2.2
        self.enableVolumeHUD = defaults.object(forKey: "nb_enableVolumeHUD") as? Bool ?? true
        self.enableBrightnessHUD = defaults.object(forKey: "nb_enableBrightnessHUD") as? Bool ?? true
        self.enableCapsLockHUD = defaults.object(forKey: "nb_enableCapsLockHUD") as? Bool ?? true
        self.enableAirDropAlerts = defaults.object(forKey: "nb_enableAirDropAlerts") as? Bool ?? true
        self.enableCallDetection = defaults.object(forKey: "nb_enableCallDetection") as? Bool ?? true
        
        self.agentPort = defaults.object(forKey: "nb_agentPort") as? Int ?? 19842
        self.autoDetectAgents = defaults.object(forKey: "nb_autoDetectAgents") as? Bool ?? true
        self.autoExpandOnToolPermission = defaults.object(forKey: "nb_autoExpandOnToolPermission") as? Bool ?? true
        self.playAgentSoundNotification = defaults.object(forKey: "nb_playAgentSoundNotification") as? Bool ?? true
        
        self.pomodoroWorkMinutes = defaults.object(forKey: "nb_pomodoroWorkMinutes") as? Int ?? 25
        self.pomodoroShortBreakMinutes = defaults.object(forKey: "nb_pomodoroShortBreakMinutes") as? Int ?? 5
        self.pomodoroLongBreakMinutes = defaults.object(forKey: "nb_pomodoroLongBreakMinutes") as? Int ?? 15
        self.soundOnTimerFinished = defaults.object(forKey: "nb_soundOnTimerFinished") as? Bool ?? true
        self.rulerTickSounds = defaults.object(forKey: "nb_rulerTickSounds") as? Bool ?? true
    }
    
    public func updateActivationPolicy() {
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    public func resetToDefaults() {
        launchAtLogin = false
        showInDock = false
        hoverToExpand = true
        hoverDelay = 0.15
        autoCollapseOnClickOutside = true
        keepOpenOnDropShelf = true
        
        accentColor = .cyan
        glassMaterial = .trueBlack
        enableNeonGlow = true
        glowIntensity = 0.8
        notchCornerRadius = 26.0
        floatingIslandMode = false
        floatingTopMargin = 12.0
        islandWidthExpanded = 570.0
        islandHeightExpanded = 270.0
        
        leftEarContent = .musicVisualizer
        rightEarContent = .networkSpeed
        showCaffeineInCompact = true
        compactEarWidth = 74.0
        
        telemetryRate = .normal
        temperatureUnit = .celsius
        highCPUThreshold = 80
        lowBatteryThreshold = 20
        showMetalGPU = true
        
        autoOpenShelfOnDrag = true
        retainFilesAfterDragOut = false
        showFileSizeBadge = true
        shelfCapacity = 10
        
        hudOnTrackChange = true
        visualizerBarsCount = 5
        hudDuration = 2.2
        enableVolumeHUD = true
        enableBrightnessHUD = true
        enableCapsLockHUD = true
        enableAirDropAlerts = true
        enableCallDetection = true
        
        agentPort = 19842
        autoDetectAgents = true
        autoExpandOnToolPermission = true
        playAgentSoundNotification = true
        
        pomodoroWorkMinutes = 25
        pomodoroShortBreakMinutes = 5
        pomodoroLongBreakMinutes = 15
        soundOnTimerFinished = true
        rulerTickSounds = true
    }
}
