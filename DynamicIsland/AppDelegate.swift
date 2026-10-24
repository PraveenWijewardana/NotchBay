import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var controller: NotchWindowController?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Set application icon from bundled or local AppIcon.icns
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        } else if let iconImage = NSImage(contentsOfFile: "DynamicIsland/Resources/AppIcon.icns") {
            NSApp.applicationIconImage = iconImage
        }

        // Set activation policy as accessory app so it doesn't clutter Dock unless desired
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize Notch Window Controller
        let windowCtrl = NotchWindowController.shared
        self.controller = windowCtrl
        windowCtrl.show()
        
        // Setup Menu Bar Status Item
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "NotchBay")
            button.image?.isTemplate = true
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Toggle NotchBay", action: #selector(toggleIsland), keyEquivalent: "i"))
        menu.addItem(NSMenuItem.separator())
        
        let pageMenu = NSMenu()
        pageMenu.addItem(NSMenuItem(title: "Home", action: #selector(showHome), keyEquivalent: "1"))
        pageMenu.addItem(NSMenuItem(title: "System Overview", action: #selector(showSystem), keyEquivalent: "2"))
        pageMenu.addItem(NSMenuItem(title: "Timers & Pomodoro", action: #selector(showTimers), keyEquivalent: "3"))
        pageMenu.addItem(NSMenuItem(title: "Now Playing", action: #selector(showMedia), keyEquivalent: "4"))
        pageMenu.addItem(NSMenuItem(title: "Drop Shelf", action: #selector(showShelf), keyEquivalent: "5"))
        pageMenu.addItem(NSMenuItem(title: "Code Agents", action: #selector(showAgents), keyEquivalent: "6"))
        
        let viewsItem = NSMenuItem(title: "Quick Switch Page", action: nil, keyEquivalent: "")
        viewsItem.submenu = pageMenu
        menu.addItem(viewsItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Center / Reset Position", action: #selector(recenterIsland), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit NotchBay", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleIsland() {
        controller?.toggle()
    }
    
    @objc private func showHome() {
        controller?.viewModel.selectedPageIndex = 0
        controller?.viewModel.setExpanded(true)
    }
    
    @objc private func showSystem() {
        controller?.viewModel.selectedPageIndex = 1
        controller?.viewModel.systemDetailMode = nil
        controller?.viewModel.setExpanded(true)
    }
    
    @objc private func showTimers() {
        controller?.viewModel.selectedPageIndex = 2
        controller?.viewModel.setExpanded(true)
    }
    
    @objc private func showMedia() {
        controller?.viewModel.selectedPageIndex = 3
        controller?.viewModel.setExpanded(true)
    }
    
    @objc private func showShelf() {
        controller?.viewModel.selectedPageIndex = 4
        controller?.viewModel.setExpanded(true)
    }
    
    @objc private func showAgents() {
        controller?.viewModel.selectedPageIndex = 5
        controller?.viewModel.setExpanded(true)
    }
    
    @objc private func recenterIsland() {
        controller?.reposition()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
