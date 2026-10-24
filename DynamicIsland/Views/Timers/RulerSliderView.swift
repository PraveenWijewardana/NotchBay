import SwiftUI

public struct RulerSliderView: View {
    @Binding public var selectedMinutes: Int
    public let range: ClosedRange<Int>
    
    public init(selectedMinutes: Binding<Int>, range: ClosedRange<Int> = 1...60) {
        self._selectedMinutes = selectedMinutes
        self.range = range
    }
    
    public var body: some View {
        GeometryReader { geo in
            let totalMarks = range.upperBound - range.lowerBound
            let spacing = geo.size.width / CGFloat(max(1, totalMarks))
            
            ZStack(alignment: .bottomLeading) {
                // Ruler baseline
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                    .offset(y: -18)
                
                // Ticks and numbers
                ForEach(range, id: \.self) { minute in
                    let xOffset = CGFloat(minute - range.lowerBound) * spacing
                    let isSelected = (minute == selectedMinutes)
                    let isMajor = (minute % 5 == 0) || (minute == 1)
                    
                    VStack(spacing: 4) {
                        // Tick mark
                        Rectangle()
                            .fill(isSelected ? Color.yellow : (isMajor ? Color.white.opacity(0.7) : Color.white.opacity(0.2)))
                            .frame(width: isSelected ? 2.5 : 1.2, height: isSelected ? 16 : (isMajor ? 10 : 6))
                        
                        // Major number label
                        if isMajor {
                            Text("\(minute)")
                                .font(.system(size: 8.5, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSelected ? .yellow : .secondary)
                        } else {
                            Spacer()
                                .frame(height: 10)
                        }
                    }
                    .position(x: xOffset, y: geo.size.height / 2)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedX = max(0, min(geo.size.width, value.location.x))
                        let fraction = clampedX / geo.size.width
                        let calculatedMin = Int(round(Double(range.lowerBound) + fraction * Double(totalMarks)))
                        selectedMinutes = max(range.lowerBound, min(range.upperBound, calculatedMin))
                    }
            )
        }
        .frame(height: 38)
    }
}
