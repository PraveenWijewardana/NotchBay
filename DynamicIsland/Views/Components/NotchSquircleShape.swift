import SwiftUI

/// A custom continuous squircle shape designed specifically for the Dynamic Island.
/// Conforms to `InsettableShape` to support both `.fill(...)` and `.strokeBorder(...)`.
/// The top edge is flat (anchored flush to the MacBook screen bezel),
/// while the bottom-left and bottom-right corners feature smoothly curved continuous arcs.
/// Implements `animatableData` so SwiftUI smoothly interpolates the corner curvature
/// on every single frame during expand/collapse transitions without ever showing sharp box corners.
public struct NotchSquircleShape: InsettableShape {
    public var cornerRadius: CGFloat
    public var insetAmount: CGFloat = 0
    
    public var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    
    public init(cornerRadius: CGFloat, insetAmount: CGFloat = 0) {
        self.cornerRadius = cornerRadius
        self.insetAmount = insetAmount
    }
    
    public func inset(by amount: CGFloat) -> NotchSquircleShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard insetRect.width > 0 && insetRect.height > 0 else { return path }
        
        let radius = max(0, min(cornerRadius - insetAmount, min(insetRect.width / 2.0, insetRect.height)))
        
        // Start top-left flush against bezel
        path.move(to: CGPoint(x: insetRect.minX, y: insetRect.minY))
        
        // Top edge: flat against the bezel
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.minY))
        
        // Right edge down to bottom-right corner curve start
        path.addLine(to: CGPoint(x: insetRect.maxX, y: max(insetRect.minY, insetRect.maxY - radius)))
        
        // Bottom-right corner arc
        path.addArc(
            center: CGPoint(x: insetRect.maxX - radius, y: insetRect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: insetRect.minX + radius, y: insetRect.maxY))
        
        // Bottom-left corner arc
        path.addArc(
            center: CGPoint(x: insetRect.minX + radius, y: insetRect.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Left edge back up to top-left
        path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.minY))
        path.closeSubpath()
        
        return path
    }
}
