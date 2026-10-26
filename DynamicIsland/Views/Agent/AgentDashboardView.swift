import SwiftUI
import AppKit

public struct AgentDashboardView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var agentService: AgentCompanionService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.agentService = viewModel.agentService
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - Header: Title + Status + Agent Selector
            headerRow
                .padding(.horizontal, 2)
            
            // MARK: - Productive 2-Card Bento: Live Mission HUD & Live Quota Telemetry
            HStack(spacing: 8) {
                // Card 1: Active Mission, Real-time Task HUD & Approval Actions
                liveMissionCard
                    .frame(maxWidth: .infinity)
                
                // Card 2: AI Quota & Model Telemetry
                aiUsageTelemetryCard
                    .frame(width: 178)
            }
            .frame(height: 144)
        }
    }
    
    // MARK: - Header Component
    private var headerRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)
                
                Text("AI Agents")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Live companion daemon status pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(agentService.isServerRunning ? Color.green : Color.orange)
                        .frame(width: 5, height: 5)
                        .shadow(color: (agentService.isServerRunning ? Color.green : Color.orange).opacity(0.8), radius: 2)
                    Text(agentService.isServerRunning ? "Listening" : "Connecting")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Agent Selector Pills: Antigravity, Claude, Cursor, Copilot
            HStack(spacing: 4) {
                ForEach(CodeAgentType.allCases) { agent in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            agentService.selectedAgent = agent
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: agent.iconName)
                                .font(.system(size: 8))
                            Text(agentShortName(agent))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundColor(agentService.selectedAgent == agent ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            agentService.selectedAgent == agent
                                ? agent.accentColor.opacity(0.35)
                                : Color.white.opacity(0.06)
                        )
                        .overlay(
                            Capsule()
                                .stroke(agentService.selectedAgent == agent ? agent.accentColor : Color.clear, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Card 1: Live Agent Mission & Execution HUD
    private var liveMissionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top Bar: Agent Branding + Execution Pill + Turn Duration + Focus IDE
            HStack(alignment: .center) {
                HStack(spacing: 4.5) {
                    Image(systemName: agentService.selectedAgent.iconName)
                        .foregroundColor(agentService.selectedAgent.accentColor)
                        .font(.system(size: 10, weight: .bold))
                    Text(agentService.selectedAgent.rawValue.uppercased())
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                // Status Badge
                HStack(spacing: 3.5) {
                    Image(systemName: agentService.status.icon)
                        .font(.system(size: 7.5, weight: .bold))
                    Text(agentService.status.rawValue)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                }
                .foregroundColor(agentService.status.color)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(agentService.status.color.opacity(0.18))
                .clipShape(Capsule())
                
                if agentService.status.isBusy {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.system(size: 7.5))
                        Text(agentService.formattedDuration)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                // Bring IDE / Terminal forward
                Button {
                    agentService.focusActiveAgentApp()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 8))
                        Text("Focus IDE")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Bring active editor or terminal to front")
            }
            
            // Middle Content: Adaptive by state
            if let req = agentService.activePermissionRequest {
                // 1. GENUINE PERMISSION / QUESTION STATE
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 9))
                        Text("ACTION APPROVAL REQUIRED")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                    }
                    
                    Text(req.actionOrTool)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .padding(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.45))
                        .cornerRadius(5)
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 6) {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                agentService.approveRequest(id: req.id)
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Approve")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                agentService.denyRequest(id: req.id)
                            }
                        } label: {
                            Text("Deny")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if agentService.status.isBusy {
                // 2. ACTIVE WORKING / EXECUTING TOOL STATE
                VStack(alignment: .leading, spacing: 3.5) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                            .shadow(color: Color.orange.opacity(0.8), radius: 2)
                        Text("CURRENT TASK")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    
                    Text(agentService.currentMessage)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.35)))
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 4) {
                        Text("Live Turn Active • \(agentService.formattedDuration)")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Spacer()
                        
                        Text("Auto-Streaming")
                            .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            } else if agentService.status == .completed {
                // 3. TASK COMPLETED STATE
                VStack(alignment: .leading, spacing: 3.5) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                        Text("TASK COMPLETED")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    
                    Text(agentService.currentMessage)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4.5, height: 4.5)
                        Text("Ready for next instruction")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
            } else {
                // 4. IDLE STATE
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(agentService.selectedAgent.accentColor)
                        Text("Agent Standby")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Text(agentService.currentMessage)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(2)
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 4, height: 4)
                        Text("Listening to local daemon on port 19842 & IDE transcripts")
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
    
    // MARK: - Card 2: AI Quota & Model Telemetry
    private var aiUsageTelemetryCard: some View {
        let metrics = agentService.usageMetrics
        let isLive = metrics.isLiveQuotaConnected
        let remainingPercent = metrics.primaryRemainingPercent
        
        let ringColor: Color = {
            if remainingPercent > 50 {
                return Color.cyan
            } else if remainingPercent > 20 {
                return Color.orange
            } else {
                return Color.red
            }
        }()
        
        return VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.needle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(isLive ? ringColor : .cyan)
                    Text("AI USAGE")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isLive {
                    Text(metrics.primaryResetCountdown)
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                } else {
                    Text(metrics.formattedLastActive)
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            
            // Circular Progress Gauge Ring
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 4.5)
                        .frame(width: 46, height: 46)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(max(0.04, min(1.0, isLive ? (Double(remainingPercent) / 100.0) : metrics.gaugeFraction))))
                        .stroke(
                            isLive
                                ? LinearGradient(colors: [ringColor, ringColor.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.cyan, Color(red: 0.7, green: 0.4, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 46, height: 46)
                    
                    VStack(spacing: 0) {
                        if isLive {
                            Text("\(remainingPercent)%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text("left")
                                .font(.system(size: 7, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(metrics.requestsToday)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text("today")
                                .font(.system(size: 7, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    if isLive {
                        Text("5-Hour Quota")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(metrics.requestsToday) turns today")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundColor(.cyan)
                            .lineLimit(1)
                        
                        if let weekly = metrics.weeklyRemainingFraction {
                            Text("Weekly: \(Int(round(weekly * 100)))% left")
                                .font(.system(size: 7.5, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Requests Today")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(metrics.requestsToday) model turns")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundColor(.cyan)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Sub-metrics / Plan Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Plan")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(metrics.planName)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                
                HStack {
                    Text(isLive ? "Weekly Reset" : "Total Trajectories")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    if isLive, let weeklyBucket = metrics.quotaBuckets.first(where: { $0.id.contains("weekly") }) {
                        Text(weeklyBucket.formattedResetCountdown)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                    } else {
                        Text("\(metrics.totalRequests)")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
            .padding(4.5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
    
    private func agentShortName(_ agent: CodeAgentType) -> String {
        switch agent {
        case .antigravity: return "Anti"
        case .claude: return "Claude"
        case .copilot: return "Copilot"
        case .cursor: return "Cursor"
        }
    }
}
