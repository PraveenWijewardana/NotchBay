import Foundation
import SwiftUI
import Combine

public enum IslandPresentationState: Equatable, Sendable {
    case compact
    case hud
    case call
    case expanded
}

public enum SystemDetailBlock: String, Identifiable, Sendable {
    case cpu = "CPU"
    case gpu = "GPU"
    case memory = "Memory"
    case swap = "Swap"
    case storage = "Storage"
    case network = "Network"
    case diskIO = "Disk I/O"
    case power = "Power"
    
    public var id: String { rawValue }
}

@MainActor
public final class NotchViewModel: ObservableObject {
    @Published public var state: IslandPresentationState = .compact {
        didSet {
            handleStateTransition(from: oldValue, to: state)
        }
    }
    @Published public var selectedPageIndex: Int = 0 {
        didSet {
            systemService.isDetailedMonitoringActive = (state == .expanded && selectedPageIndex == 1)
            if selectedPageIndex == 0 || selectedPageIndex == 3 {
                mediaService.syncPlayerStateFromActiveApp()
            }
            if selectedPageIndex == 0 {
                focusService.refreshFocusState()
            }
        }
    }
    @Published public var systemDetailMode: SystemDetailBlock? = nil
    @Published public var isHovering: Bool = false
    @Published public var isPinned: Bool = AppSettings.shared.isIslandPinned {
        didSet {
            AppSettings.shared.isIslandPinned = isPinned
        }
    }
    @Published public var isGrabberHovered: Bool = false
    
    // Services
    @Published public var systemService = SystemMonitorService()
    @Published public var networkService = NetworkMonitorService()
    @Published public var mediaService = MediaControllerService()
    @Published public var shelfService = DropShelfService()
    @Published public var hudService = SystemHUDService()
    @Published public var agentService = AgentCompanionService()
    @Published public var weatherService = WeatherService()
    @Published public var calendarService = CalendarService()
    @Published public var caffeineService = CaffeineService()
    @Published public var callService = CallService()
    @Published public var clipboardService = ClipboardService()
    @Published public var fileTransferService = FileTransferService()
    @Published public var focusService = FocusService()
    
    // Live Dynamic Island HUD
    @Published public var currentHUDAlert: HUDAlert? = nil
    private var hudDismissTimer: Timer?
    
    // Clock heartbeat
    @Published public var currentDate: Date = Date()
    private var clockTimer: Timer?
    
    // Timer state
    @Published public var timerMode: TimerMode = .timer
    @Published public var timerConfig = TimerConfig()
    private var countdownTimer: Timer?
    private var stopwatchTimer: Timer?
    private var hoverTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    public let totalPages: Int = 8 // 0: Home, 1: System, 2: Timers, 3: Music, 4: Shelf, 5: Agents, 6: Calendar, 7: Weather
    
    public var physicalNotchWidth: CGFloat {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        if let auxLeft = screen.auxiliaryTopLeftArea, let auxRight = screen.auxiliaryTopRightArea {
            return max(150.0, auxRight.minX - auxLeft.maxX)
        }
        return 179.0
    }
    
    public var physicalNotchHeight: CGFloat {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        return screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 32.0
    }
    
    public var compactHeight: CGFloat {
        max(physicalNotchHeight + 4.0, 36.0)
    }
    
    public init() {
        setupSubscribers()
        if state == .expanded {
            startClockTimer()
        }
    }
    
    private func handleStateTransition(from oldState: IslandPresentationState, to newState: IslandPresentationState) {
        if newState == .expanded {
            currentDate = Date()
            startClockTimer()
            systemService.isDetailedMonitoringActive = (selectedPageIndex == 1)
            systemService.refreshAll()
            mediaService.syncPlayerStateFromActiveApp()
            focusService.refreshFocusState()
        } else {
            stopClockTimer()
            systemService.isDetailedMonitoringActive = false
        }
    }
    
    private func startClockTimer() {
        clockTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentDate = Date()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }
    
    private func stopClockTimer() {
        clockTimer?.invalidate()
        clockTimer = nil
    }
    
    private func setupSubscribers() {
        // Wire up HUD Service triggers
        hudService.onAlertTriggered = { [weak self] alert in
            self?.presentHUD(alert)
        }
        
        hudService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        caffeineService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        // Wire up Agent Companion triggers (Permission requests, Task completions, Task failures)
        agentService.onPermissionRequested = { [weak self] req in
            self?.presentHUD(
                HUDAlert(
                    type: .agentPermission(agent: req.agent, requestId: req.id, action: req.actionOrTool),
                    title: req.agent.rawValue,
                    subtitle: req.actionOrTool.isEmpty ? "Permission Required" : req.actionOrTool,
                    icon: req.agent.iconName,
                    duration: 15.0
                )
            )
        }
        
        agentService.onTaskCompleted = { [weak self] agent, message in
            self?.presentHUD(
                HUDAlert(
                    type: .agentFinished(agent: agent, message: message),
                    title: agent.rawValue,
                    subtitle: message.isEmpty ? "Task Complete" : message,
                    icon: "checkmark.seal.fill",
                    duration: 4.5
                )
            )
        }
        
        agentService.onTaskFailed = { [weak self] agent, message in
            self?.presentHUD(
                HUDAlert(
                    type: .agentError(agent: agent, message: message),
                    title: agent.rawValue,
                    subtitle: message.isEmpty ? "Task Failed" : message,
                    icon: "xmark.octagon.fill",
                    duration: 5.0
                )
            )
        }
        
        agentService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        systemService.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.hudService.evaluateBatteryMetrics(self.systemService.powerMetrics)
            }
            .store(in: &cancellables)
            
        mediaService.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.hudService.evaluateTrackChange(self.mediaService.currentTrack)
            }
            .store(in: &cancellables)
            
        // Wire up Caffeine Sleep Prevention HUD
        caffeineService.onStatusChanged = { [weak self] isActive, preset in
            self?.presentHUD(
                HUDAlert(
                    type: .caffeine(isActive: isActive, presetTitle: preset.title),
                    title: "Caffeine",
                    subtitle: isActive ? "Stay Awake (\(preset.shortTitle))" : "Normal Sleep",
                    icon: isActive ? "cup.and.saucer.fill" : "cup.and.saucer",
                    duration: 2.5
                )
            )
        }
        
        // Wire up Call Service triggers (Incoming, Active, Ended)
        callService.onCallStateChanged = { [weak self] session in
            guard let self = self else { return }
            if let call = session {
                if call.status == .incoming || call.status == .active {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        self.state = .call
                    }
                } else if call.status == .ended {
                    // Stay in .call for 1.2s to display "Call Ended", then collapse
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                        guard let self = self else { return }
                        if self.state == .call && self.callService.currentCall == nil {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                self.state = .compact
                            }
                        }
                    }
                }
            } else {
                if self.state == .call {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        self.state = .compact
                    }
                }
            }
        }
        
        // Wire up File Transfer / AirDrop triggers
        fileTransferService.onTransferChanged = { [weak self] item in
            guard let self = self else { return }
            if let transfer = item {
                let alert = HUDAlert(
                    type: .fileTransfer(
                        name: transfer.filename,
                        progress: transfer.progress,
                        isAirDrop: transfer.isAirDrop,
                        isCompleted: transfer.isCompleted,
                        currentBytes: transfer.currentBytes,
                        totalBytes: transfer.totalBytes,
                        speedStr: transfer.formattedSpeed
                    ),
                    title: transfer.isAirDrop ? "AirDrop" : (transfer.isCompleted ? "Download Complete" : "Downloading"),
                    subtitle: transfer.subtitleFormatted,
                    icon: transfer.isAirDrop ? "airdrop" : (transfer.isCompleted ? "checkmark.circle.fill" : "arrow.down.circle.fill"),
                    progress: transfer.totalBytes > 0 ? transfer.progress : nil,
                    duration: transfer.isCompleted ? 3.5 : 2.0
                )
                self.presentHUD(alert)
            } else {
                if self.state == .hud, case .fileTransfer = self.currentHUDAlert?.type {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        self.state = .compact
                        self.currentHUDAlert = nil
                    }
                }
            }
        }
        
        // Wire up Focus Mode HUD alerts
        focusService.onFocusChanged = { [weak self] (isActive, sessionTitle, duration) in
            guard let self = self else { return }
            let icon = isActive ? self.focusService.activeModeIcon : "moon.slash.fill"
            let alert = HUDAlert(
                type: .focus(isActive: isActive, sessionTitle: sessionTitle, duration: duration),
                title: isActive ? "Apple Focus" : "Focus Off",
                subtitle: isActive ? "\(sessionTitle) • Active" : "Focus Ended",
                icon: icon,
                duration: 2.5
            )
            self.presentHUD(alert)
        }
    }
    
    // MARK: - Live HUD Alerts (Volume, Battery, Track, Downloads)
    public func presentHUD(_ alert: HUDAlert) {
        self.currentHUDAlert = alert
        hudDismissTimer?.invalidate()
        
        // Only enter HUD mode if currently in compact mode.
        // If the user is currently viewing the expanded dashboard (Home, Music, etc.), never kick them out!
        if state == .compact {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                self.state = .hud
            }
        }
        
        // Auto-dismiss HUD only if in .hud mode
        if state == .hud {
            let timer = Timer(timeInterval: alert.duration, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    // Keep approval banner visible until approved or denied
                    if case .agentPermission = self.currentHUDAlert?.type,
                       self.agentService.activePermissionRequest != nil {
                        return
                    }
                    if self.state == .hud && self.currentHUDAlert?.id == alert.id {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            self.state = .compact
                            self.currentHUDAlert = nil
                        }
                    }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            hudDismissTimer = timer
        }
    }
    
    public func handleHover(_ hovering: Bool) {
        self.isHovering = hovering
        hoverTask?.cancel()
        
        // While settings page is in use, notch must remain closed
        if SettingsWindowController.shared.isSettingsOpen {
            return
        }
        
        guard AppSettings.shared.hoverToExpand else { return }
        
        if hovering {
            // Expand to dashboard if in compact OR hud mode (e.g. while downloading files)!
            if state == .compact || state == .hud {
                hoverTask = Task { @MainActor in
                    let delayNanos = UInt64(max(0.05, AppSettings.shared.hoverDelay) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNanos)
                    if !Task.isCancelled && self.isHovering && !SettingsWindowController.shared.isSettingsOpen && (self.state == .compact || self.state == .hud) {
                        self.setExpanded(true)
                    }
                }
            }
        }
    }
    
    // MARK: - Apple Fluid Dynamic Island Spring Animations
    public static var expandSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.78, blendDuration: 0.08)
    }
    
    public static var collapseSpring: Animation {
        .spring(response: 0.30, dampingFraction: 0.86, blendDuration: 0.06)
    }
    
    public static func spring(for state: IslandPresentationState) -> Animation {
        state == .expanded ? expandSpring : collapseSpring
    }
    
    public func toggleExpand() {
        if SettingsWindowController.shared.isSettingsOpen {
            return
        }
        let targetState: IslandPresentationState = (state == .compact || state == .hud) ? .expanded : .compact
        let anim = (targetState == .expanded) ? Self.expandSpring : Self.collapseSpring
        withAnimation(anim) {
            state = targetState
            if state == .expanded {
                hudDismissTimer?.invalidate()
            }
        }
    }
    
    public func setExpanded(_ expanded: Bool) {
        if expanded && SettingsWindowController.shared.isSettingsOpen {
            return
        }
        let anim = expanded ? Self.expandSpring : Self.collapseSpring
        withAnimation(anim) {
            state = expanded ? .expanded : .compact
            if expanded {
                hudDismissTimer?.invalidate()
            }
        }
    }
    
    // MARK: - Timer Actions
    public func setTimerMinutes(_ minutes: Int) {
        timerConfig.selectedDurationMinutes = minutes
        timerConfig.remainingSeconds = minutes * 60
        timerConfig.targetDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    public func toggleTimer() {
        if timerConfig.isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }
    
    public func startTimer() {
        timerConfig.isRunning = true
        timerConfig.targetDate = Date().addingTimeInterval(TimeInterval(timerConfig.remainingSeconds))
        
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.timerConfig.remainingSeconds > 0 {
                    self.timerConfig.remainingSeconds -= 1
                } else {
                    self.timerCompleted()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }
    
    public func pauseTimer() {
        timerConfig.isRunning = false
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    public func resetTimer() {
        pauseTimer()
        timerConfig.remainingSeconds = timerConfig.selectedDurationMinutes * 60
        timerConfig.targetDate = Date().addingTimeInterval(TimeInterval(timerConfig.remainingSeconds))
    }
    
    private func timerCompleted() {
        pauseTimer()
        NSSound.beep()
        if timerMode == .pomodoro {
            if timerConfig.pomodoroPhase == .work {
                timerConfig.completedPomodoros += 1
                timerConfig.pomodoroPhase = (timerConfig.completedPomodoros % 4 == 0) ? .longBreak : .shortBreak
                let mins = (timerConfig.pomodoroPhase == .longBreak) ? 15 : 5
                setTimerMinutes(mins)
            } else {
                timerConfig.pomodoroPhase = .work
                setTimerMinutes(25)
            }
        }
    }
    
    // MARK: - Stopwatch Actions
    public func toggleStopwatch() {
        if timerConfig.isRunning {
            timerConfig.isRunning = false
            stopwatchTimer?.invalidate()
            stopwatchTimer = nil
        } else {
            timerConfig.isRunning = true
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.timerConfig.stopwatchElapsedSeconds += 0.1
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            stopwatchTimer = timer
        }
    }
    
    public func resetStopwatch() {
        timerConfig.isRunning = false
        stopwatchTimer?.invalidate()
        stopwatchTimer = nil
        timerConfig.stopwatchElapsedSeconds = 0
        timerConfig.laps.removeAll()
    }
    
    public func lapStopwatch() {
        timerConfig.laps.append(timerConfig.stopwatchElapsedSeconds)
    }
}
