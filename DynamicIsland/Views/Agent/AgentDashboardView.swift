import SwiftUI
import AppKit

public struct AgentDashboardView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var agentService: AgentCompanionService
    @ObservedObject private var settings: AppSettings = AppSettings.shared
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.agentService = viewModel.agentService
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - Header: Title + Status + Settings Shortcut
            headerRow
                .padding(.horizontal, 2)
            
            // MARK: - Multi-Agent Quota Grid (All selected companions simultaneously without filtering)
            let selectedAgents = settings.selectedAgentsList
            
            HStack(spacing: 8) {
                ForEach(selectedAgents) { agent in
                    agentQuotaCard(for: agent, count: selectedAgents.count)
                }
            }
            .frame(height: 146)
        }
    }
    
    // MARK: - Header Component
    private var headerRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)
                
                Text("AI Code Agents")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Live companion daemon status pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(agentService.isServerRunning ? Color.green : Color.orange)
                        .frame(width: 5, height: 5)
                        .shadow(color: (agentService.isServerRunning ? Color.green : Color.orange).opacity(0.8), radius: 2)
                    Text(agentService.isServerRunning ? "Listening :\(settings.agentPort)" : "Connecting")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Customize button: opens Settings directly to AI Code Agents tab and closes notch
            Button {
                viewModel.setExpanded(false)
                SettingsWindowController.shared.showWindow(tab: .aiAgents)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 8.5))
                    Text("Customize")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Choose which AI companions are displayed in Settings")
        }
    }
    
    // MARK: - Individual Agent Quota Card (5-Hour & 7-Day Quotas)
    private func agentQuotaCard(for agent: CodeAgentType, count: Int) -> some View {
        let metrics = agentService.metrics(for: agent)
        let status = agentService.status(for: agent)
        let isUsageMode = (settings.quotaDisplayMode == .used)
        
        let fiveHourRawRemaining = metrics.fiveHourRemainingPercent
        let weeklyRawRemaining = metrics.weeklyRemainingPercent
        
        let fiveHourDisplayPct = isUsageMode ? max(0, min(100, 100 - fiveHourRawRemaining)) : fiveHourRawRemaining
        let weeklyDisplayPct = isUsageMode ? max(0, min(100, 100 - weeklyRawRemaining)) : weeklyRawRemaining
        let limitSuffix = isUsageMode ? "used" : "left"
        
        let hasPendingApproval = (agentService.activePermissionRequest?.agent == agent)
        
        let fiveHourColor: Color = {
            if isUsageMode {
                if fiveHourDisplayPct > 80 { return Color.red }
                if fiveHourDisplayPct > 50 { return Color.orange }
                return agent.accentColor
            } else {
                if fiveHourDisplayPct > 50 { return agent.accentColor }
                if fiveHourDisplayPct > 20 { return Color.orange }
                return Color.red
            }
        }()
        
        let weeklyColor: Color = {
            if isUsageMode {
                if weeklyDisplayPct > 80 { return Color.red }
                if weeklyDisplayPct > 50 { return Color.orange }
                return Color(red: 0.75, green: 0.55, blue: 1.0)
            } else {
                if weeklyDisplayPct > 50 { return Color(red: 0.75, green: 0.55, blue: 1.0) }
                if weeklyDisplayPct > 20 { return Color.orange }
                return Color.red
            }
        }()
        
        return VStack(alignment: .leading, spacing: 5) {
            // Card Header: Icon + Name + Status + Quick Focus
            HStack(spacing: 4) {
                Image(systemName: agent.iconName)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(agent.accentColor)
                
                Text(agentShortName(agent))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer(minLength: 2)
                
                // Status Pill
                HStack(spacing: 3) {
                    Circle()
                        .fill(status.isBusy ? Color.orange : Color.green)
                        .frame(width: 4, height: 4)
                        .shadow(color: (status.isBusy ? Color.orange : Color.green).opacity(0.8), radius: 1.5)
                    Text(status.isBusy ? "Active" : "Ready")
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .foregroundColor(status.isBusy ? .orange : .green)
                }
                .padding(.horizontal, 4.5)
                .padding(.vertical, 1.5)
                .background((status.isBusy ? Color.orange : Color.green).opacity(0.12))
                .clipShape(Capsule())
                
                // Quick Focus IDE / App Button
                Button {
                    agentService.focusAgentApp(agent: agent)
                } label: {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(2.5)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Focus \(agent.rawValue)")
            }
            
            // Pending Approval Banner if needed
            if hasPendingApproval, let req = agentService.activePermissionRequest {
                HStack(spacing: 4) {
                    Text("Approve?")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.yellow)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Yes") {
                        agentService.approveRequest(id: req.id)
                    }
                    .font(.system(size: 7.5, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    
                    Button("No") {
                        agentService.denyRequest(id: req.id)
                    }
                    .font(.system(size: 7.5, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }
                .padding(3)
                .background(Color.black.opacity(0.4))
                .cornerRadius(4)
            }
            
            // MARK: - 1. 5-Hour Rolling Limit Quota (Tap to toggle Left vs Usage)
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    settings.quotaDisplayMode = (settings.quotaDisplayMode == .remaining ? .used : .remaining)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2.5) {
                    HStack {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 7.5))
                                .foregroundColor(fiveHourColor)
                            Text(isUsageMode ? "5h Usage" : "5h Left")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                        Text(metrics.fiveHourResetCountdown)
                            .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    
                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [fiveHourColor, fiveHourColor.opacity(0.75)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: max(4, geo.size.width * CGFloat(min(1.0, Double(fiveHourDisplayPct) / 100.0))))
                        }
                    }
                    .frame(height: 4.5)
                    
                    HStack {
                        Text("\(fiveHourDisplayPct)% \(limitSuffix)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text("5h rolling")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(5)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.035)))
            }
            .buttonStyle(.plain)
            .help("Click to toggle between Left Limit and Usage Limit")
            
            // MARK: - 2. 7-Day Weekly Limit Quota (Tap to toggle Left vs Usage)
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    settings.quotaDisplayMode = (settings.quotaDisplayMode == .remaining ? .used : .remaining)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2.5) {
                    HStack {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 7.5))
                                .foregroundColor(weeklyColor)
                            Text(isUsageMode ? "7-Day Usage" : "7-Day Left")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                        Text(metrics.weeklyResetCountdown)
                            .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(red: 0.75, green: 0.55, blue: 1.0))
                    }
                    
                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [weeklyColor, weeklyColor.opacity(0.75)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: max(4, geo.size.width * CGFloat(min(1.0, Double(weeklyDisplayPct) / 100.0))))
                        }
                    }
                    .frame(height: 4.5)
                    
                    HStack {
                        Text("\(weeklyDisplayPct)% \(limitSuffix)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text("Weekly reset")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(5)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.035)))
            }
            .buttonStyle(.plain)
            .help("Click to toggle between Left Limit and Usage Limit")
            
            Spacer(minLength: 0)
            
            // MARK: - Footer: Plan Name & Turns Today
            HStack {
                Text(metrics.planName)
                    .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(metrics.requestsToday) turns")
                    .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
        .padding(7.5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
    
    private func agentShortName(_ agent: CodeAgentType) -> String {
        switch agent {
        case .antigravity: return "Antigravity"
        case .claude: return "Claude Code"
        case .cursor: return "Cursor AI"
        case .copilot: return "Copilot"
        }
    }
}
