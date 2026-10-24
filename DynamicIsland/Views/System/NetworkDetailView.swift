import SwiftUI

public struct NetworkDetailView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var networkService: NetworkMonitorService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.networkService = viewModel.networkService
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header: Breadcrumb & Live Badge
            HStack {
                HStack(spacing: 4) {
                    Text("System")
                        .foregroundColor(.secondary)
                    Text("▸")
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Network")
                        .foregroundColor(.white)
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                
                Spacer()
                
                GlowingBadge(text: "Live", dotColor: .green)
            }
            
            // Sub-header: < All button + Current Live Speed + Mini Chart
            HStack(alignment: .center, spacing: 10) {
                // Back Button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        viewModel.systemDetailMode = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("All")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                // Network Title
                HStack(spacing: 5) {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    Text("Network")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Live Rates (Down & Up)
                HStack(spacing: 12) {
                    HStack(spacing: 3.5) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                        Text(NetworkMetrics.formatSpeed(viewModel.networkService.metrics.currentDownSpeed))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 3.5) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                        Text(NetworkMetrics.formatSpeed(viewModel.networkService.metrics.currentUpSpeed))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Dual Live Waveform Graph (Download & Upload)
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                    
                    // Up Speed Sparkline (Cyan)
                    let upHistory = viewModel.networkService.metrics.history.map { $0.upBytesPerSec }
                    SparklineChart(
                        data: upHistory.isEmpty ? [0, 0] : upHistory,
                        strokeColor: .cyan,
                        fillColor: .cyan.opacity(0.1),
                        lineWidth: 1.5
                    )
                    
                    // Down Speed Sparkline (Blue)
                    let downHistory = viewModel.networkService.metrics.history.map { $0.downBytesPerSec }
                    SparklineChart(
                        data: downHistory.isEmpty ? [0, 0] : downHistory,
                        strokeColor: .blue,
                        fillColor: .blue.opacity(0.2),
                        lineWidth: 2.0
                    )
                }
                .frame(height: 52)
                
                // Legend
                HStack {
                    HStack(spacing: 4) {
                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                        Text("Down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Circle().fill(Color.cyan).frame(width: 6, height: 6)
                        Text("Up")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("last 30s")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 2)
            }
            
            // 4 Summary Cards: Peak Down, Peak Up, Session Down, Session Up
            HStack(spacing: 6) {
                // Peak Down
                VStack(spacing: 2.5) {
                    Text(NetworkMetrics.formatSpeed(viewModel.networkService.metrics.peakDownSpeed))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("PEAK ↓")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.blue.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color(white: 0.12)))
                
                // Peak Up
                VStack(spacing: 2.5) {
                    Text(NetworkMetrics.formatSpeed(viewModel.networkService.metrics.peakUpSpeed))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("PEAK ↑")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color(white: 0.12)))
                
                // Session Down
                VStack(spacing: 2.5) {
                    Text(NetworkMetrics.formatBytes(viewModel.networkService.metrics.sessionDownloadedBytes))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("TOTAL ↓")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color(white: 0.12)))
                
                // Session Up
                VStack(spacing: 2.5) {
                    Text(NetworkMetrics.formatBytes(viewModel.networkService.metrics.sessionUploadedBytes))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("TOTAL ↑")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color(white: 0.12)))
            }
        }
    }
}
