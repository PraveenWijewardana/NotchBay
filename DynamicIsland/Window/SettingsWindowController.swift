import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    public let settingsModel = SettingsViewModel()
    public private(set) var isSettingsOpen: Bool = false
    
    public override init() {
        super.init()
    }
    
    public func showWindow(tab: SettingsTab? = nil) {
        isSettingsOpen = true
        // Automatically collapse and cancel hover when opening Settings
        NotchWindowController.shared.viewModel.handleHover(false)
        NotchWindowController.shared.viewModel.setExpanded(false)
        
        if let tab = tab {
            settingsModel.selectedTab = tab
        }
        
        if let existing = window {
            centerWindowOnActiveScreen(existing)
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(model: settingsModel)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let windowWidth: CGFloat = 840
        let windowHeight: CGFloat = 620
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "NotchBay Settings"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .visible
        newWindow.toolbarStyle = .unified
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.contentViewController = hostingController
        newWindow.minSize = NSSize(width: 740, height: 520)
        newWindow.level = .normal
        
        // Dark aesthetic background
        newWindow.backgroundColor = NSColor(red: 0.05, green: 0.055, blue: 0.075, alpha: 1.0)
        
        self.window = newWindow
        centerWindowOnActiveScreen(newWindow)
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func centerWindowOnActiveScreen(_ win: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        
        guard let screen = targetScreen else {
            win.center()
            return
        }
        
        let screenVisibleFrame = screen.visibleFrame
        let windowSize = win.frame.size
        
        let x = screenVisibleFrame.origin.x + (screenVisibleFrame.width - windowSize.width) / 2.0
        let y = screenVisibleFrame.origin.y + (screenVisibleFrame.height - windowSize.height) / 2.0
        
        win.setFrameOrigin(NSPoint(x: round(x), y: round(y)))
    }
    
    public func closeWindow() {
        isSettingsOpen = false
        window?.close()
    }
    
    public func windowDidBecomeKey(_ notification: Notification) {
        isSettingsOpen = true
        NotchWindowController.shared.viewModel.handleHover(false)
        NotchWindowController.shared.viewModel.setExpanded(false)
    }
    
    public func windowWillClose(_ notification: Notification) {
        isSettingsOpen = false
    }
}
