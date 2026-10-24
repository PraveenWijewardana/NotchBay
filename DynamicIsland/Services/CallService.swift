import Foundation
import SwiftUI
import AppKit
import CoreGraphics
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
    private var autoDetectTimer: Timer?
    private var isAutoDetectedSession: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        checkInstalledApps()
        observeAppLaunches()
        startAutoDetectMonitoring()
    }
    
    deinit {
        durationTimer?.invalidate()
        visualizerTimer?.invalidate()
        ringTimer?.invalidate()
        autoDetectTimer?.invalidate()
    }
    
    // MARK: - App Monitoring & Auto-Detection
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
    
    public func startAutoDetectMonitoring() {
        autoDetectTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkRealTimeCallStatus()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        autoDetectTimer = timer
    }
    
    public func stopAutoDetectMonitoring() {
        autoDetectTimer?.invalidate()
        autoDetectTimer = nil
    }
    
    public func checkRealTimeCallStatus() {
        checkInstalledApps()
        
        guard isWhatsAppRunning || isFaceTimeRunning else {
            if isAutoDetectedSession, currentCall != nil, currentCall?.status != .ended {
                isAutoDetectedSession = false
                endCall()
            }
            return
        }
        
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        
        var detectedCall: (category: CallCategory, contactName: String, isIncoming: Bool)? = nil
        
        for win in windowList {
            guard let owner = win[kCGWindowOwnerName as String] as? String else { continue }
            let ownerLower = owner.lowercased()
            let title = (win[kCGWindowName as String] as? String) ?? ""
            let titleLower = title.lowercased()
            
            // Check WhatsApp
            if ownerLower.contains("whatsapp") {
                if titleLower.contains("call") || titleLower.contains("calling") || titleLower.contains("incoming") {
                    let isVideo = titleLower.contains("video")
                    let isIncoming = titleLower.contains("incoming") || titleLower.contains("ringing")
                    var cleanName = title.replacingOccurrences(of: "WhatsApp Call with ", with: "")
                        .replacingOccurrences(of: "WhatsApp Call", with: "")
                        .replacingOccurrences(of: "Call with ", with: "")
                        .replacingOccurrences(of: "Calling ", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanName.isEmpty { cleanName = "WhatsApp Contact" }
                    detectedCall = (isVideo ? .whatsAppVideo : .whatsAppAudio, cleanName, isIncoming)
                    break
                }
            }
            
            // Check FaceTime / Cellular Continuity
            if ownerLower.contains("facetime") || ownerLower.contains("callservices") {
                if titleLower.contains("call") || titleLower.contains("facetime") || titleLower.contains("with ") {
                    let isVideo = titleLower.contains("video")
                    let isIncoming = titleLower.contains("incoming") || titleLower.contains("ringing")
                    var cleanName = title.replacingOccurrences(of: "FaceTime with ", with: "")
                        .replacingOccurrences(of: "FaceTime", with: "")
                        .replacingOccurrences(of: "Call with ", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanName.isEmpty { cleanName = "Phone Contact" }
                    detectedCall = (isVideo ? .facetimeVideo : .cellular, cleanName, isIncoming)
                    break
                }
            }
        }
        
        if let info = detectedCall {
            if currentCall == nil || currentCall?.status == .ended {
                isAutoDetectedSession = true
                if info.isIncoming {
                    startIncomingCall(category: info.category, contactName: info.contactName)
                } else {
                    let contact = CallContact(name: info.contactName)
                    let session = ActiveCallSession(
                        contact: contact,
                        category: info.category,
                        status: .active,
                        startedAt: Date()
                    )
                    self.currentCall = session
                    onCallStateChanged?(session)
                    startLiveDurationTicker()
                    startAudioVisualizer()
                }
            }
        } else {
            if isAutoDetectedSession, let call = currentCall, call.status != .ended {
                isAutoDetectedSession = false
                endCall()
            }
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
        
        // Bring native app to front if active
        if call.category.appType == .whatsApp {
            if let wa = NSWorkspace.shared.runningApplications.first(where: { ($0.bundleIdentifier ?? "").lowercased().contains("whatsapp") }) {
                wa.activate(options: .activateIgnoringOtherApps)
            }
        } else if call.category.appType == .facetime || call.category.appType == .normal {
            if let ft = NSWorkspace.shared.runningApplications.first(where: { ($0.bundleIdentifier ?? "").lowercased().contains("facetime") }) {
                ft.activate(options: .activateIgnoringOtherApps)
            }
        }
        
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
