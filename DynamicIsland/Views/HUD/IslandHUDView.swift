import SwiftUI
import AppKit

public struct IslandHUDView: View {
    @ObservedObject public var viewModel: NotchViewModel
    public let alert: HUDAlert
    
    public init(viewModel: NotchViewModel, alert: HUDAlert) {
        self.viewModel = viewModel
        self.alert = alert
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left Ear: Icon + Title
            HStack(spacing: 7) {
                iconView
                
                Text(alert.title)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(width: 120, alignment: .leading)
            .padding(.leading, 12)
            
            Spacer(minLength: max(180, viewModel.physicalNotchWidth + 8)) // Hardware camera notch cutout clearance
            
            // Right Ear: Progress Level, Subtitle, or Interactive Action Buttons (Approve / Deny / Transfer)
            Group {
                switch alert.type {
                case .magSafe(let level, _, _):
                    // Apple MagSafe Neon Charging Ring
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.18), lineWidth: 2.2)
                                .frame(width: 20, height: 20)
                            Circle()
                                .trim(from: 0, to: CGFloat(level) / 100.0)
                                .stroke(Color.green, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 20, height: 20)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.green)
                        }
                        Text("\(level)%")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    
                case .fileTransfer(_, let progress, let isAirDrop, let isCompleted, let currentBytes, let totalBytes, _):
                    HStack(spacing: 6) {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.green)
                            Text(isAirDrop ? "Received" : "Complete")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        } else if totalBytes > 0 {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 2)
                                    .frame(width: 18, height: 18)
                                Circle()
                                    .trim(from: 0, to: CGFloat(max(0.02, min(1.0, progress))))
                                    .stroke(isAirDrop ? Color.cyan : Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 18, height: 18)
                            }
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(isAirDrop ? .cyan : .blue)
                        } else {
                            // Real downloaded size + animated progress ring when total size is indeterminate
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 2)
                                    .frame(width: 18, height: 18)
                                Circle()
                                    .trim(from: 0.1, to: 0.75)
                                    .stroke(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .rotationEffect(.degrees(viewModel.isHovering ? 360 : 180))
                                    .frame(width: 18, height: 18)
                            }
                            Text(ByteCountFormatter.string(fromByteCount: currentBytes, countStyle: .file))
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }
                    
                case .agentPermission(_, let reqId, _):
                    // Interactive Action Buttons right inside the Notch HUD
                    HStack(spacing: 6) {
                        Button {
                            viewModel.agentService.approveRequest(id: reqId)
                            viewModel.state = .compact
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9.5, weight: .bold))
                                Text("Approve")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color.green)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            viewModel.agentService.denyRequest(id: reqId)
                            viewModel.state = .compact
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(4)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                case .agentFinished:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                        Text("Finished")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    
                case .focus(let isActive, _, _):
                    HStack(spacing: 5) {
                        Image(systemName: isActive ? "moon.fill" : "moon.stars.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isActive ? Color(red: 0.75, green: 0.55, blue: 1.0) : .white)
                        Text(isActive ? "Focus On" : "Focus Ended")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(isActive ? Color(red: 0.75, green: 0.55, blue: 1.0) : .white)
                    }
                    
                default:
                    HStack(spacing: 7) {
                        if let progress = alert.progress {
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: 50, height: 5)
                                
                                Capsule()
                                    .fill(barGradient)
                                    .frame(width: max(2, min(50, 50 * CGFloat(progress))), height: 5)
                            }
                        }
                        
                        Text(alert.subtitle)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(subtitleColor)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 120, alignment: .trailing)
            .padding(.trailing, 12)
        }
        .frame(height: 46)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                if case .agentPermission = alert.type {
                    viewModel.selectedPageIndex = 5 // Jump to Agent tab
                    viewModel.setExpanded(true)
                } else if case .fileTransfer = alert.type {
                    viewModel.selectedPageIndex = 4 // Jump to Shelf / Downloads tab
                    viewModel.setExpanded(true)
                } else {
                    viewModel.setExpanded(true)
                }
            }
        }
    }
    
    // MARK: - Dynamic Icon
    @ViewBuilder
    private var iconView: some View {
        switch alert.type {
        case .magSafe:
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.25))
                    .frame(width: 22, height: 22)
                Image(systemName: "bolt.ring.closed")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.green)
            }
            
        case .fileTransfer(_, _, let isAirDrop, let isCompleted, _, _, _):
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green.opacity(0.25) : (isAirDrop ? Color.cyan.opacity(0.25) : Color.blue.opacity(0.25)))
                    .frame(width: 22, height: 22)
                Image(systemName: isCompleted ? "checkmark" : (isAirDrop ? "airdrop" : "arrow.down.circle.fill"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isCompleted ? .green : (isAirDrop ? .cyan : .blue))
            }
            
        case .volume(_, let isMuted):
            ZStack {
                Circle()
                    .fill(isMuted ? Color.red.opacity(0.2) : Color.cyan.opacity(0.2))
                    .frame(width: 22, height: 22)
                Image(systemName: alert.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isMuted ? .red : .cyan)
            }
            
        case .battery(_, let isCharging, _):
            ZStack {
                Circle()
                    .fill(isCharging ? Color.green.opacity(0.2) : Color.yellow.opacity(0.2))
                    .frame(width: 22, height: 22)
                Image(systemName: alert.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isCharging ? .green : .yellow)
            }
            
        case .track:
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 22, height: 22)
                Image(systemName: alert.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.purple)
            }
            
        case .agentPermission(let agent, _, _):
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.25))
                    .frame(width: 22, height: 22)
                Image(systemName: agent.iconName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.yellow)
            }
            
        case .agentFinished(let agent, _):
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 22, height: 22)
                Image(systemName: agent.iconName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
            }
            
        case .caffeine(let isActive, _):
            ZStack {
                Circle()
                    .fill(isActive ? Color.orange.opacity(0.2) : Color.white.opacity(0.12))
                    .frame(width: 22, height: 22)
                Image(systemName: alert.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isActive ? .orange : .white)
            }
            
        case .focus(let isActive, _, _):
            ZStack {
                Circle()
                    .fill(isActive ? Color.purple.opacity(0.25) : Color.white.opacity(0.12))
                    .frame(width: 22, height: 22)
                Image(systemName: isActive ? "moon.fill" : "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isActive ? Color(red: 0.75, green: 0.55, blue: 1.0) : .green)
            }
        }
    }
    
    // MARK: - Colors & Gradients
    private var barGradient: LinearGradient {
        switch alert.type {
        case .magSafe:
            return LinearGradient(colors: [.green, Color(red: 0.2, green: 0.95, blue: 0.5)], startPoint: .leading, endPoint: .trailing)
            
        case .fileTransfer(_, _, let isAirDrop, _, _, _, _):
            return isAirDrop
                ? LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
            
        case .volume(_, let isMuted):
            if isMuted {
                return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
            }
            return LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
            
        case .battery(let level, let isCharging, _):
            if isCharging {
                return LinearGradient(colors: [.green, Color(red: 0.3, green: 0.9, blue: 0.5)], startPoint: .leading, endPoint: .trailing)
            } else if level <= 20 {
                return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
            }
            return LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
            
        case .track:
            return LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
            
        case .agentPermission:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
            
        case .agentFinished:
            return LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing)
            
        case .caffeine(let isActive, _):
            return isActive
                ? LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [.white.opacity(0.4), .gray], startPoint: .leading, endPoint: .trailing)
                
        case .focus(let isActive, _, _):
            return isActive
                ? LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [.white.opacity(0.4), .gray], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var subtitleColor: Color {
        switch alert.type {
        case .magSafe:
            return .green
        case .fileTransfer(_, _, let isAirDrop, let isCompleted, _, _, _):
            return isCompleted ? .green : (isAirDrop ? .cyan : .blue)
        case .volume(_, let isMuted):
            return isMuted ? .red : .white
        case .battery(let level, let isCharging, _):
            if isCharging { return .green }
            if level <= 20 { return .red }
            return .white
        case .track:
            return .secondary
        case .agentPermission:
            return .yellow
        case .agentFinished:
            return .green
        case .caffeine(let isActive, _):
            return isActive ? .orange : .white
        case .focus(let isActive, _, _):
            return isActive ? Color(red: 0.75, green: 0.55, blue: 1.0) : .secondary
        }
    }
}
