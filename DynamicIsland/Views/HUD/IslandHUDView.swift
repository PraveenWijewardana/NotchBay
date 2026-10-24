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
            .frame(width: 115, alignment: .leading)
            .padding(.leading, 12)
            
            Spacer(minLength: max(180, viewModel.physicalNotchWidth + 8)) // Hardware camera notch cutout clearance
            
            // Right Ear: Progress Level, Subtitle, or Interactive Action Buttons (Approve / Deny)
            Group {
                switch alert.type {
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
            .frame(width: 115, alignment: .trailing)
            .padding(.trailing, 12)
        }
        .frame(height: 46)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                viewModel.state = .expanded
                if case .agentPermission = alert.type {
                    viewModel.selectedPageIndex = 5 // Jump directly to Agent tab!
                }
            }
        }
    }
    
    // MARK: - Dynamic Icon
    @ViewBuilder
    private var iconView: some View {
        switch alert.type {
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
            
        case .buildStatus(_, _, _, let isSuccess, _):
            ZStack {
                Circle()
                    .fill(isSuccess ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 22, height: 22)
                Image(systemName: alert.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSuccess ? .green : .red)
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
        }
    }
    
    // MARK: - Colors & Gradients
    private var barGradient: LinearGradient {
        switch alert.type {
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
            
        case .buildStatus(_, _, _, let isSuccess, _):
            return isSuccess 
                ? LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                
        case .caffeine(let isActive, _):
            return isActive
                ? LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [.white.opacity(0.4), .gray], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var subtitleColor: Color {
        switch alert.type {
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
        case .buildStatus(_, _, _, let isSuccess, _):
            return isSuccess ? .green : .red
        case .caffeine(let isActive, _):
            return isActive ? .orange : .white
        }
    }
}
