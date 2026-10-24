import AppKit
import SwiftUI

public final class InteractiveHostingView<Content: View>: NSHostingView<Content> {
    private var customTrackingArea: NSTrackingArea?
    public var onHoverChanged: ((Bool) -> Void)?
    public var onDragEntered: (() -> Void)?
    public var onPerformDrag: (([URL]) -> Void)?
    
    required public init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDrag()
    }
    
    @MainActor required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDrag()
    }
    
    private func registerForDrag() {
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            .tiff,
            .png
        ])
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = customTrackingArea {
            removeTrackingArea(existing)
        }
        
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways,
            .inVisibleRect
        ]
        
        let newArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(newArea)
        self.customTrackingArea = newArea
    }
    
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(true)
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(false)
    }
    
    // MARK: - NSDraggingDestination Protocol
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        return .copy
    }
    
    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
            return false
        }
        onPerformDrag?(urls)
        return true
    }
}
