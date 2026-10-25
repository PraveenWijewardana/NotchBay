import SwiftUI

public struct NotchContainerView: View {
    @ObservedObject public var viewModel: NotchViewModel
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }
    
    private var bottomRadius: CGFloat {
        switch viewModel.state {
        case .expanded:
            return 26
        case .call:
            return 24
        case .hud:
            return 18
        case .compact:
            return 18
        }
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Background: OLED true black anchored to top bezel with smooth continuous curved bottom corners
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.black)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: bottomRadius,
                    bottomTrailingRadius: bottomRadius,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .strokeBorder(
                    borderGradient,
                    lineWidth: (viewModel.state == .hud || viewModel.state == .call || viewModel.isHovering) ? 1.5 : 1.0
                )
            )
            .shadow(
                color: shadowColor,
                radius: viewModel.state == .expanded ? 20 : (viewModel.state == .call ? 16 : (viewModel.state == .hud ? 12 : (viewModel.isHovering ? 8 : 4))),
                x: 0,
                y: viewModel.state == .expanded ? 8 : (viewModel.state == .call ? 6 : (viewModel.state == .hud ? 5 : 2))
            )
            
            // Content Switcher: Expanded Dashboard vs. Call Banner vs. Live HUD vs. Compact Pill
            Group {
                if viewModel.state == .expanded {
                    ExpandedIslandView(viewModel: viewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if viewModel.state == .call, let call = viewModel.callService.currentCall {
                    CallIslandBannerView(viewModel: viewModel, call: call)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else if viewModel.state == .hud, let alert = viewModel.currentHUDAlert {
                    IslandHUDView(viewModel: viewModel, alert: alert)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    CompactIslandView(viewModel: viewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: viewModel.state)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: viewModel.isHovering)
    }
    
    // MARK: - Dynamic Border & Glow
    private var borderGradient: LinearGradient {
        if viewModel.state == .call, let call = viewModel.callService.currentCall {
            let color = call.category.appType.accentColor
            return LinearGradient(
                colors: [color.opacity(0.7), color.opacity(0.35), color.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        
        if viewModel.state == .hud, let alert = viewModel.currentHUDAlert {
            switch alert.type {
            case .volume(_, let isMuted):
                return LinearGradient(
                    colors: isMuted ? [Color.red.opacity(0.4), Color.orange.opacity(0.3)] : [Color.cyan.opacity(0.5), Color.blue.opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .battery(_, let isCharging, _):
                return LinearGradient(
                    colors: isCharging ? [Color.green.opacity(0.5), Color.teal.opacity(0.4)] : [Color.yellow.opacity(0.4), Color.orange.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .track:
                return LinearGradient(
                    colors: [Color.purple.opacity(0.5), Color.pink.opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .agentPermission:
                return LinearGradient(
                    colors: [Color.orange.opacity(0.6), Color.yellow.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .agentFinished:
                return LinearGradient(
                    colors: [Color.green.opacity(0.6), Color.cyan.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .caffeine(let isActive, _):
                return LinearGradient(
                    colors: isActive ? [Color.orange.opacity(0.6), Color.yellow.opacity(0.5)] : [Color.white.opacity(0.2), Color.gray.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .magSafe:
                return LinearGradient(
                    colors: [Color.green.opacity(0.7), Color(red: 0.2, green: 0.95, blue: 0.5).opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .fileTransfer(_, _, let isAirDrop, _):
                return LinearGradient(
                    colors: isAirDrop ? [Color.cyan.opacity(0.7), Color.blue.opacity(0.6)] : [Color.blue.opacity(0.7), Color.purple.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        
        if viewModel.isHovering && viewModel.state == .compact {
            return LinearGradient(
                colors: [Color.cyan.opacity(0.4), Color.purple.opacity(0.4), Color.cyan.opacity(0.4)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        
        return LinearGradient(
            colors: [Color.white.opacity(0.08), Color.white.opacity(0.14)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var shadowColor: Color {
        if viewModel.state == .call, let call = viewModel.callService.currentCall {
            return call.category.appType.accentColor.opacity(0.4)
        }
        
        if viewModel.state == .hud, let alert = viewModel.currentHUDAlert {
            switch alert.type {
            case .volume(_, let isMuted):
                return isMuted ? Color.red.opacity(0.4) : Color.cyan.opacity(0.4)
            case .battery(_, let isCharging, _):
                return isCharging ? Color.green.opacity(0.4) : Color.yellow.opacity(0.35)
            case .track:
                return Color.purple.opacity(0.4)
            case .agentPermission:
                return Color.orange.opacity(0.5)
            case .agentFinished:
                return Color.green.opacity(0.5)
            case .caffeine(let isActive, _):
                return isActive ? Color.orange.opacity(0.5) : Color.clear
            case .magSafe:
                return Color.green.opacity(0.5)
            case .fileTransfer(_, _, let isAirDrop, _):
                return isAirDrop ? Color.cyan.opacity(0.5) : Color.blue.opacity(0.5)
            }
        }
        if viewModel.isHovering && viewModel.state == .compact {
            return Color.cyan.opacity(0.35)
        }
        return Color.black.opacity(0.6)
    }
}
