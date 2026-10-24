import SwiftUI

public struct GlowingBadge: View {
    public let text: String
    public let dotColor: Color
    
    public init(text: String = "Live", dotColor: Color = Color.green) {
        self.text = text
        self.dotColor = dotColor
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .shadow(color: dotColor.opacity(0.8), radius: 2)
            
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

public struct PagerIndicator: View {
    public let totalPages: Int
    @Binding public var currentPage: Int
    
    public init(totalPages: Int, currentPage: Binding<Int>) {
        self.totalPages = totalPages
        self._currentPage = currentPage
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentPage = index
                    }
                } label: {
                    ZStack {
                        Capsule()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.25))
                            .frame(width: currentPage == index ? 14 : 5, height: 4)
                    }
                    .frame(width: 14, height: 22)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
