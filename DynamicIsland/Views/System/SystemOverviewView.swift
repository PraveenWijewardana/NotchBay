import SwiftUI

public struct SystemOverviewView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var systemService: SystemMonitorService
    @ObservedObject private var networkService: NetworkMonitorService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.systemService = viewModel.systemService
        self.networkService = viewModel.networkService
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    public var body: some View {
        Group {
            if let mode = viewModel.systemDetailMode {
                switch mode {
                case .cpu:
                    CPUDetailView(viewModel: viewModel)
                case .gpu:
                    GPUDetailView(viewModel: viewModel)
                case .memory:
                    MemoryDetailView(viewModel: viewModel)
                case .swap:
                    SwapDetailView(viewModel: viewModel)
                case .storage:
                    StorageDetailView(viewModel: viewModel)
                case .network:
                    NetworkDetailView(viewModel: viewModel)
                case .diskIO:
                    DiskIODetailView(viewModel: viewModel)
                case .power:
                    PowerDetailView(viewModel: viewModel)
                }
            } else {
                gridView
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
    
    private var gridView: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                Text("System")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                GlowingBadge(text: "Live", dotColor: .green)
            }
            .padding(.horizontal, 4)
            
            // 4x2 Grid of Telemetry (Every block opens its detail view)
            LazyVGrid(columns: columns, spacing: 8) {
                // 1. CPU Block
                Button {
                    openDetail(.cpu)
                } label: {
                    MetricCardView(
                        icon: "cpu",
                        iconColor: .cyan,
                        title: "CPU",
                        mainValue: String(format: "%.0f%%", viewModel.systemService.cpuMetrics.usagePercentage)
                    ) {
                        SparklineChart(
                            data: viewModel.systemService.cpuMetrics.history,
                            strokeColor: .cyan,
                            fillColor: .cyan.opacity(0.2),
                            lineWidth: 1.5
                        )
                    }
                }
                .buttonStyle(.plain)
                
                // 2. GPU Block
                Button {
                    openDetail(.gpu)
                } label: {
                    MetricCardView(
                        icon: "square.grid.3x3.topleft.filled",
                        iconColor: .teal,
                        title: "GPU",
                        mainValue: String(format: "%.0f%%", viewModel.systemService.gpuMetrics.usagePercentage)
                    ) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule()
                                    .fill(Color.teal)
                                    .frame(width: geo.size.width * CGFloat(viewModel.systemService.gpuMetrics.usagePercentage / 100.0))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // 3. MEMORY Block
                Button {
                    openDetail(.memory)
                } label: {
                    MetricCardView(
                        icon: "memorychip",
                        iconColor: .purple,
                        title: "Memory",
                        mainValue: viewModel.systemService.memoryMetrics.usedFormatted
                    ) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule()
                                    .fill(Color.purple)
                                    .frame(width: geo.size.width * CGFloat(viewModel.systemService.memoryMetrics.usageFraction))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // 4. SWAP Block
                Button {
                    openDetail(.swap)
                } label: {
                    MetricCardView(
                        icon: "arrow.left.arrow.right",
                        iconColor: .indigo,
                        title: "Swap",
                        mainValue: viewModel.systemService.memoryMetrics.swapUsedBytes > 0
                            ? ByteCountFormatter.string(fromByteCount: Int64(viewModel.systemService.memoryMetrics.swapUsedBytes), countStyle: .memory)
                            : "None"
                    ) {
                        Text(viewModel.systemService.memoryMetrics.swapUsedBytes > 0 ? "in use" : "no swap in use")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                
                // 5. STORAGE Block
                Button {
                    openDetail(.storage)
                } label: {
                    MetricCardView(
                        icon: "internaldrive",
                        iconColor: .orange,
                        title: "Storage",
                        mainValue: "\(viewModel.systemService.storageMetrics.freeFormatted) free"
                    ) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule()
                                    .fill(Color.orange)
                                    .frame(width: geo.size.width * CGFloat(viewModel.systemService.storageMetrics.usedFraction))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // 6. NETWORK Block
                Button {
                    openDetail(.network)
                } label: {
                    MetricCardView(
                        icon: "globe",
                        iconColor: .blue,
                        title: "Network",
                        mainValue: "↓ \(NetworkMetrics.formatSpeed(viewModel.networkService.metrics.currentDownSpeed))"
                    ) {
                        Text("↑ \(NetworkMetrics.formatSpeed(viewModel.networkService.metrics.currentUpSpeed))")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                
                // 7. DISK I/O Block
                Button {
                    openDetail(.diskIO)
                } label: {
                    MetricCardView(
                        icon: "externaldrive",
                        iconColor: .cyan,
                        title: "Disk I/O",
                        mainValue: viewModel.systemService.diskIOMetrics.readFormatted
                    ) {
                        Text(viewModel.systemService.diskIOMetrics.writeFormatted)
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                
                // 8. POWER Block
                Button {
                    openDetail(.power)
                } label: {
                    MetricCardView(
                        icon: viewModel.systemService.powerMetrics.isCharging ? "battery.100.bolt" : "battery.75",
                        iconColor: .green,
                        title: "Power",
                        mainValue: "\(viewModel.systemService.powerMetrics.batteryLevel)%"
                    ) {
                        Text(viewModel.systemService.powerMetrics.statusDescription)
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func openDetail(_ block: SystemDetailBlock) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            viewModel.systemDetailMode = block
        }
    }
}
