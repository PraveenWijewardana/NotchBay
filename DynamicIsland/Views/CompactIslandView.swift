import SwiftUI

public struct CompactIslandView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var systemService: SystemMonitorService
    @ObservedObject private var networkService: NetworkMonitorService
    @ObservedObject private var mediaService: MediaControllerService
    
    // Each ear has a fixed 44pt content width + 6pt padding for exact symmetry
    private let earWidth: CGFloat = 44.0
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.systemService = viewModel.systemService
        self.networkService = viewModel.networkService
        self.mediaService = viewModel.mediaService
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left Ear: CPU Load or Animated Music Equalizer
            leftEarView
                .frame(width: earWidth, alignment: .leading)
                .padding(.leading, 6)
            
            // Center Notch Bridge (matches physical hardware notch width with 100% mathematical center)
            ZStack {
                Color.clear
                    .frame(width: viewModel.physicalNotchWidth)
                
                if viewModel.isHovering {
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .frame(width: viewModel.physicalNotchWidth)
            
            // Right Ear: Symmetrically sized to earWidth, pinned to outer right
            rightEarView
                .frame(width: earWidth, alignment: .trailing)
                .padding(.trailing, 6)
        }
        .frame(height: 32)
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
        HStack(spacing: 3.5) {
            if viewModel.mediaService.currentTrack.isPlaying {
                if let data = viewModel.mediaService.currentTrack.artworkData,
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 13, height: 13)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                
                HStack(alignment: .bottom, spacing: 1.5) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom))
                            .frame(width: 1.8, height: max(2.5, viewModel.mediaService.audioFrequencies[i] * 10))
                    }
                }
                .frame(height: 11)
            } else {
                Image(systemName: "cpu")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(viewModel.isHovering ? .white : .cyan)
                    .shadow(color: .cyan.opacity(viewModel.isHovering ? 0.8 : 0.0), radius: 3)
                
                Text(String(format: "%.0f%%", viewModel.systemService.cpuMetrics.usagePercentage))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
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
        HStack(spacing: 3) {
            if viewModel.agentService.status == .awaitingPermission {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.8), radius: 3)
                Text("Approve")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
            } else if viewModel.timerConfig.isRunning {
                Image(systemName: "timer")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(viewModel.isHovering ? 0.8 : 0.0), radius: 3)
                Text(viewModel.timerConfig.formattedTime)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.yellow)
            } else {
                let down = viewModel.networkService.metrics.currentDownSpeed
                let up = viewModel.networkService.metrics.currentUpSpeed
                let isUpload = up > down && up >= 1024
                let activeSpeed = isUpload ? up : down
                let icon = isUpload ? "arrow.up" : "arrow.down"
                let iconColor = isUpload ? Color.teal : (viewModel.isHovering ? Color.cyan : Color.blue)
                
                Image(systemName: icon)
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(iconColor)
                Text(NetworkMetrics.formatSpeed(activeSpeed))
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .scaleEffect(viewModel.isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.isHovering)
    }
}
