import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
public final class CallService: ObservableObject {
    @Published public var currentCall: ActiveCallSession? = nil
    @Published public var isWhatsAppRunning: Bool = false
    @Published public var isFaceTimeRunning: Bool = false
    @Published public var callAudioFrequencies: [CGFloat] = [0.3, 0.7, 0.5, 0.8]
    
    public var onCallStateChanged: ((ActiveCallSession?) -> Void)?
    
    private var durationTimer: Timer?
    private var visualizerTimer: Timer?
    private var ringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        checkInstalledApps()
        observeAppLaunches()
    }
    
    deinit {
        durationTimer?.invalidate()
        visualizerTimer?.invalidate()
        ringTimer?.invalidate()
    }
    
    // MARK: - App Monitoring (WhatsApp & FaceTime)
    public func checkInstalledApps() {
        let running = NSWorkspace.shared.runningApplications
        isWhatsAppRunning = running.contains { app in
            let id = app.bundleIdentifier?.lowercased() ?? ""
            let name = app.localizedName?.lowercased() ?? ""
            return id.contains("whatsapp") || name.contains("whatsapp")
        }
        
        isFaceTimeRunning = running.contains { app in
            let id = app.bundleIdentifier?.lowercased() ?? ""
            let name = app.localizedName?.lowercased() ?? ""
            return id.contains("facetime") || name.contains("facetime")
        }
    }
    
    private func observeAppLaunches() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkInstalledApps()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkInstalledApps()
        }
    }
    
    // MARK: - Call Actions
    public func startIncomingCall(
        category: CallCategory,
        contactName: String,
        numberOrHandle: String = "",
        colorHex: String? = nil
    ) {
        let defaultColor: String
        switch category.appType {
        case .normal: defaultColor = "#34C759"
        case .facetime: defaultColor = "#007AFF"
        case .whatsApp: defaultColor = "#25D366"
        }
        
        let contact = CallContact(
            name: contactName,
            numberOrHandle: numberOrHandle.isEmpty ? (category.appType == .whatsApp ? "+1 (555) 321-9876" : "+1 (555) 867-5309") : numberOrHandle,
            avatarColorHex: colorHex ?? defaultColor
        )
        
        let session = ActiveCallSession(
            contact: contact,
            category: category,
            status: .incoming
        )
        
        self.currentCall = session
        onCallStateChanged?(session)
        
        // Ringing audio feedback loop
        playRingChime()
        ringTimer?.invalidate()
        let timer = Timer(timeInterval: 2.8, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.currentCall?.status == .incoming else { return }
                self.playRingChime()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ringTimer = timer
    }
    
    public func answerCall() {
        guard var call = currentCall, call.status == .incoming else { return }
        
        ringTimer?.invalidate()
        ringTimer = nil
        
        call.status = .active
        call.durationSeconds = 0
        self.currentCall = call
        
        NSSound(named: "Pop")?.play()
        onCallStateChanged?(call)
        
        startLiveDurationTicker()
        startAudioVisualizer()
    }
    
    public func declineCall() {
        ringTimer?.invalidate()
        ringTimer = nil
        
        guard var call = currentCall else { return }
        call.status = .ended
        self.currentCall = call
        
        NSSound(named: "Tink")?.play()
        onCallStateChanged?(call)
        
        stopTimers()
        
        // Auto-dismiss after 1.2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.currentCall?.status == .ended {
                self?.currentCall = nil
                self?.onCallStateChanged?(nil)
            }
        }
    }
    
    public func endCall() {
        ringTimer?.invalidate()
        ringTimer = nil
        
        guard var call = currentCall else { return }
        call.status = .ended
        self.currentCall = call
        
        NSSound(named: "Basso")?.play()
        onCallStateChanged?(call)
        
        stopTimers()
        
        // Auto-dismiss after 1.2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.currentCall?.status == .ended {
                self?.currentCall = nil
                self?.onCallStateChanged?(nil)
            }
        }
    }
    
    public func toggleMute() {
        guard var call = currentCall, call.status == .active else { return }
        call.isMuted.toggle()
        self.currentCall = call
        NSSound(named: "Tink")?.play()
        onCallStateChanged?(call)
    }
    
    public func toggleSpeaker() {
        guard var call = currentCall, call.status == .active else { return }
        call.isSpeaker.toggle()
        self.currentCall = call
        NSSound(named: "Pop")?.play()
        onCallStateChanged?(call)
    }
    
    // MARK: - Audio Visualizer & Timers
    private func startLiveDurationTicker() {
        durationTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, var call = self.currentCall, call.status == .active else { return }
                call.durationSeconds += 1
                self.currentCall = call
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        durationTimer = timer
    }
    
    private func startAudioVisualizer() {
        visualizerTimer?.invalidate()
        let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let call = self.currentCall, call.status == .active else { return }
                if call.isMuted {
                    self.callAudioFrequencies = [0.1, 0.1, 0.1, 0.1]
                } else {
                    self.callAudioFrequencies = [
                        CGFloat.random(in: 0.25...0.95),
                        CGFloat.random(in: 0.35...1.0),
                        CGFloat.random(in: 0.20...0.85),
                        CGFloat.random(in: 0.30...0.90)
                    ]
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        visualizerTimer = timer
    }
    
    private func stopTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        visualizerTimer?.invalidate()
        visualizerTimer = nil
        callAudioFrequencies = [0.2, 0.2, 0.2, 0.2]
    }
    
    private func playRingChime() {
        NSSound(named: "Ping")?.play()
    }
}
