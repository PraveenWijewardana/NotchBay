import SwiftUI

public struct CompactIslandView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var systemService: SystemMonitorService
    @ObservedObject private var networkService: NetworkMonitorService
    @ObservedObject private var mediaService: MediaControllerService
    
    // Symmetrical ear content width with generous breathing room
    private let earWidth: CGFloat = 50.0
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.systemService = viewModel.systemService
        self.networkService = viewModel.networkService
        self.mediaService = viewModel.mediaService
    }
    
    private var cpuColor: Color {
        let usage = systemService.cpuMetrics.usagePercentage
        if usage > 70 { return Color(red: 1.0, green: 0.35, blue: 0.35) }
        if usage > 30 { return Color(red: 1.0, green: 0.8, blue: 0.2) }
        return Color(red: 0.2, green: 0.85, blue: 0.95)
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left Ear: CPU Load or Animated Music Equalizer
            leftEarView
                .frame(width: earWidth, alignment: .leading)
                .padding(.leading, 10)
            
            // Center Notch Bridge (matches physical hardware notch width with exact mathematical center)
            ZStack {
                Color.clear
                    .frame(width: viewModel.physicalNotchWidth)
                
                if viewModel.isHovering {
                    ZStack {
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 22, height: 12)
                        
                        Image(systemName: "chevron.compact.down")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .frame(width: viewModel.physicalNotchWidth)
            
            // Right Ear: Symmetrically sized to earWidth, pinned to outer right
            rightEarView
                .frame(width: earWidth, alignment: .trailing)
                .padding(.trailing, 10)
        }
        .frame(height: viewModel.compactHeight)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .text, .image], isTargeted: nil) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                viewModel.selectedPageIndex = 4
                viewModel.state = .expanded
            }
            return true
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                viewModel.state = .expanded
            }
        }
    }
    
    // MARK: - Left Ear Content (Music Artwork/Equalizer or CPU Load)
    @ViewBuilder
    private var leftEarView: some View {
        HStack(spacing: 4) {
            if mediaService.currentTrack.isPlaying {
                if let data = mediaService.currentTrack.artworkData,
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 15, height: 15)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                        .shadow(color: .purple.opacity(0.3), radius: 2)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 15, height: 15)
                        Image(systemName: "music.note")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                HStack(alignment: .bottom, spacing: 1.5) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom))
                            .frame(width: 2.0, height: max(3.0, mediaService.audioFrequencies[i] * 12))
                    }
                }
                .frame(height: 12)
            } else {
                Image(systemName: "cpu")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(cpuColor)
                    .shadow(color: cpuColor.opacity(viewModel.isHovering ? 0.7 : 0.25), radius: 2.5)
                
                Text(String(format: "%.0f%%", systemService.cpuMetrics.usagePercentage))
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .scaleEffect(viewModel.isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.isHovering)
    }
    
    // MARK: - Right Ear Content (Agent Status, Timer, or Network Speed)
    @ViewBuilder
    private var rightEarView: some View {
        HStack(spacing: 3.5) {
            if viewModel.agentService.status == .awaitingPermission {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.8), radius: 3)
                Text("Approve")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
            } else if viewModel.agentService.status == .executing || viewModel.agentService.status == .coding {
                Image(systemName: viewModel.agentService.selectedAgent.iconName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(viewModel.agentService.selectedAgent.accentColor)
                    .shadow(color: viewModel.agentService.selectedAgent.accentColor.opacity(0.6), radius: 2)
                Text("Working")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.agentService.selectedAgent.accentColor)
            } else if viewModel.agentService.status == .thinking {
                Image(systemName: "brain")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.6), radius: 2)
                Text("Thinking")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
            } else if viewModel.agentService.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.6), radius: 2)
                Text("Done")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
            } else if viewModel.timerConfig.isRunning {
                Image(systemName: "timer")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(viewModel.isHovering ? 0.8 : 0.3), radius: 2.5)
                Text(viewModel.timerConfig.formattedTime)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.yellow)
            } else {
                let down = viewModel.networkService.metrics.currentDownSpeed
                let up = viewModel.networkService.metrics.currentUpSpeed
                let isUpload = up > down && up >= 1024
                let activeSpeed = isUpload ? up : down
                let icon = isUpload ? "arrow.up" : "arrow.down"
                let iconColor = isUpload ? Color(red: 0.3, green: 0.9, blue: 0.5) : Color(red: 0.2, green: 0.85, blue: 0.95)
                
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(iconColor)
                    .shadow(color: iconColor.opacity(0.4), radius: 2)
                
                Text(NetworkMetrics.formatSpeed(activeSpeed))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .scaleEffect(viewModel.isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.isHovering)
    }
}
