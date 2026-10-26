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
    
    // User Session tracking to keep focus active in NotchBay even when no shortcut is installed
    @Published public var isUserSessionActive: Bool = false
    private var lastSystemAssertionState: Bool = false
    
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
        requestAuthorizationIfNeeded()
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
        
        // Step 1: Attempt to check active focus from DB, helper shortcut, INFocusStatusCenter, or Control Center preferences
        var hasActiveAssertion = false
        var detectedMode: AppleFocusMode? = nil
        
        let dbResult = checkAssertionsDatabase()
        if dbResult.0 {
            hasActiveAssertion = true
            if let id = dbResult.1 {
                detectedMode = matchMode(for: id)
            }
        }
        
        // Step 2: If DB access is blocked by macOS TCC, try querying helper shortcut if installed
        if detectedMode == nil {
            if let shortcutMode = queryActiveFocusViaShortcut() {
                hasActiveAssertion = true
                detectedMode = shortcutMode
            }
        }
        
        // Step 3: Check system status indicators
        if !hasActiveAssertion {
            if let intentsFocused = checkIntentsFocusStatus(), intentsFocused {
                hasActiveAssertion = true
            } else if checkControlCenterFocusActive() {
                hasActiveAssertion = true
            }
        }
        
        var newIsActive = false
        var newMode: AppleFocusMode? = nil
        
        if hasActiveAssertion {
            // macOS system has an active Focus mode confirmed
            self.lastSystemAssertionState = true
            newIsActive = true
            if let mode = detectedMode {
                newMode = mode
            } else if isUserSessionActive, let cur = self.activeMode {
                // User explicitly selected this mode in NotchBay
                newMode = cur
            } else {
                // Generic Apple Focus is on, but exact profile is not yet specified
                newMode = nil
            }
        } else {
            // macOS system has NO active assertion
            if lastSystemAssertionState == true {
                // System focus was previously active and was turned off externally in macOS
                self.lastSystemAssertionState = false
                self.isUserSessionActive = false
                newIsActive = false
            } else if isUserSessionActive, let cur = self.activeMode {
                // User started a session inside NotchBay, keep it alive
                newIsActive = true
                newMode = cur
            } else {
                newIsActive = false
            }
        }
        
        // Step 4: Apply state updates
        let stateChanged = (self.isAppleFocusActive != newIsActive) || (newMode?.id != self.activeMode?.id)
        
        self.isAppleFocusActive = newIsActive
        self.isActive = newIsActive
        
        if newIsActive {
            if let mode = newMode {
                self.activeMode = mode
                self.activeModeName = mode.name
                self.activeModeIcon = mode.iconName
                self.lastKnownActiveMode = mode
            } else {
                self.activeMode = nil
                self.activeModeName = "Focus"
                self.activeModeIcon = "moon.fill"
            }
            self.statusSubtitle = "Active"
        } else {
            self.activeMode = nil
            self.activeModeName = "Focus"
            self.activeModeIcon = "moon.fill"
            self.statusSubtitle = "Off"
        }
        
        if stateChanged {
            onFocusChanged?(newIsActive, self.activeModeName, newIsActive ? "Active" : "Off")
        }
    }
    
    // MARK: - Apple Focus Mode Control (Sync with Apple)
    public func setAppleFocus(mode: AppleFocusMode) {
        // Immediate UI responsiveness
        self.isUserSessionActive = true
        self.isAppleFocusActive = true
        self.isActive = true
        self.activeMode = mode
        self.activeModeName = mode.name
        self.activeModeIcon = mode.iconName
        self.statusSubtitle = "Active"
        self.lastKnownActiveMode = mode
        
        UserDefaults.standard.set(mode.id, forKey: "notchbay.last_focus_mode_id")
        UserDefaults.standard.set(mode.name, forKey: "notchbay.last_focus_mode_name")
        
        // Execute system command safely without stderr noise
        executeSystemFocusChange(mode: mode, activate: true)
        
        onFocusChanged?(true, mode.name, "Active")
    }
    
    public func turnOffAppleFocus() {
        self.isUserSessionActive = false
        self.isAppleFocusActive = false
        self.isActive = false
        self.activeMode = nil
        self.activeModeName = "Focus"
        self.activeModeIcon = "moon.fill"
        self.statusSubtitle = "Off"
        
        executeSystemFocusChange(mode: lastKnownActiveMode, activate: false)
        
        onFocusChanged?(false, "Focus", "Turned Off")
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
    
    public func openShortcutsApp() {
        if let url = URL(string: "shortcuts:") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
        }
    }
    
    public func installSyncShortcut() {
        if let url = Bundle.main.url(forResource: "Get_Current_Focus", withExtension: "shortcut") {
            NSWorkspace.shared.open(url)
        } else {
            let tmpURL = URL(fileURLWithPath: "/tmp/Get_Current_Focus.shortcut")
            if FileManager.default.fileExists(atPath: tmpURL.path) {
                NSWorkspace.shared.open(tmpURL)
            }
        }
    }
    
    public func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func queryActiveFocusViaShortcut() -> AppleFocusMode? {
        let shortcuts = getInstalledShortcuts()
        guard let shortcut = shortcuts.first(where: {
            let lower = $0.lowercased()
            return lower == "get current focus" || lower == "current focus" || lower == "get focus"
        }) else { return nil }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", shortcut]
        let stdout = Pipe()
        task.standardOutput = stdout
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                if output.lowercased() != "none" && output.lowercased() != "off" {
                    return matchMode(for: output)
                }
            }
        } catch {}
        return nil
    }
    
    // MARK: - System Execution Helpers
    private func executeSystemFocusChange(mode: AppleFocusMode, activate: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Check installed shortcuts silently (with standardError suppressed)
            let installed = self.getInstalledShortcuts()
            var didSucceed = false
            
            if let matched = self.findShortcut(matching: mode, activate: activate, available: installed) {
                didSucceed = self.runShortcut(named: matched)
            }
            
            // 2. If no shortcut matched, attempt AppleScript UI script on Control Center
            if !didSucceed {
                didSucceed = self.triggerControlCenterFocus()
            }
            
            // 3. Post Distributed Notification
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
    
    private nonisolated func getInstalledShortcuts() -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["list"]
        let stdout = Pipe()
        task.standardOutput = stdout
        task.standardError = Pipe() // Silence any stderr
        do {
            try task.run()
            task.waitUntilExit()
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        } catch {}
        return []
    }
    
    private nonisolated func findShortcut(matching mode: AppleFocusMode, activate: Bool, available: [String]) -> String? {
        let modeName = mode.name.lowercased()
        
        let candidates: [String] = activate ? [
            "set focus \(modeName)",
            "turn on \(modeName)",
            "enable \(modeName)",
            modeName,
            "turn on focus",
            "set focus",
            "toggle focus",
            "focus",
            "turn on do not disturb",
            "do not disturb",
            "dnd"
        ] : [
            "turn off \(modeName)",
            "disable \(modeName)",
            "turn off focus",
            "focus off",
            "disable focus",
            "toggle focus",
            "turn off do not disturb",
            "do not disturb",
            "dnd"
        ]
        
        for candidate in candidates {
            if let match = available.first(where: { $0.lowercased() == candidate }) {
                return match
            }
        }
        
        if let match = available.first(where: { $0.lowercased().contains(modeName) }) {
            return match
        }
        
        if let match = available.first(where: { $0.lowercased().contains("focus") || $0.lowercased().contains("dnd") }) {
            return match
        }
        
        return nil
    }
    
    @discardableResult
    private nonisolated func runShortcut(named shortcut: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", shortcut]
        task.standardOutput = Pipe()
        task.standardError = Pipe() // Silence any errors
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    @discardableResult
    private nonisolated func triggerControlCenterFocus() -> Bool {
        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                try
                    click (first menu bar item of menu bar 1 whose description contains "Focus" or description contains "Do Not Disturb")
                    return true
                on error
                    try
                        click menu bar item "Control Center" of menu bar 1
                        delay 0.15
                        click (first checkbox of group 1 of window 1 whose title contains "Focus" or description contains "Focus")
                        delay 0.1
                        key code 53
                        return true
                    on error
                        return false
                    end try
                end try
            end tell
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var errorDict: NSDictionary?
            let result = appleScript.executeAndReturnError(&errorDict)
            return errorDict == nil && result.booleanValue
        }
        return false
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
    
    public func requestAuthorizationIfNeeded() {
        let center = INFocusStatusCenter.default
        if center.authorizationStatus == .notDetermined {
            center.requestAuthorization { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshFocusState()
                }
            }
        }
    }
    
    private func checkIntentsFocusStatus() -> Bool? {
        let center = INFocusStatusCenter.default
        if center.authorizationStatus == .notDetermined {
            requestAuthorizationIfNeeded()
            return nil
        }
        guard center.authorizationStatus == .authorized else { return nil }
        return center.focusStatus.isFocused
    }
    
    private func checkControlCenterFocusActive() -> Bool {
        // macOS Sonoma/Sequoia sets "NSStatusItem Visible FocusModes" = 1 in com.apple.controlcenter when Focus is on
        if let val = CFPreferencesCopyAppValue("NSStatusItem Visible FocusModes" as CFString, "com.apple.controlcenter" as CFString) {
            if let num = val as? NSNumber {
                return num.boolValue
            } else if let b = val as? Bool {
                return b
            }
        }
        return false
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
