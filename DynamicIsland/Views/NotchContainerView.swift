import SwiftUI

public struct NotchContainerView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var settings: AppSettings = AppSettings.shared
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }
    
    private var bottomRadius: CGFloat {
        switch viewModel.state {
        case .expanded:
            return CGFloat(settings.notchCornerRadius)
        case .call:
            return CGFloat(max(18, settings.notchCornerRadius - 2))
        case .hud, .compact:
            return CGFloat(max(14, settings.notchCornerRadius - 8))
        }
    }
    
    private var topRadius: CGFloat {
        settings.floatingIslandMode ? bottomRadius : 0
    }
    
    private var containerBackground: Color {
        switch settings.glassMaterial {
        case .trueBlack:
            return Color.black
        case .frostedDark:
            return Color(red: 0.06, green: 0.065, blue: 0.08).opacity(0.95)
        case .neonCyber:
            return Color(red: 0.04, green: 0.045, blue: 0.07)
        case .ultraThin:
            return Color.black.opacity(0.85)
        }
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Background: OLED true black anchored to top bezel with smooth continuous curved bottom corners
            UnevenRoundedRectangle(
                topLeadingRadius: topRadius,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: topRadius,
                style: .continuous
            )
            .fill(containerBackground)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: topRadius,
                    bottomLeadingRadius: bottomRadius,
                    bottomTrailingRadius: bottomRadius,
                    topTrailingRadius: topRadius,
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
                        .transition(
                            .asymmetric(
                                insertion: .opacity
                                    .combined(with: .scale(scale: 0.94, anchor: .top))
                                    .combined(with: .offset(y: -6)),
                                removal: .opacity
                                    .combined(with: .scale(scale: 0.96, anchor: .top))
                                    .combined(with: .offset(y: -4))
                            )
                        )
                } else if viewModel.state == .call, let call = viewModel.callService.currentCall {
                    CallIslandBannerView(viewModel: viewModel, call: call)
                        .transition(
                            .asymmetric(
                                insertion: .opacity
                                    .combined(with: .scale(scale: 0.94, anchor: .top))
                                    .combined(with: .offset(y: -4)),
                                removal: .opacity
                                    .combined(with: .scale(scale: 0.96, anchor: .top))
                            )
                        )
                } else if viewModel.state == .hud, let alert = viewModel.currentHUDAlert {
                    IslandHUDView(viewModel: viewModel, alert: alert)
                        .transition(
                            .asymmetric(
                                insertion: .opacity
                                    .combined(with: .scale(scale: 0.94, anchor: .top))
                                    .combined(with: .offset(y: -4)),
                                removal: .opacity
                                    .combined(with: .scale(scale: 0.96, anchor: .top))
                            )
                        )
                } else {
                    CompactIslandView(viewModel: viewModel)
                        .transition(
                            .asymmetric(
                                insertion: .opacity
                                    .combined(with: .scale(scale: 0.95, anchor: .top)),
                                removal: .opacity
                                    .combined(with: .scale(scale: 0.90, anchor: .top))
                            )
                        )
                }
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: topRadius,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: topRadius,
                style: .continuous
            )
        )
        .animation(NotchViewModel.spring(for: viewModel.state), value: viewModel.state)
        .animation(.spring(response: 0.28, dampingFraction: 0.76), value: viewModel.isHovering)
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
            case .fileTransfer(_, _, let isAirDrop, _, _, _, _):
                return LinearGradient(
                    colors: isAirDrop ? [Color.cyan.opacity(0.7), Color.blue.opacity(0.6)] : [Color.blue.opacity(0.7), Color.purple.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .focus(let isActive, _, _):
                return LinearGradient(
                    colors: isActive ? [Color.indigo.opacity(0.7), Color.purple.opacity(0.6)] : [Color.white.opacity(0.2), Color.purple.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .agentError:
                return LinearGradient(
                    colors: [Color.red.opacity(0.6), Color.orange.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        
        if viewModel.isHovering && viewModel.state == .compact {
            let accent = settings.accentColor.color
            return LinearGradient(
                colors: settings.enableNeonGlow
                    ? [accent.opacity(0.55 * settings.glowIntensity), Color.purple.opacity(0.4), accent.opacity(0.55 * settings.glowIntensity)]
                    : [Color.white.opacity(0.2), Color.white.opacity(0.12)],
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
            case .agentError:
                return Color.red.opacity(0.5)
            case .caffeine(let isActive, _):
                return isActive ? Color.orange.opacity(0.5) : Color.clear
            case .magSafe:
                return Color.green.opacity(0.5)
            case .fileTransfer(_, _, let isAirDrop, _, _, _, _):
                return isAirDrop ? Color.cyan.opacity(0.5) : Color.blue.opacity(0.5)
            case .focus(let isActive, _, _):
                return isActive ? Color.purple.opacity(0.5) : Color.clear
            }
        }
        if viewModel.isHovering && viewModel.state == .compact {
            return settings.enableNeonGlow ? settings.accentColor.color.opacity(0.4 * settings.glowIntensity) : Color.white.opacity(0.15)
        }
        return Color.black.opacity(0.6)
    }
}
