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
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.viewModel.state == .expanded else { return }
            // Do NOT collapse if user is on Drop Shelf (page 4), so the user can select and drag files freely!
            if self.viewModel.selectedPageIndex == 4 { return }
            
            let mouseLocation = NSEvent.mouseLocation
            if let panel = self.panel, !panel.frame.contains(mouseLocation) {
                Task { @MainActor in
                    self.viewModel.setExpanded(false)
                }
            }
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
            
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reposition()
            }
            .store(in: &cancellables)
    }
    
    private func animateFrame(for state: IslandPresentationState) {
        guard let panel = panel else { return }
        let targetFrame = calculateFrame(state: state)
        
        // Fluid Apple cubic spring animation pulling UP into the notch or dropping down smoothly
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
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
            width = 570
            height = 270
        case .hud:
            width = 390
            height = notchHeight
        case .compact:
            // Symmetrical compact ears: 74pt content + 10pt outer padding on each side of the physical notch
            let earTotal: CGFloat = 84.0
            width = physicalNotchWidth + (earTotal * 2.0)
            height = max(notchHeight + 4.0, 36.0)
        }
        
        let x = notchCenterX - (width / 2.0)
        let y = screenRect.maxY - height
        
        return NSRect(x: round(x), y: round(y), width: round(width), height: round(height))
    }
}
