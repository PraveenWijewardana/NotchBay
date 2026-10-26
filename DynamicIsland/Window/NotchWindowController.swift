import AppKit
import SwiftUI
import Combine

@MainActor
public final class NotchWindowController: NSObject, ObservableObject {
    public static let shared = NotchWindowController()
    
    public let viewModel = NotchViewModel()
    private var panel: NotchPanel?
    private var cancellables = Set<AnyCancellable>()
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    
    public override init() {
        super.init()
        setupPanel()
        bindViewModel()
        setupGlobalClickMonitor()
    }
    
    public func show() {
        reposition()
        panel?.orderFrontRegardless()
    }
    
    public func toggle() {
        viewModel.toggleExpand()
    }
    
    private func setupPanel() {
        let initialFrame = calculateFrame(state: .compact)
        let newPanel = NotchPanel(contentRect: initialFrame)
        
        let rootView = NotchContainerView(viewModel: viewModel)
        let hosting = InteractiveHostingView(rootView: rootView)
        hosting.onHoverChanged = { [weak self] isHovering in
            Task { @MainActor in
                self?.viewModel.handleHover(isHovering)
            }
        }
        
        // Auto-expand to Drop Shelf when dragging files towards the notch
        hosting.onDragEntered = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                guard AppSettings.shared.autoOpenShelfOnDrag else { return }
                self.viewModel.selectedPageIndex = 4
                self.viewModel.setExpanded(true)
                self.viewModel.shelfService.isTargeted = true
            }
        }
        
        hosting.onPerformDrag = { [weak self] urls in
            Task { @MainActor in
                guard let self = self else { return }
                for url in urls {
                    self.viewModel.shelfService.addFile(url: url)
                }
                self.viewModel.shelfService.isTargeted = false
            }
        }
        
        newPanel.contentView = hosting
        self.panel = newPanel
        reposition()
    }
    
    private func setupGlobalClickMonitor() {
        // Detects clicks outside the island when expanded and tucks it UP into the notch
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self = self, self.viewModel.state == .expanded else { return }
            // Do not minimize if notch is pinned / locked open
            guard !self.viewModel.isPinned else { return }
            guard AppSettings.shared.autoCollapseOnClickOutside else { return }
            
            // Respect keepOpenOnDropShelf setting
            if AppSettings.shared.keepOpenOnDropShelf && self.viewModel.selectedPageIndex == 4 { return }
            
            let mouseLocation = NSEvent.mouseLocation
            if let panel = self.panel, !panel.frame.contains(mouseLocation) {
                Task { @MainActor in
                    self.viewModel.setExpanded(false)
                }
            }
        }
        
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self = self, self.viewModel.state == .expanded else { return event }
            guard !self.viewModel.isPinned else { return event }
            guard AppSettings.shared.autoCollapseOnClickOutside else { return event }
            if AppSettings.shared.keepOpenOnDropShelf && self.viewModel.selectedPageIndex == 4 { return event }
            
            let mouseLocation = NSEvent.mouseLocation
            if let panel = self.panel, !panel.frame.contains(mouseLocation) {
                Task { @MainActor in
                    self.viewModel.setExpanded(false)
                }
            }
            return event
        }
    }
    
    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.animateFrame(for: state)
            }
            .store(in: &cancellables)
            
        viewModel.$selectedPageIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.viewModel.state == .expanded else { return }
                self.animateFrame(for: .expanded)
            }
            .store(in: &cancellables)
            
        viewModel.caffeineService.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.viewModel.state == .compact else { return }
                self.animateFrame(for: .compact)
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reposition()
            }
            .store(in: &cancellables)
            
        // Observe AppSettings changes to automatically reposition / re-animate
        AppSettings.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reposition()
                }
            }
            .store(in: &cancellables)
    }
    
    private func animateFrame(for state: IslandPresentationState) {
        guard let panel = panel else { return }
        if state == .call {
            panel.orderFrontRegardless()
        }
        let targetFrame = calculateFrame(state: state)
        if panel.frame.equalTo(targetFrame) {
            return
        }
        
        // Ensure the top edge is firmly pinned to targetFrame.maxY before animating.
        // This ensures the animation always begins from the physical notch without any downward offset.
        if abs(panel.frame.maxY - targetFrame.maxY) > 1.0 {
            panel.setFrameOrigin(NSPoint(x: panel.frame.origin.x, y: targetFrame.maxY - panel.frame.height))
        }
        
        let isExpanding = (state == .expanded)
        let duration: TimeInterval = isExpanding ? 0.38 : 0.30
        
        // Fluid Apple cubic spring animation pulling UP into the notch or dropping down smoothly
        // Opening: slight elastic overshoot (1.05) that settles like fluid glass
        // Closing: crisp, smooth deceleration (zero overshoot) tucking cleanly into the notch
        let timing: CAMediaTimingFunction = isExpanding
            ? CAMediaTimingFunction(controlPoints: 0.18, 0.88, 0.28, 1.05)
            : CAMediaTimingFunction(controlPoints: 0.25, 1.0, 0.28, 1.0)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = timing
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(targetFrame, display: true)
        }
    }
    
    public func reposition() {
        guard let panel = panel else { return }
        let targetFrame = calculateFrame(state: viewModel.state)
        panel.setFrame(targetFrame, display: true)
    }
    
    private func calculateFrame(state: IslandPresentationState) -> NSRect {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let screenRect = screen.frame
        let notchHeight: CGFloat = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 32.0
        
        let physicalNotchWidth: CGFloat
        let notchCenterX: CGFloat
        if let auxLeft = screen.auxiliaryTopLeftArea, let auxRight = screen.auxiliaryTopRightArea {
            physicalNotchWidth = max(150.0, auxRight.minX - auxLeft.maxX)
            notchCenterX = (auxLeft.maxX + auxRight.minX) / 2.0
        } else {
            physicalNotchWidth = 179.0
            notchCenterX = screenRect.midX
        }
        
        let width: CGFloat
        let height: CGFloat
        
        switch state {
        case .expanded:
            width = CGFloat(AppSettings.shared.islandWidthExpanded)
            height = CGFloat(AppSettings.shared.islandHeightExpanded)
        case .call:
            width = max(460.0, physicalNotchWidth + 240.0)
            height = notchHeight + 62.0
        case .hud:
            let earWidth: CGFloat = 130.0
            width = max(460.0, physicalNotchWidth + (earWidth * 2.0) + 16.0)
            height = max(notchHeight + 8.0, 44.0)
        case .compact:
            // Symmetrical compact ears from user settings
            let extraCaffeine: CGFloat = (viewModel.caffeineService.isActive && AppSettings.shared.showCaffeineInCompact) ? 12.0 : 0.0
            let earContent: CGFloat = CGFloat(AppSettings.shared.compactEarWidth) + extraCaffeine
            let earTotal: CGFloat = earContent + 10.0
            width = physicalNotchWidth + (earTotal * 2.0)
            height = max(notchHeight + 4.0, 36.0)
        }
        
        let x = notchCenterX - (width / 2.0)
        var y = screenRect.maxY - height
        
        // If user enabled Floating Dynamic Island mode (e.g. for external monitors or non-notch Macs)
        if AppSettings.shared.floatingIslandMode {
            y -= CGFloat(AppSettings.shared.floatingTopMargin)
        }
        
        return NSRect(x: round(x), y: round(y), width: round(width), height: round(height))
    }
}
