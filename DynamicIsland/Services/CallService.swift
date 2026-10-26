import Foundation
import SwiftUI
import AppKit
import CoreGraphics
import ApplicationServices
import Contacts
import Combine

// MARK: - Contacts Resolver Helper
public final class ContactsResolver: @unchecked Sendable {
    public static let shared = ContactsResolver()
    private let contactStore = CNContactStore()
    private var cachedContacts: [String: CallContact] = [:]
    private let lock = NSLock()
    
    public init() {}
    
    public func resolve(nameOrNumber: String, defaultColorHex: String = "#34C759") -> CallContact {
        let clean = nameOrNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return CallContact(name: "Unknown Caller", numberOrHandle: "", avatarImageData: nil, avatarColorHex: defaultColorHex)
        }
        
        lock.lock()
        if let cached = cachedContacts[clean] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        let authStatus = CNContactStore.authorizationStatus(for: .contacts)
        if authStatus == .notDetermined {
            contactStore.requestAccess(for: .contacts) { _, _ in }
        }
        
        guard authStatus == .authorized else {
            let isDigitsOnly = clean.filter({ $0.isNumber }).count >= 7
            let contact = CallContact(
                name: clean,
                numberOrHandle: isDigitsOnly ? clean : "",
                avatarImageData: nil,
                avatarColorHex: defaultColorHex
            )
            lock.lock()
            cachedContacts[clean] = contact
            lock.unlock()
            return contact
        }
        
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ]
        
        var matchedContact: CNContact? = nil
        
        // 1. Try phone number matching
        let digits = clean.filter { $0.isNumber }
        if digits.count >= 7 {
            let phoneNumber = CNPhoneNumber(stringValue: clean)
            let predicate = CNContact.predicateForContacts(matching: phoneNumber)
            if let results = try? contactStore.unifiedContacts(matching: predicate, keysToFetch: keys), let first = results.first {
                matchedContact = first
            }
        }
        
        // 2. Try name matching
        if matchedContact == nil {
            let predicate = CNContact.predicateForContacts(matchingName: clean)
            if let results = try? contactStore.unifiedContacts(matching: predicate, keysToFetch: keys), let first = results.first {
                matchedContact = first
            }
        }
        
        if let cn = matchedContact {
            let fullName = [cn.givenName, cn.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let displayName = fullName.isEmpty ? clean : fullName
            let phone = cn.phoneNumbers.first?.value.stringValue ?? (clean != displayName ? clean : "")
            let contact = CallContact(
                name: displayName,
                numberOrHandle: phone,
                avatarImageData: cn.thumbnailImageData,
                avatarColorHex: defaultColorHex
            )
            lock.lock()
            cachedContacts[clean] = contact
            lock.unlock()
            return contact
        }
        
        let contact = CallContact(
            name: clean,
            numberOrHandle: clean.filter({ $0.isNumber }).count >= 7 ? clean : "",
            avatarImageData: nil,
            avatarColorHex: defaultColorHex
        )
        lock.lock()
        cachedContacts[clean] = contact
        lock.unlock()
        return contact
    }
}

// MARK: - Call Service
@MainActor
public final class CallService: ObservableObject {
    @Published public var currentCall: ActiveCallSession? = nil
    @Published public var isWhatsAppRunning: Bool = false
    @Published public var isFaceTimeRunning: Bool = false
    @Published public var isPhoneContinuityRunning: Bool = false
    @Published public var callAudioFrequencies: [CGFloat] = [0.3, 0.7, 0.5, 0.8]
    
    public var onCallStateChanged: ((ActiveCallSession?) -> Void)?
    
    // Cached AXUIElements for instant action triggers
    private var cachedAcceptButton: AXUIElement? = nil
    private var cachedDeclineButton: AXUIElement? = nil
    private var cachedMuteButton: AXUIElement? = nil
    private var cachedCallingPID: pid_t? = nil
    
    private var durationTimer: Timer?
    private var visualizerTimer: Timer?
    private var ringTimer: Timer?
    private var autoDetectTimer: Timer?
    private var isAutoDetectedSession: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        checkInstalledApps()
        observeAppLaunches()
        observeDistributedNotifications()
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
        
        isPhoneContinuityRunning = running.contains { app in
            let id = app.bundleIdentifier?.lowercased() ?? ""
            let name = app.localizedName?.lowercased() ?? ""
            return id.contains("incallservice") || id.contains("callservices") || name.contains("incallservice") || name.contains("callservices")
        }
    }
    
    private func observeAppLaunches() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkInstalledApps()
                self?.checkRealTimeCallStatus()
            }
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkInstalledApps()
                self?.checkRealTimeCallStatus()
            }
        }
    }
    
    private func observeDistributedNotifications() {
        let distCenter = DistributedNotificationCenter.default()
        let callNotificationNames = [
            "com.apple.FaceTime.callStateChanged",
            "com.apple.FaceTime.incomingCall",
            "com.apple.telephonyutilities.callservicesd.callStatusChanged",
            "com.apple.telephonyutilities.callservicesd.incomingCall",
            "com.apple.telephonyutilities.callservicesd.activeCall",
            "com.apple.telephonyutilities.callservicesd.callEnded",
            "TUCallCenterCallStatusChangedNotification",
            "TUCallCenterVideoCallStatusChangedNotification",
            "TUCallCenterCallConnectedNotification",
            "TUCallCenterCallEndedNotification"
        ]
        
        for name in callNotificationNames {
            distCenter.addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkRealTimeCallStatus()
                }
            }
        }
    }
    
    public func startAutoDetectMonitoring() {
        autoDetectTimer?.invalidate()
        // Low-overhead 2.0s timer when idle with tolerance to save battery and CPU
        let interval: TimeInterval = (currentCall != nil) ? 1.0 : 2.0
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkRealTimeCallStatus()
            }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        autoDetectTimer = timer
    }
    
    public func stopAutoDetectMonitoring() {
        autoDetectTimer?.invalidate()
        autoDetectTimer = nil
    }
    
    // MARK: - Core Call Detection Logic (Direct Accessibility Engine)
    public func checkRealTimeCallStatus() {
        guard AppSettings.shared.enableCallDetection else {
            if isAutoDetectedSession, currentCall != nil, currentCall?.status != .ended {
                isAutoDetectedSession = false
                endCall()
            }
            return
        }
        
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Define known candidate calling applications
        struct CandidateDef {
            let matches: (NSRunningApplication) -> Bool
            let appType: CallAppType
            let defaultCategory: CallCategory
        }
        
        let candidates: [CandidateDef] = [
            CandidateDef(
                matches: { app in
                    let id = app.bundleIdentifier?.lowercased() ?? ""
                    let name = app.localizedName?.lowercased() ?? ""
                    return id.contains("incallservice") || name.contains("incallservice") || id.contains("callservices")
                },
                appType: .normal,
                defaultCategory: .cellular
            ),
            CandidateDef(
                matches: { app in
                    let id = app.bundleIdentifier?.lowercased() ?? ""
                    let name = app.localizedName?.lowercased() ?? ""
                    return id.contains("facetime") || name.contains("facetime")
                },
                appType: .facetime,
                defaultCategory: .facetimeAudio
            ),
            CandidateDef(
                matches: { app in
                    let id = app.bundleIdentifier?.lowercased() ?? ""
                    let name = app.localizedName?.lowercased() ?? ""
                    return id.contains("whatsapp") || name.contains("whatsapp")
                },
                appType: .whatsApp,
                defaultCategory: .whatsAppAudio
            ),
            CandidateDef(
                matches: { app in
                    let id = app.bundleIdentifier?.lowercased() ?? ""
                    let name = app.localizedName?.lowercased() ?? ""
                    return id.contains("us.zoom.xos") || id.contains("zoom.us") || name.contains("zoom")
                },
                appType: .zoom,
                defaultCategory: .zoomMeeting
            ),
            CandidateDef(
                matches: { app in
                    let id = app.bundleIdentifier?.lowercased() ?? ""
                    let name = app.localizedName?.lowercased() ?? ""
                    return id.contains("com.microsoft.teams") || name.contains("teams")
                },
                appType: .teams,
                defaultCategory: .teamsMeeting
            ),
            CandidateDef(
                matches: { app in
                    let id = app.bundleIdentifier?.lowercased() ?? ""
                    let name = app.localizedName?.lowercased() ?? ""
                    return id.contains("telegram") || name.contains("telegram")
                },
                appType: .telegram,
                defaultCategory: .telegramCall
            ),
            CandidateDef(
                matches: { app in
                    let id = app.bundleIdentifier?.lowercased() ?? ""
                    let name = app.localizedName?.lowercased() ?? ""
                    return id.contains("slack") || name.contains("slack")
                },
                appType: .slack,
                defaultCategory: .slackHuddle
            ),
            CandidateDef(
                matches: { app in
                    let id = app.bundleIdentifier?.lowercased() ?? ""
                    let name = app.localizedName?.lowercased() ?? ""
                    return id.contains("chrome") || id.contains("safari") || id.contains("brave") || id.contains("arc")
                },
                appType: .meet,
                defaultCategory: .webMeeting
            )
        ]
        
        var detectedInfo: (
            category: CallCategory,
            contactName: String,
            numberOrHandle: String,
            isIncoming: Bool,
            pid: pid_t,
            acceptBtn: AXUIElement?,
            declineBtn: AXUIElement?,
            muteBtn: AXUIElement?
        )? = nil
        
        for cand in candidates {
            guard let app = runningApps.first(where: cand.matches) else { continue }
            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement], !windows.isEmpty else {
                continue
            }
            
            let isInCallService = (cand.appType == .normal)
            
            for win in windows.prefix(6) {
                var titleRef: CFTypeRef?
                var windowTitle = ""
                if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let t = titleRef as? String {
                    windowTitle = t
                }
                
                var buttons: [(role: String, title: String, element: AXUIElement)] = []
                var extractedTexts: [String] = []
                scanAXUIElement(win, depth: 0, maxDepth: 4, extractedTexts: &extractedTexts, buttons: &buttons)
                
                let acceptBtn = buttons.first { b in
                    let lower = b.title.lowercased()
                    return lower.contains("accept") || lower.contains("answer") || lower.contains("join")
                }?.element
                
                let declineBtn = buttons.first { b in
                    let lower = b.title.lowercased()
                    return lower.contains("decline") || lower.contains("end") || lower.contains("leave") || lower.contains("hang up")
                }?.element
                
                let muteBtn = buttons.first { b in
                    let lower = b.title.lowercased()
                    return lower.contains("mute") || lower.contains("mic")
                }?.element
                
                let titleLower = windowTitle.lowercased()
                
                // Detection criteria
                var isCallWindow = false
                var isIncoming = (acceptBtn != nil)
                
                if isInCallService {
                    isCallWindow = true
                } else if cand.appType == .meet {
                    if titleLower.contains("meet - ") || titleLower.contains("meet.google.com") || titleLower.contains("zoom meeting") {
                        if declineBtn != nil || muteBtn != nil || titleLower.contains("meeting") {
                            isCallWindow = true
                        }
                    }
                } else {
                    let hasCallKeyword = titleLower.contains("call") ||
                                         titleLower.contains("calling") ||
                                         titleLower.contains("incoming") ||
                                         titleLower.contains("ringing") ||
                                         titleLower.contains("meeting") ||
                                         titleLower.contains("huddle") ||
                                         titleLower.contains("facetime")
                    
                    if acceptBtn != nil || declineBtn != nil {
                        isCallWindow = true
                    } else if hasCallKeyword && (muteBtn != nil || !extractedTexts.isEmpty) {
                        isCallWindow = true
                    }
                }
                
                if titleLower.contains("incoming") || titleLower.contains("ringing") {
                    isIncoming = true
                }
                
                if isCallWindow {
                    let isVideo = titleLower.contains("video") ||
                                  extractedTexts.contains { $0.lowercased().contains("video") } ||
                                  cand.defaultCategory.isVideo
                    
                    let category: CallCategory
                    switch cand.appType {
                    case .normal: category = .cellular
                    case .facetime: category = isVideo ? .facetimeVideo : .facetimeAudio
                    case .whatsApp: category = isVideo ? .whatsAppVideo : .whatsAppAudio
                    case .zoom: category = .zoomMeeting
                    case .teams: category = .teamsMeeting
                    case .telegram: category = .telegramCall
                    case .slack: category = .slackHuddle
                    case .meet: category = .webMeeting
                    case .other: category = .other
                    }
                    
                    let (name, number) = extractCallerIdentifier(
                        windowTitle: windowTitle,
                        extractedTexts: extractedTexts,
                        appType: cand.appType
                    )
                    
                    detectedInfo = (
                        category: category,
                        contactName: name,
                        numberOrHandle: number,
                        isIncoming: isIncoming,
                        pid: pid,
                        acceptBtn: acceptBtn,
                        declineBtn: declineBtn,
                        muteBtn: muteBtn
                    )
                    break
                }
            }
            
            if detectedInfo != nil { break }
        }
        
        // MARK: - State Application
        if let info = detectedInfo {
            // Cache controls for native interaction
            self.cachedAcceptButton = info.acceptBtn
            self.cachedDeclineButton = info.declineBtn
            self.cachedMuteButton = info.muteBtn
            self.cachedCallingPID = info.pid
            
            // Resolve real contact details via macOS Contacts framework
            let resolvedContact = ContactsResolver.shared.resolve(
                nameOrNumber: info.contactName.isEmpty ? info.numberOrHandle : info.contactName,
                defaultColorHex: info.category.appType.accentColor.toHex() ?? "#34C759"
            )
            
            if currentCall == nil || currentCall?.status == .ended {
                isAutoDetectedSession = true
                if info.isIncoming {
                    startIncomingCall(
                        category: info.category,
                        contact: resolvedContact,
                        appPID: info.pid
                    )
                } else {
                    let session = ActiveCallSession(
                        contact: resolvedContact,
                        category: info.category,
                        status: .active,
                        startedAt: Date(),
                        appPID: info.pid
                    )
                    self.currentCall = session
                    onCallStateChanged?(session)
                    startLiveDurationTicker()
                    startAudioVisualizer()
                }
            } else if var call = currentCall {
                // If call was incoming and is now answered on the Mac or phone, transition to active
                if call.status == .incoming && !info.isIncoming {
                    ringTimer?.invalidate()
                    ringTimer = nil
                    call.status = .active
                    call.durationSeconds = 0
                    self.currentCall = call
                    onCallStateChanged?(call)
                    startLiveDurationTicker()
                    startAudioVisualizer()
                }
            }
        } else {
            // If the call window has vanished, finish the auto-detected session gracefully
            if isAutoDetectedSession, let call = currentCall, call.status != .ended {
                isAutoDetectedSession = false
                endCall()
            }
        }
    }
    
    // MARK: - Accessibility Traversal Helper
    private func scanAXUIElement(
        _ element: AXUIElement,
        depth: Int = 0,
        maxDepth: Int = 4,
        extractedTexts: inout [String],
        buttons: inout [(role: String, title: String, element: AXUIElement)]
    ) {
        guard depth <= maxDepth else { return }
        
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            
            var titleRef: CFTypeRef?
            var title = ""
            if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
               let t = titleRef as? String {
                title = t
            }
            
            var valRef: CFTypeRef?
            var val = ""
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valRef) == .success,
               let v = valRef as? String {
                val = v
            }
            
            var descRef: CFTypeRef?
            var desc = ""
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
               let d = descRef as? String {
                desc = d
            }
            
            if role == (kAXButtonRole as String) {
                let btnLabel = !title.isEmpty ? title : (!desc.isEmpty ? desc : val)
                buttons.append((role: role, title: btnLabel, element: element))
            }
            
            let candidate = !title.isEmpty ? title : (!val.isEmpty ? val : desc)
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count < 90 && !extractedTexts.contains(trimmed) {
                extractedTexts.append(trimmed)
            }
        }
        
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                scanAXUIElement(child, depth: depth + 1, maxDepth: maxDepth, extractedTexts: &extractedTexts, buttons: &buttons)
            }
        }
    }
    
    // MARK: - Caller Identifier Extraction
    private func extractCallerIdentifier(
        windowTitle: String,
        extractedTexts: [String],
        appType: CallAppType
    ) -> (name: String, number: String) {
        let blacklist = [
            "incoming call", "calling", "ringing", "facetime audio", "facetime video",
            "iphone cellular call", "cellular call", "facetime", "whatsapp call",
            "whatsapp video call", "whatsapp", "accept", "decline", "answer", "end call",
            "mute", "unmute", "audio", "video", "leave", "hang up", "00:00", "connected",
            "zoom", "zoom meeting", "teams", "microsoft teams", "meeting", "huddle",
            "slack", "telegram", "google meet", "close", "minimize", "maximize"
        ]
        
        // 1. Clean window title
        let cleanTitle = windowTitle
            .replacingOccurrences(of: "WhatsApp Call with ", with: "")
            .replacingOccurrences(of: "WhatsApp Call", with: "")
            .replacingOccurrences(of: "FaceTime with ", with: "")
            .replacingOccurrences(of: "FaceTime", with: "")
            .replacingOccurrences(of: "Call with ", with: "")
            .replacingOccurrences(of: "Calling ", with: "")
            .replacingOccurrences(of: "Zoom Meeting - ", with: "")
            .replacingOccurrences(of: "Meet - ", with: "")
            .replacingOccurrences(of: " | Microsoft Teams", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !cleanTitle.isEmpty && !blacklist.contains(cleanTitle.lowercased()) {
            return (cleanTitle, "")
        }
        
        // 2. Scan extracted static texts for real contact name or phone number
        for text in extractedTexts {
            let lower = text.lowercased()
            if blacklist.contains(lower) { continue }
            if lower.contains("call with") || lower.contains("incoming") || lower.contains("calling") { continue }
            
            // Check if text is a phone number
            let digitsCount = text.filter({ $0.isNumber }).count
            if digitsCount >= 7 {
                return (text, text)
            }
            
            // Otherwise, it's likely a real contact name
            if text.count >= 2 && text.count <= 40 {
                return (text, "")
            }
        }
        
        let defaultName: String
        switch appType {
        case .normal: defaultName = "Phone Contact"
        case .facetime: defaultName = "FaceTime Contact"
        case .whatsApp: defaultName = "WhatsApp Contact"
        case .zoom: defaultName = "Zoom Meeting"
        case .teams: defaultName = "Teams Meeting"
        case .telegram: defaultName = "Telegram Contact"
        case .slack: defaultName = "Slack Huddle"
        case .meet: defaultName = "Google Meet"
        case .other: defaultName = "Incoming Call"
        }
        return (defaultName, "")
    }
    
    // MARK: - Call Actions
    public func startIncomingCall(
        category: CallCategory,
        contact: CallContact,
        appPID: pid_t? = nil
    ) {
        let session = ActiveCallSession(
            contact: contact,
            category: category,
            status: .incoming,
            appPID: appPID
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
    
    public func startIncomingCall(
        category: CallCategory,
        contactName: String,
        numberOrHandle: String = "",
        colorHex: String? = nil
    ) {
        let defaultColor = category.appType.accentColor.toHex() ?? "#34C759"
        let contact = ContactsResolver.shared.resolve(
            nameOrNumber: contactName.isEmpty ? numberOrHandle : contactName,
            defaultColorHex: colorHex ?? defaultColor
        )
        startIncomingCall(category: category, contact: contact)
    }
    
    public func answerCall() {
        guard var call = currentCall, call.status == .incoming else { return }
        
        ringTimer?.invalidate()
        ringTimer = nil
        
        // 1. Programmatically trigger native Accept action via Accessibility
        if let acceptBtn = cachedAcceptButton {
            AXUIElementPerformAction(acceptBtn, kAXPressAction as CFString)
        }
        
        // 2. Bring native call application to front
        activateCallApp(for: call)
        
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
        
        // 1. Programmatically trigger native Decline action via Accessibility
        if let declineBtn = cachedDeclineButton {
            AXUIElementPerformAction(declineBtn, kAXPressAction as CFString)
        }
        
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
        
        // 1. Programmatically trigger native End Call action via Accessibility
        if let declineBtn = cachedDeclineButton {
            AXUIElementPerformAction(declineBtn, kAXPressAction as CFString)
        }
        
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
        
        // Toggle native mute via Accessibility
        if let muteBtn = cachedMuteButton {
            AXUIElementPerformAction(muteBtn, kAXPressAction as CFString)
        }
        
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
    
    private func activateCallApp(for call: ActiveCallSession) {
        if let pid = call.appPID ?? cachedCallingPID,
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
            bringAppToFront(app)
            return
        }
        
        if call.category.appType == .whatsApp {
            if let wa = NSWorkspace.shared.runningApplications.first(where: { ($0.bundleIdentifier ?? "").lowercased().contains("whatsapp") }) {
                bringAppToFront(wa)
            }
        } else {
            if let ft = NSWorkspace.shared.runningApplications.first(where: { ($0.bundleIdentifier ?? "").lowercased().contains("facetime") || ($0.bundleIdentifier ?? "").lowercased().contains("callservices") }) {
                bringAppToFront(ft)
            }
        }
    }
    
    private func bringAppToFront(_ app: NSRunningApplication) {
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: .activateIgnoringOtherApps)
        }
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

// MARK: - Color Extension Helper
private extension Color {
    func toHex() -> String? {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return nil }
        let r = Int(rgbColor.redComponent * 255.0)
        let g = Int(rgbColor.greenComponent * 255.0)
        let b = Int(rgbColor.blueComponent * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
