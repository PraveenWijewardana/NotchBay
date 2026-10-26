import SwiftUI

public struct CompactIslandView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var systemService: SystemMonitorService
    @ObservedObject private var networkService: NetworkMonitorService
    @ObservedObject private var mediaService: MediaControllerService
    @ObservedObject private var settings: AppSettings = AppSettings.shared
    
    // Symmetrical ear content width with user settings
    private var earWidth: CGFloat {
        let extraCaffeine: CGFloat = (viewModel.caffeineService.isActive && settings.showCaffeineInCompact) ? 12.0 : 0.0
        return CGFloat(settings.compactEarWidth) + extraCaffeine
    }
    
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
    
    // MARK: - Left Ear Content (Call, Music Artwork/Equalizer, or CPU Load)
    @ViewBuilder
    private var leftEarView: some View {
        HStack(spacing: 4) {
            if let call = viewModel.callService.currentCall {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.state = .call
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: call.category.appType.iconName)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(call.category.appType.accentColor)
                            .shadow(color: call.category.appType.accentColor.opacity(0.8), radius: 2)
                        
                        HStack(alignment: .bottom, spacing: 1.5) {
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(call.category.appType.accentColor)
                                    .frame(width: 2.0, height: max(3.0, viewModel.callService.callAudioFrequencies[i] * 11))
                            }
                        }
                        .frame(height: 11)
                    }
                }
                .buttonStyle(.plain)
            } else if mediaService.currentTrack.isPlaying {
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
                if settings.showCaffeineInCompact && viewModel.caffeineService.isActive {
                    HStack(spacing: 2.5) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.orange)
                            .shadow(color: .orange.opacity(0.8), radius: 2)
                        
                        Text(viewModel.caffeineService.formattedRemainingTime)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.orange)
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
                
                switch settings.leftEarContent {
                case .cpuLoad, .musicVisualizer:
                    Image(systemName: "cpu")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(cpuColor)
                        .shadow(color: cpuColor.opacity(viewModel.isHovering ? 0.7 : 0.25), radius: 2.5)
                    
                    Text(String(format: "%.0f%%", systemService.cpuMetrics.usagePercentage))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                case .memoryUsage:
                    Image(systemName: "memorychip")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(settings.accentColor.color)
                        .shadow(color: settings.accentColor.color.opacity(0.5), radius: 2.5)
                    
                    Text(String(format: "%.0f%%", systemService.memoryMetrics.usageFraction * 100))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                case .clock:
                    Image(systemName: "clock")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(settings.accentColor.color)
                    
                    Text(viewModel.currentDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                case .weatherTemp:
                    Image(systemName: viewModel.weatherService.weather.condition.iconName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    Text("\(viewModel.weatherService.weather.temperature)°")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                case .batteryPercent:
                    Image(systemName: systemService.powerMetrics.isCharging ? "battery.100.bolt" : "battery.75")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(systemService.powerMetrics.isCharging ? .green : (systemService.powerMetrics.batteryLevel < 20 ? .red : .white))
                    
                    Text("\(systemService.powerMetrics.batteryLevel)%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                case .hidden:
                    EmptyView()
                }
            }
        }
        .scaleEffect(viewModel.isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.isHovering)
    }
    
    // MARK: - Right Ear Content (Call, Agent Status, Timer, or Network Speed)
    @ViewBuilder
    private var rightEarView: some View {
        HStack(spacing: 3.5) {
            if let call = viewModel.callService.currentCall {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.state = .call
                    }
                } label: {
                    HStack(spacing: 3) {
                        if call.status == .incoming {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(call.category.appType.accentColor)
                            Text("Call")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(call.category.appType.accentColor)
                        } else {
                            Text(call.durationFormatted)
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 7.5, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            } else if viewModel.agentService.status == .awaitingPermission {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        viewModel.selectedPageIndex = 5
                        viewModel.state = .expanded
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.8), radius: 3)
                        Text("Approve")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            } else if viewModel.agentService.status == .executing || viewModel.agentService.status == .coding {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        viewModel.selectedPageIndex = 5
                        viewModel.state = .expanded
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: viewModel.agentService.selectedAgent.iconName)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(viewModel.agentService.selectedAgent.accentColor)
                            .shadow(color: viewModel.agentService.selectedAgent.accentColor.opacity(0.6), radius: 2)
                        Text("Working")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(viewModel.agentService.selectedAgent.accentColor)
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            } else if viewModel.agentService.status == .thinking {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        viewModel.selectedPageIndex = 5
                        viewModel.state = .expanded
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "brain")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.cyan)
                            .shadow(color: .cyan.opacity(0.6), radius: 2)
                        Text("Thinking")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            } else if viewModel.agentService.status == .completed {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        viewModel.selectedPageIndex = 5
                        viewModel.state = .expanded
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                            .shadow(color: .green.opacity(0.6), radius: 2)
                        Text("Done")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            } else if viewModel.timerConfig.isRunning {
                Image(systemName: "timer")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(viewModel.isHovering ? 0.8 : 0.3), radius: 2.5)
                Text(viewModel.timerConfig.formattedTime)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.yellow)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                switch settings.rightEarContent {
                case .networkSpeed:
                    networkSpeedView
                case .downloadOnly:
                    downloadOnlyView
                case .uploadOnly:
                    uploadOnlyView
                case .activeAgents:
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(settings.accentColor.color)
                        Text("AI Idle")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                    }
                case .timers:
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("00:00")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.6))
                    }
                case .batteryPercent:
                    HStack(spacing: 3) {
                        Image(systemName: systemService.powerMetrics.isCharging ? "battery.100.bolt" : "battery.75")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(systemService.powerMetrics.isCharging ? .green : .white)
                        Text("\(systemService.powerMetrics.batteryLevel)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                case .hidden:
                    EmptyView()
                }
            }
        }
        .scaleEffect(viewModel.isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.isHovering)
    }
    
    @ViewBuilder
    private var downloadOnlyView: some View {
        let down = viewModel.networkService.metrics.currentDownSpeed
        let (val, unit) = formatSpeedParts(down)
        HStack(spacing: 3) {
            Image(systemName: "arrow.down")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(down >= 1024 ? Color.cyan : Color.white.opacity(0.35))
            HStack(alignment: .firstTextBaseline, spacing: 1.5) {
                Text(val)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(down >= 1024 ? .white : Color.white.opacity(0.45))
                Text(unit)
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .foregroundColor(down >= 1024 ? Color.cyan.opacity(0.9) : Color.white.opacity(0.35))
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    @ViewBuilder
    private var uploadOnlyView: some View {
        let up = viewModel.networkService.metrics.currentUpSpeed
        let (val, unit) = formatSpeedParts(up)
        HStack(spacing: 3) {
            Image(systemName: "arrow.up")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(up >= 1024 ? Color.green : Color.white.opacity(0.35))
            HStack(alignment: .firstTextBaseline, spacing: 1.5) {
                Text(val)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(up >= 1024 ? .white : Color.white.opacity(0.45))
                Text(unit)
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .foregroundColor(up >= 1024 ? Color.green.opacity(0.9) : Color.white.opacity(0.35))
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    // MARK: - Enhanced Network Speed View
    @ViewBuilder
    private var networkSpeedView: some View {
        let down = viewModel.networkService.metrics.currentDownSpeed
        let up = viewModel.networkService.metrics.currentUpSpeed
        let isUpload = up > down && up >= 1024
        let speed = isUpload ? up : down
        let isActive = speed >= 1024
        let (val, unit) = formatSpeedParts(speed)
        
        let icon = isUpload ? "arrow.up" : "arrow.down"
        let iconColor: Color = isUpload
            ? Color(red: 0.3, green: 0.95, blue: 0.55) // Mint Emerald
            : Color(red: 0.15, green: 0.85, blue: 1.0) // Electric Cyan
        
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(isActive ? iconColor : Color.white.opacity(0.35))
                .shadow(color: isActive ? iconColor.opacity(0.6) : .clear, radius: 2.5)
            
            HStack(alignment: .firstTextBaseline, spacing: 1.5) {
                Text(val)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(isActive ? .white : Color.white.opacity(0.45))
                
                Text(unit)
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .foregroundColor(isActive ? iconColor.opacity(0.9) : Color.white.opacity(0.35))
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    private func formatSpeedParts(_ bytesPerSec: Double) -> (String, String) {
        let absBytes = abs(bytesPerSec)
        if absBytes >= 1_073_741_824 { // 1 GB/s
            return (String(format: "%.1f", bytesPerSec / 1_073_741_824.0), "GB/s")
        } else if absBytes >= 1_048_576 { // 1 MB/s
            if absBytes >= 100 * 1_048_576 {
                return (String(format: "%.0f", bytesPerSec / 1_048_576.0), "MB/s")
            } else {
                return (String(format: "%.1f", bytesPerSec / 1_048_576.0), "MB/s")
            }
        } else if absBytes >= 1024 { // 1 KB/s
            return (String(format: "%.0f", bytesPerSec / 1024.0), "KB/s")
        } else {
            return ("0", "KB/s")
        }
    }
}
