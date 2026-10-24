import SwiftUI

// MARK: - CPU Detail View
public struct CPUDetailView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var systemService: SystemMonitorService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.systemService = viewModel.systemService
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            header(title: "CPU")
            
            HStack(spacing: 12) {
                // Left: Big Usage & History Graph
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(format: "%.0f%%", viewModel.systemService.cpuMetrics.usagePercentage))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("TOTAL LOAD")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "Peak: %.0f%%", viewModel.systemService.cpuMetrics.peakPercentage))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                    
                    SparklineChart(
                        data: viewModel.systemService.cpuMetrics.history,
                        strokeColor: .cyan,
                        fillColor: .cyan.opacity(0.18),
                        lineWidth: 2
                    )
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                }
                .frame(maxWidth: .infinity)
                
                // Right: User / System / Idle breakdown & Per-Core bars
                VStack(spacing: 8) {
                    statRow(label: "User", value: String(format: "%.1f%%", viewModel.systemService.cpuMetrics.userPercentage), color: .cyan)
                    statRow(label: "System", value: String(format: "%.1f%%", viewModel.systemService.cpuMetrics.systemPercentage), color: .blue)
                    statRow(label: "Idle", value: String(format: "%.1f%%", viewModel.systemService.cpuMetrics.idlePercentage), color: .gray)
                    statRow(label: "Cores", value: "\(viewModel.systemService.cpuMetrics.coreLoads.count)", color: .white)
                }
                .frame(width: 140)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
            }
        }
    }
    
    private func header(title: String) -> some View {
        DetailHeaderView(title: title, onBack: { viewModel.systemDetailMode = nil })
    }
    
    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(color)
        }
    }
}

// MARK: - GPU Detail View
public struct GPUDetailView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var systemService: SystemMonitorService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.systemService = viewModel.systemService
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            DetailHeaderView(title: "GPU", onBack: { viewModel.systemDetailMode = nil })
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(format: "%.0f%%", viewModel.systemService.gpuMetrics.usagePercentage))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("DEVICE UTILIZATION")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    SparklineChart(
                        data: viewModel.systemService.gpuMetrics.history,
                        strokeColor: .teal,
                        fillColor: .teal.opacity(0.18),
                        lineWidth: 2
                    )
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 8) {
                    statRow(label: "Tiler", value: String(format: "%.0f%%", viewModel.systemService.gpuMetrics.tilerPercentage))
                    statRow(label: "Renderer", value: String(format: "%.0f%%", viewModel.systemService.gpuMetrics.rendererPercentage))
                    statRow(
                        label: "Metal Memory",
                        value: viewModel.systemService.gpuMetrics.memoryInUseBytes > 0
                            ? ByteCountFormatter.string(fromByteCount: Int64(viewModel.systemService.gpuMetrics.memoryInUseBytes), countStyle: .memory)
                            : "Dynamic"
                    )
                }
                .frame(width: 150)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
            }
        }
    }
    
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.teal)
        }
    }
}

// MARK: - Memory Detail View
public struct MemoryDetailView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var systemService: SystemMonitorService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.systemService = viewModel.systemService
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            DetailHeaderView(title: "Memory", onBack: { viewModel.systemDetailMode = nil })
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(viewModel.systemService.memoryMetrics.usedFormatted) Used")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Total \(viewModel.systemService.memoryMetrics.totalFormatted)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12)).frame(height: 6)
                        Capsule()
                            .fill(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(viewModel.systemService.memoryMetrics.usageFraction), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 2)
            
            // 4 Memory Breakdown Cards
            HStack(spacing: 8) {
                breakdownCard(label: "Active", value: viewModel.systemService.memoryMetrics.activeFormatted, color: .purple)
                breakdownCard(label: "Wired", value: viewModel.systemService.memoryMetrics.wiredFormatted, color: .blue)
                breakdownCard(label: "Compressed", value: viewModel.systemService.memoryMetrics.compressedFormatted, color: .orange)
                breakdownCard(label: "Free / Cache", value: viewModel.systemService.memoryMetrics.freeFormatted, color: .green)
            }
        }
    }
    
    private func breakdownCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(label.uppercased()).font(.system(size: 8.5, weight: .bold, design: .rounded)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
    }
}

// MARK: - Swap Detail View
public struct SwapDetailView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var systemService: SystemMonitorService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.systemService = viewModel.systemService
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            DetailHeaderView(title: "Swap Space", onBack: { viewModel.systemDetailMode = nil })
            
            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(viewModel.systemService.memoryMetrics.swapUsedBytes > 0 ? .orange : .indigo)
                    Text(viewModel.systemService.memoryMetrics.swapUsedBytes > 0 ? "Swap Active" : "No Swap in Use")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
                
                VStack(spacing: 8) {
                    infoRow(label: "Swap Used", value: viewModel.systemService.memoryMetrics.swapUsedBytes > 0 ? ByteCountFormatter.string(fromByteCount: Int64(viewModel.systemService.memoryMetrics.swapUsedBytes), countStyle: .memory) : "0 B")
                    infoRow(label: "Swap Total", value: viewModel.systemService.memoryMetrics.swapTotalBytes > 0 ? ByteCountFormatter.string(fromByteCount: Int64(viewModel.systemService.memoryMetrics.swapTotalBytes), countStyle: .memory) : "Dynamic")
                    infoRow(label: "Memory Pressure", value: "Normal")
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
            }
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.white)
        }
    }
}

// MARK: - Storage Detail View
public struct StorageDetailView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var systemService: SystemMonitorService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.systemService = viewModel.systemService
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            DetailHeaderView(title: "Storage", onBack: { viewModel.systemDetailMode = nil })
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "internaldrive").foregroundColor(.orange)
                        Text(viewModel.systemService.storageMetrics.volumeName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("\(viewModel.systemService.storageMetrics.freeFormatted) Free of \(viewModel.systemService.storageMetrics.totalFormatted)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12)).frame(height: 8)
                        Capsule()
                            .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(viewModel.systemService.storageMetrics.usedFraction), height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
            
            HStack(spacing: 8) {
                metricBox(title: "USED CAPACITY", value: viewModel.systemService.storageMetrics.usedFormatted)
                metricBox(title: "FREE CAPACITY", value: viewModel.systemService.storageMetrics.freeFormatted)
                metricBox(title: "TOTAL SIZE", value: viewModel.systemService.storageMetrics.totalFormatted)
            }
        }
    }
    
    private func metricBox(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(title).font(.system(size: 8.5, weight: .bold, design: .rounded)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
    }
}

// MARK: - Disk I/O Detail View
public struct DiskIODetailView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var systemService: SystemMonitorService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.systemService = viewModel.systemService
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            DetailHeaderView(title: "Disk I/O", onBack: { viewModel.systemDetailMode = nil })
            
            HStack(spacing: 10) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill").font(.system(size: 20)).foregroundColor(.cyan)
                    Text(viewModel.systemService.diskIOMetrics.readFormatted)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("CURRENT READ SPEED")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
                
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 20)).foregroundColor(.teal)
                    Text(viewModel.systemService.diskIOMetrics.writeFormatted)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("CURRENT WRITE SPEED")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
            }
            
            HStack(spacing: 8) {
                Text("Total Read: \(ByteCountFormatter.string(fromByteCount: Int64(viewModel.systemService.diskIOMetrics.totalReadBytes), countStyle: .file))")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Total Written: \(ByteCountFormatter.string(fromByteCount: Int64(viewModel.systemService.diskIOMetrics.totalWriteBytes), countStyle: .file))")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Power Detail View
public struct PowerDetailView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var systemService: SystemMonitorService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.systemService = viewModel.systemService
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            DetailHeaderView(title: "Power & Battery", onBack: { viewModel.systemDetailMode = nil })
            
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(systemName: viewModel.systemService.powerMetrics.isCharging ? "battery.100.bolt" : "battery.75")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                    Text("\(viewModel.systemService.powerMetrics.batteryLevel)%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(viewModel.systemService.powerMetrics.powerSourceState.uppercased())
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
                
                VStack(spacing: 8) {
                    infoRow(label: "Status", value: viewModel.systemService.powerMetrics.statusDescription)
                    infoRow(label: "Estimate", value: viewModel.systemService.powerMetrics.timeRemainingFormatted)
                    infoRow(label: "Thermals", value: viewModel.systemService.powerMetrics.thermalState)
                    infoRow(label: "Low Power Mode", value: viewModel.systemService.powerMetrics.isLowPowerMode ? "Enabled" : "Off")
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
            }
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.white)
        }
    }
}

// MARK: - Reusable Header with Back Button
public struct DetailHeaderView: View {
    public let title: String
    public let onBack: () -> Void
    
    public var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                    Text("System").font(.system(size: 11.5, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .cornerRadius(6)
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            Text("▸").foregroundColor(.secondary.opacity(0.6))
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white)
            
            Spacer()
            
            GlowingBadge(text: "Live", dotColor: .green)
        }
        .padding(.horizontal, 2)
    }
}
