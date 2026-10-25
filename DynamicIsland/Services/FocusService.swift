import Foundation
import AppKit
import Combine
import Intents

// MARK: - Apple Focus Mode Model
public struct AppleFocusMode: Identifiable, Hashable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let iconName: String
    public let isBuiltIn: Bool
    
    public init(id: String, name: String, iconName: String, isBuiltIn: Bool = true) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.isBuiltIn = isBuiltIn
    }
    
    public static let doNotDisturb = AppleFocusMode(id: "com.apple.donotdisturb.mode.default", name: "Do Not Disturb", iconName: "moon.fill")
    public static let work = AppleFocusMode(id: "com.apple.donotdisturb.mode.work", name: "Work", iconName: "briefcase.fill")
    public static let personal = AppleFocusMode(id: "com.apple.donotdisturb.mode.personal", name: "Personal", iconName: "person.fill")
    public static let sleep = AppleFocusMode(id: "com.apple.donotdisturb.mode.sleep", name: "Sleep", iconName: "bed.double.fill")
    public static let reading = AppleFocusMode(id: "com.apple.donotdisturb.mode.reading", name: "Reading", iconName: "book.fill")
    public static let gaming = AppleFocusMode(id: "com.apple.donotdisturb.mode.gaming", name: "Gaming", iconName: "gamecontroller.fill")
    public static let fitness = AppleFocusMode(id: "com.apple.donotdisturb.mode.fitness", name: "Fitness", iconName: "figure.run")
    
    public static let defaultModes: [AppleFocusMode] = [
        .doNotDisturb,
        .work,
        .personal,
        .sleep,
        .reading,
        .gaming,
        .fitness
    ]
}

// MARK: - Legacy Types for Backward Compatibility
public enum FocusModeType: String, CaseIterable, Identifiable, Sendable {
    case dnd = "Do Not Disturb"
    case deepFocus = "Deep Focus"
    case work = "Work"
    case personal = "Personal"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .dnd: return "moon.fill"
        case .deepFocus: return "brain.head.profile"
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        }
    }
}

public enum FocusDurationPreset: Int, CaseIterable, Identifiable, Sendable {
    case minutes15 = 15
    case minutes25 = 25
    case minutes45 = 45
    case minutes60 = 60
    case indefinite = 0
    
    public var id: Int { rawValue }
    
    public var displayTitle: String {
        switch self {
        case .minutes15: return "15m"
        case .minutes25: return "25m"
        case .minutes45: return "45m"
        case .minutes60: return "60m"
        case .indefinite: return "∞"
        }
    }
}

// MARK: - Focus Service with Apple Focus Synchronization
@MainActor
public final class FocusService: ObservableObject {
    // Real Apple Focus Synchronization state
    @Published public var isAppleFocusActive: Bool = false
    @Published public var activeMode: AppleFocusMode? = nil
    @Published public var availableModes: [AppleFocusMode] = AppleFocusMode.defaultModes
    @Published public var activeModeName: String = "Focus Off"
    @Published public var activeModeIcon: String = "moon.fill"
    @Published public var statusSubtitle: String = "Tap to Switch"
    @Published public var lastKnownActiveMode: AppleFocusMode = .doNotDisturb
    
    // Legacy properties for backward compatibility
    @Published public var isActive: Bool = false
    @Published public var focusType: FocusModeType = .dnd
    @Published public var selectedDuration: FocusDurationPreset = .minutes25
    @Published public var remainingSeconds: Int = 25 * 60
    @Published public var totalSeconds: Int = 25 * 60
    
    public var onFocusChanged: ((Bool, String, String) -> Void)?
    
    private var monitoringTimer: Timer?
    private var countdownTimer: Timer?
    private var isRefreshing: Bool = false
    
    public init() {
        // Restore last known mode preference
        if let savedName = UserDefaults.standard.string(forKey: "notchbay.last_focus_mode_name") {
            if let matched = AppleFocusMode.defaultModes.first(where: { $0.name == savedName }) {
                self.lastKnownActiveMode = matched
            }
        }
        
        // Initial setup and check
        loadAvailableAppleModes()
        refreshFocusState()
        
        // Start continuous background sync
        setupDistributedNotificationObservers()
        startMonitoringTimer()
    }
    
    deinit {
        monitoringTimer?.invalidate()
        countdownTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    // MARK: - Formatted Properties
    public var formattedRemainingTime: String {
        if isAppleFocusActive {
            return activeModeName
        }
        guard isActive else {
            return selectedDuration.displayTitle
        }
        if selectedDuration == .indefinite {
            return "Active"
        }
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    public var progress: Double {
        guard isActive, totalSeconds > 0, selectedDuration != .indefinite else {
            return (isActive || isAppleFocusActive) ? 1.0 : 0.0
        }
        let elapsed = Double(totalSeconds - remainingSeconds)
        return min(max(elapsed / Double(totalSeconds), 0.0), 1.0)
    }
    
    // MARK: - Query & Sync Apple Focus State
    public func refreshFocusState() {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        
        // Step 1: Attempt to read macOS DoNotDisturb database files
        let (hasActiveAssertion, activeModeId) = checkAssertionsDatabase()
        
        var newIsActive = false
        var newMode: AppleFocusMode? = nil
        
        if hasActiveAssertion {
            newIsActive = true
            if let modeId = activeModeId {
                newMode = matchMode(for: modeId)
            } else {
                newMode = lastKnownActiveMode
            }
        } else {
            // Step 2: Fallback to Apple Intents INFocusStatusCenter
            let intentsStatus = checkIntentsFocusStatus()
            if let isFocused = intentsStatus {
                newIsActive = isFocused
                if isFocused {
                    newMode = activeMode ?? lastKnownActiveMode
                }
            }
        }
        
        // Step 3: Apply state updates
        let stateChanged = (self.isAppleFocusActive != newIsActive) || (newMode != nil && self.activeMode?.id != newMode?.id)
        
        self.isAppleFocusActive = newIsActive
        self.isActive = newIsActive
        
        if newIsActive {
            let mode = newMode ?? lastKnownActiveMode
            self.activeMode = mode
            self.activeModeName = mode.name
            self.activeModeIcon = mode.iconName
            self.statusSubtitle = "Apple Focus • On"
            self.lastKnownActiveMode = mode
        } else {
            self.activeMode = nil
            self.activeModeName = "Focus Off"
            self.activeModeIcon = "moon.fill"
            self.statusSubtitle = "Tap to Switch"
        }
        
        if stateChanged {
            onFocusChanged?(newIsActive, self.activeModeName, newIsActive ? "Active" : "Off")
        }
    }
    
    // MARK: - Apple Focus Mode Control (Sync with Apple)
    public func setAppleFocus(mode: AppleFocusMode) {
        // Immediate UI responsiveness
        self.isAppleFocusActive = true
        self.isActive = true
        self.activeMode = mode
        self.activeModeName = mode.name
        self.activeModeIcon = mode.iconName
        self.statusSubtitle = "Apple Focus • On"
        self.lastKnownActiveMode = mode
        
        UserDefaults.standard.set(mode.id, forKey: "notchbay.last_focus_mode_id")
        UserDefaults.standard.set(mode.name, forKey: "notchbay.last_focus_mode_name")
        
        // Execute system command
        executeSystemFocusChange(mode: mode, activate: true)
        
        onFocusChanged?(true, mode.name, "Active")
        
        // Verify state after slight system delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refreshFocusState()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.refreshFocusState()
        }
    }
    
    public func turnOffAppleFocus() {
        self.isAppleFocusActive = false
        self.isActive = false
        self.activeMode = nil
        self.activeModeName = "Focus Off"
        self.activeModeIcon = "moon.fill"
        self.statusSubtitle = "Tap to Switch"
        
        executeSystemFocusChange(mode: lastKnownActiveMode, activate: false)
        
        onFocusChanged?(false, "Focus Off", "Turned Off")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refreshFocusState()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.refreshFocusState()
        }
    }
    
    public func toggleAppleFocus() {
        if isAppleFocusActive {
            turnOffAppleFocus()
        } else {
            setAppleFocus(mode: lastKnownActiveMode)
        }
    }
    
    public func toggleFocus() {
        toggleAppleFocus()
    }
    
    public func openFocusSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - System Execution Helpers
    private func executeSystemFocusChange(mode: AppleFocusMode, activate: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Attempt 1: Run Shortcuts CLI
            let candidateShortcuts: [String]
            if activate {
                candidateShortcuts = [
                    "Set Focus \(mode.name)",
                    "Turn On \(mode.name)",
                    mode.name,
                    "Turn On Do Not Disturb",
                    "Toggle Focus",
                    "Set Focus"
                ]
            } else {
                candidateShortcuts = [
                    "Turn Off Focus",
                    "Turn Off \(mode.name)",
                    "Turn Off Do Not Disturb",
                    "Focus Off",
                    "Toggle Focus"
                ]
            }
            
            var didSucceed = false
            for shortcut in candidateShortcuts {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                task.arguments = ["run", shortcut]
                do {
                    try task.run()
                    task.waitUntilExit()
                    if task.terminationStatus == 0 {
                        didSucceed = true
                        break
                    }
                } catch {
                    continue
                }
            }
            
            // Attempt 2: AppleScript Shortcuts Events
            if !didSucceed {
                let scriptName = activate ? mode.name : "Turn Off Focus"
                let script = "tell application \"Shortcuts Events\" to try\nrun shortcut \"\(scriptName)\"\nend try"
                if let appleScript = NSAppleScript(source: script) {
                    var errorDict: NSDictionary?
                    appleScript.executeAndReturnError(&errorDict)
                }
            }
            
            // Post Distributed Notification
            DispatchQueue.main.async {
                DistributedNotificationCenter.default().postNotificationName(
                    NSNotification.Name("com.apple.notificationcenterui.dndprefs_changed"),
                    object: nil,
                    userInfo: nil,
                    deliverImmediately: true
                )
            }
        }
    }
    
    // MARK: - Database Inspection Helpers
    private func loadAvailableAppleModes() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configURL = home.appendingPathComponent("Library/DoNotDisturb/DB/ModeConfigurations.json")
        
        guard FileManager.default.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            return
        }
        
        var discoveredModes = AppleFocusMode.defaultModes
        
        for item in dataArray {
            guard let modeConfigs = item["modeConfigurations"] as? [String: [String: Any]] else { continue }
            for (modeId, config) in modeConfigs {
                guard let modeDict = config["mode"] as? [String: Any],
                      let name = modeDict["name"] as? String, !name.isEmpty else { continue }
                
                let symbol = (modeDict["symbolImageName"] as? String) ?? iconForModeName(name)
                let isBuiltIn = modeId.contains("mode.default") || modeId.contains("apple")
                let newMode = AppleFocusMode(id: modeId, name: name, iconName: symbol, isBuiltIn: isBuiltIn)
                
                if let idx = discoveredModes.firstIndex(where: { $0.id == modeId || $0.name.lowercased() == name.lowercased() }) {
                    discoveredModes[idx] = newMode
                } else {
                    discoveredModes.append(newMode)
                }
            }
        }
        
        self.availableModes = discoveredModes
    }
    
    private func checkAssertionsDatabase() -> (Bool, String?) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let assertionsURL = home.appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")
        
        guard FileManager.default.fileExists(atPath: assertionsURL.path),
          let data = try? Data(contentsOf: assertionsURL),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let dataArray = json["data"] as? [[String: Any]] else {
            return (false, nil)
        }
        
        for item in dataArray {
            let records = (item["storeAssertionRecords"] as? [[String: Any]]) ?? (item["assertions"] as? [[String: Any]]) ?? []
            if !records.isEmpty {
                for record in records {
                    if let details = record["assertionDetails"] as? [String: Any] {
                        if let modeId = details["assertionDetailsModeIdentifier"] as? String, !modeId.isEmpty {
                            return (true, modeId)
                        }
                        if let modeId = details["modeIdentifier"] as? String, !modeId.isEmpty {
                            return (true, modeId)
                        }
                    }
                    if let modeId = record["modeIdentifier"] as? String, !modeId.isEmpty {
                        return (true, modeId)
                    }
                }
                return (true, nil)
            }
        }
        
        return (false, nil)
    }
    
    private func checkIntentsFocusStatus() -> Bool? {
        let center = INFocusStatusCenter.default
        guard center.authorizationStatus == .authorized else { return nil }
        return center.focusStatus.isFocused
    }
    
    private func matchMode(for modeId: String) -> AppleFocusMode {
        if let exact = availableModes.first(where: { $0.id == modeId }) {
            return exact
        }
        let lower = modeId.lowercased()
        if lower.contains("work") {
            return AppleFocusMode.work
        } else if lower.contains("sleep") {
            return AppleFocusMode.sleep
        } else if lower.contains("personal") {
            return AppleFocusMode.personal
        } else if lower.contains("reading") {
            return AppleFocusMode.reading
        } else if lower.contains("game") || lower.contains("gaming") {
            return AppleFocusMode.gaming
        } else if lower.contains("fitness") {
            return AppleFocusMode.fitness
        }
        return AppleFocusMode.doNotDisturb
    }
    
    private func iconForModeName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("work") { return "briefcase.fill" }
        if lower.contains("sleep") { return "bed.double.fill" }
        if lower.contains("personal") { return "person.fill" }
        if lower.contains("read") { return "book.fill" }
        if lower.contains("game") { return "gamecontroller.fill" }
        if lower.contains("fitness") || lower.contains("workout") { return "figure.run" }
        if lower.contains("code") || lower.contains("develop") { return "chevron.left.forwardslash.chevron.right" }
        if lower.contains("study") { return "graduationcap.fill" }
        return "moon.fill"
    }
    
    // MARK: - Notifications and Timer
    private func setupDistributedNotificationObservers() {
        let dnc = DistributedNotificationCenter.default()
        let names = [
            "com.apple.donotdisturb.mode.state-changed",
            "_NSDoNotDisturbEnabledNotification",
            "_NSDoNotDisturbDisabledNotification",
            "com.apple.notificationcenterui.dndprefs_changed"
        ]
        for name in names {
            dnc.addObserver(
                self,
                selector: #selector(systemFocusNotificationReceived(_:)),
                name: NSNotification.Name(name),
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }
    }
    
    @objc private func systemFocusNotificationReceived(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.refreshFocusState()
        }
    }
    
    private func startMonitoringTimer() {
        monitoringTimer?.invalidate()
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshFocusState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.monitoringTimer = timer
    }
    
    // MARK: - Legacy Countdown Methods
    public func startFocus(preset: FocusDurationPreset? = nil, type: FocusModeType? = nil) {
        if let type = type {
            self.focusType = type
            if let matched = availableModes.first(where: { $0.name.lowercased() == type.rawValue.lowercased() }) {
                setAppleFocus(mode: matched)
                return
            }
        }
        setAppleFocus(mode: lastKnownActiveMode)
    }
    
    public func stopFocus() {
        turnOffAppleFocus()
    }
    
    public func setPreset(_ preset: FocusDurationPreset) {
        self.selectedDuration = preset
        let sec = preset.rawValue * 60
        self.remainingSeconds = sec
        self.totalSeconds = sec
    }
}
