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
            existing.makeKeyAndOrderFront(nil)
            existing.center()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(model: settingsModel)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 620),
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
        newWindow.center()
        newWindow.level = .normal
        
        // Dark aesthetic background
        newWindow.backgroundColor = NSColor(red: 0.05, green: 0.055, blue: 0.075, alpha: 1.0)
        
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
