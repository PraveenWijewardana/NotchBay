import Foundation
import AppKit
import IOKit
import IOKit.pwr_mgt
import Combine

public enum CaffeinePreset: Int, CaseIterable, Identifiable, Sendable {
    case indefinite = 0
    case minutes15 = 15
    case minutes30 = 30
    case hours1 = 60
    case hours2 = 120
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .indefinite: return "Indefinitely"
        case .minutes15: return "15 Minutes"
        case .minutes30: return "30 Minutes"
        case .hours1: return "1 Hour"
        case .hours2: return "2 Hours"
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .indefinite: return "∞"
        case .minutes15: return "15m"
        case .minutes30: return "30m"
        case .hours1: return "1h"
        case .hours2: return "2h"
        }
    }
    
    public var durationSeconds: Int? {
        switch self {
        case .indefinite: return nil
        default: return rawValue * 60
        }
    }
}

@MainActor
public final class CaffeineService: ObservableObject {
    @Published public var isActive: Bool = false
    @Published public var selectedPreset: CaffeinePreset = .indefinite
    @Published public var remainingSeconds: Int = 0
    
    public var onStatusChanged: ((Bool, CaffeinePreset) -> Void)?
    
    private var assertionID: IOPMAssertionID = 0
    private var countdownTimer: Timer?
    
    public init() {}
    
    deinit {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
        }
    }
    
    public var formattedRemainingTime: String {
        guard isActive else { return "" }
        if selectedPreset == .indefinite {
            return "∞"
        }
        let hrs = remainingSeconds / 3600
        let mins = (remainingSeconds % 3600) / 60
        let secs = remainingSeconds % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }
    
    public func toggle() {
        if isActive {
            deactivate()
        } else {
            activate(preset: selectedPreset)
        }
    }
    
    public func activate(preset: CaffeinePreset) {
        self.selectedPreset = preset
        createAssertion()
        
        isActive = true
        NSSound(named: "Pop")?.play()
        
        countdownTimer?.invalidate()
        if let totalSeconds = preset.durationSeconds {
            remainingSeconds = totalSeconds
            let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.remainingSeconds > 0 {
                        self.remainingSeconds -= 1
                    }
                    if self.remainingSeconds <= 0 {
                        self.deactivate()
                    }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            countdownTimer = timer
        } else {
            remainingSeconds = 0
            countdownTimer = nil
        }
        
        onStatusChanged?(true, preset)
    }
    
    public func deactivate() {
        guard isActive else { return }
        releaseAssertion()
        
        isActive = false
        remainingSeconds = 0
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        NSSound(named: "Tink")?.play()
        onStatusChanged?(false, selectedPreset)
    }
    
    private func createAssertion() {
        releaseAssertion()
        let reason = "NotchBay Caffeine: Preventing sleep" as CFString
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        if success != kIOReturnSuccess {
            assertionID = 0
        }
    }
    
    private func releaseAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
}
