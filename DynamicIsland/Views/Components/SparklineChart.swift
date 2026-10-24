import SwiftUI

public struct SparklineChart: View {
    public let data: [Double]
    public let strokeColor: Color
    public let fillColor: Color
    public let lineWidth: CGFloat
    
    public init(
        data: [Double],
        strokeColor: Color = Color.cyan,
        fillColor: Color = Color.cyan.opacity(0.15),
        lineWidth: CGFloat = 2.0
    ) {
        self.data = data
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.lineWidth = lineWidth
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)
            
            ZStack {
                // Gradient Fill Area
                if points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: proxy.size.height))
                        path.addLine(to: points[0])
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                        path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [fillColor, fillColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                // Stroke Line
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for i in 1..<points.count {
                            // Smooth quadratic curve between points
                            let mid = CGPoint(
                                x: (points[i-1].x + points[i].x) / 2.0,
                                y: (points[i-1].y + points[i].y) / 2.0
                            )
                            path.addQuadCurve(to: mid, control: points[i-1])
                            path.addLine(to: points[i])
                        }
                    }
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
    
    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        let maxVal = max(data.max() ?? 1.0, 1.0)
        let stepX = size.width / CGFloat(data.count - 1)
        
        return data.enumerated().map { index, val in
            let x = CGFloat(index) * stepX
            let normalizedY = CGFloat(val / maxVal)
            let y = size.height - (normalizedY * (size.height - 4)) - 2
            return CGPoint(x: x, y: y)
        }
    }
}
