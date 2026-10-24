import SwiftUI

public struct MetricCardView<Content: View>: View {
    public let icon: String
    public let iconColor: Color
    public let title: String
    public let mainValue: String
    @ViewBuilder public let footer: () -> Content
    
    public init(
        icon: String,
        iconColor: Color,
        title: String,
        mainValue: String,
        @ViewBuilder footer: @escaping () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.mainValue = mainValue
        self.footer = footer
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Icon + Category Title
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(iconColor)
                
                Text(title.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Primary Value
            Text(mainValue)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Footer: sparkline, progress bar, or subtitle
            footer()
                .frame(height: 12)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
