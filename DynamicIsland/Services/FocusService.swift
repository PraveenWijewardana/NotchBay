import Foundation
import AppKit
import Combine

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

@MainActor
public final class FocusService: ObservableObject {
    @Published public var isActive: Bool = false
    @Published public var focusType: FocusModeType = .dnd
    @Published public var selectedDuration: FocusDurationPreset = .minutes25
    @Published public var remainingSeconds: Int = 25 * 60
    @Published public var totalSeconds: Int = 25 * 60
    
    public var onFocusChanged: ((Bool, String, String) -> Void)?
    
    private var countdownTimer: Timer?
    
    public init() {}
    
    public var formattedRemainingTime: String {
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
            return isActive ? 1.0 : 0.0
        }
        let elapsed = Double(totalSeconds - remainingSeconds)
        return min(max(elapsed / Double(totalSeconds), 0.0), 1.0)
    }
    
    public func toggleFocus() {
        if isActive {
            stopFocus()
        } else {
            startFocus()
        }
    }
    
    public func startFocus(preset: FocusDurationPreset? = nil, type: FocusModeType? = nil) {
        if let preset = preset {
            self.selectedDuration = preset
        }
        if let type = type {
            self.focusType = type
        }
        
        let seconds = (selectedDuration == .indefinite) ? 0 : selectedDuration.rawValue * 60
        self.remainingSeconds = seconds
        self.totalSeconds = seconds
        self.isActive = true
        
        // Execute system DND / Focus shortcut if configured
        executeSystemFocusToggle(activate: true)
        
        // Countdown timer
        countdownTimer?.invalidate()
        if selectedDuration != .indefinite {
            let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isActive else { return }
                    if self.remainingSeconds > 0 {
                        self.remainingSeconds -= 1
                    } else {
                        self.focusSessionCompleted()
                    }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.countdownTimer = timer
        }
        
        onFocusChanged?(true, focusType.rawValue, selectedDuration.displayTitle)
    }
    
    public func stopFocus() {
        guard isActive else { return }
        isActive = false
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        executeSystemFocusToggle(activate: false)
        
        onFocusChanged?(false, focusType.rawValue, "Ended")
    }
    
    public func setPreset(_ preset: FocusDurationPreset) {
        self.selectedDuration = preset
        if !isActive {
            let sec = preset.rawValue * 60
            self.remainingSeconds = sec
            self.totalSeconds = sec
        }
    }
    
    private func focusSessionCompleted() {
        stopFocus()
        NSSound(named: "Glass")?.play()
        onFocusChanged?(false, "Session Complete", "🎉 Break Time")
    }
    
    private func executeSystemFocusToggle(activate: Bool) {
        // Runs in background process to avoid blocking UI
        DispatchQueue.global(qos: .utility).async {
            let shortcutName = activate ? "Turn On Do Not Disturb" : "Turn Off Do Not Disturb"
            let genericShortcut = "Toggle Focus"
            
            // Try specific shortcut first, then generic toggle
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            task.arguments = ["run", activate ? shortcutName : genericShortcut]
            
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                // Fails silently if user has not set up Shortcuts app focus actions
            }
        }
    }
}
