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
            // MARK: - Header: Title + Agent Selector + Simulation Menu
            headerRow
                .padding(.horizontal, 2)
            
            // MARK: - 3-Column Layout: Live Status & Actions | AI Usage Gauge | Activity Stream
            HStack(spacing: 8) {
                // Column 1: Live Status & Wait / Request Permission / Finish
                liveStatusCard
                    .frame(width: 156)
                
                // Column 2: AI Usage Gauge (CodeNotch Implementation)
                aiUsageGaugeCard
                    .frame(width: 144)
                
                // Column 3: Live Activity Stream
                activityStreamCard
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 142)
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
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Live companion daemon pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(agentService.isServerRunning ? Color.green : Color.orange)
                        .frame(width: 5, height: 5)
                        .shadow(color: .green.opacity(0.8), radius: 2)
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
            
            // Demo & Simulation Menu
            Menu {
                Section("Simulate State") {
                    Button("Simulate: Wait / Thinking") {
                        agentService.setWorking(agent: agentService.selectedAgent, status: .thinking, message: "Analyzing project files...")
                    }
                    Button("Simulate: Wait / Running Tool") {
                        agentService.setWorking(agent: agentService.selectedAgent, status: .executing, message: "Running: git diff --cached")
                    }
                    Button("Simulate: Request Permission") {
                        agentService.requestPermission(
                            agent: agentService.selectedAgent,
                            actionOrTool: "Run: git push origin main",
                            detail: "Requires network access outside sandbox"
                        )
                    }
                    Button("Simulate: Task Finished") {
                        agentService.completeTask(agent: agentService.selectedAgent, message: "All files updated and verified!")
                    }
                }
                Divider()
                Button("Reset to Idle") {
                    agentService.updateSilentStatus(agent: agentService.selectedAgent, status: .idle, message: "Connected & Ready")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 18, height: 18)
            }
            .menuStyle(.borderlessButton)
            .help("Simulate agent states")
        }
    }
    
    // MARK: - Column 1: Live Status & Interactive Action Card
    private var liveStatusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Agent Name + Status Badge
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: agentService.selectedAgent.iconName)
                        .foregroundColor(agentService.selectedAgent.accentColor)
                        .font(.system(size: 10))
                    Text(agentService.selectedAgent.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 3.5) {
                    Image(systemName: agentService.status.icon)
                        .font(.system(size: 8, weight: .bold))
                    Text(agentService.status.rawValue)
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(agentService.status.color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(agentService.status.color.opacity(0.18))
                .clipShape(Capsule())
            }
            
            // Content based on lifecycle state
            if let req = agentService.activePermissionRequest {
                // 1. REQUEST PERMISSION STATE
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 9))
                        Text("PERMISSION REQUIRED")
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
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                agentService.denyRequest(id: req.id)
                            }
                        } label: {
                            Text("Deny")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if agentService.status.isBusy {
                // 2. WAIT / BUSY STATE (Thinking or Running Tool)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(agentService.selectedAgent.accentColor.opacity(0.3), lineWidth: 2)
                                .frame(width: 18, height: 18)
                            Circle()
                                .trim(from: 0.1, to: 0.75)
                                .stroke(agentService.selectedAgent.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 18, height: 18)
                                .rotationEffect(.degrees(Double((agentService.turnElapsedSeconds % 60) * 60)))
                                .animation(.easeInOut(duration: 0.8), value: agentService.turnElapsedSeconds)
                        }
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text(agentService.status == .thinking ? "Thinking..." : "Running Tool...")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("\(agentService.formattedTurnElapsed) elapsed")
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 2)
                    
                    Text(agentService.currentMessage)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(agentService.status.color)
                            .frame(width: 4.5, height: 4.5)
                        Text("Active Turn In Progress")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            } else if agentService.status == .completed {
                // 3. FINISH STATE
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                        Text("Turn Finished")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    
                    Text(agentService.currentMessage)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4.5, height: 4.5)
                        Text("Ready for next prompt")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            } else {
                // 4. IDLE STATE
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Agent Idle")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(agentService.currentMessage)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 4.5, height: 4.5)
                        Text("Auto-detects IDE & CLI")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
    
    // MARK: - Column 2: AI Usage Gauge Card (CodeNotch Implementation)
    private var aiUsageGaugeCard: some View {
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
                        .font(.system(size: 9.5))
                        .foregroundColor(isLive ? ringColor : .cyan)
                    Text("AI USAGE")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isLive {
                    Text(metrics.primaryResetCountdown)
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
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
                        .stroke(Color.white.opacity(0.10), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(max(0.04, min(1.0, isLive ? (Double(remainingPercent) / 100.0) : metrics.gaugeFraction))))
                        .stroke(
                            isLive
                                ? LinearGradient(colors: [ringColor, ringColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.cyan, Color(red: 0.7, green: 0.4, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                    
                    VStack(spacing: 0) {
                        if isLive {
                            Text("\(remainingPercent)%")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
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
                        } else {
                            Text("\(metrics.activeSessionsCount) sessions")
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
                        
                        Text("\(metrics.activeSessionsCount) active sessions")
                            .font(.system(size: 7.5, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
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
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
    
    // MARK: - Column 3: Activity Stream Card
    private var activityStreamCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet.rectangle.portrait.fill")
                        .font(.system(size: 9.5))
                        .foregroundColor(.cyan)
                    Text("ACTIVITY STREAM")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(agentService.activityLog.count) events")
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(agentService.activityLog) { item in
                        HStack(alignment: .top, spacing: 5) {
                            Circle()
                                .fill(item.status.color)
                                .frame(width: 4.5, height: 4.5)
                                .padding(.top, 3.5)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                HStack {
                                    Text(item.agent.rawValue)
                                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(item.formattedTime)
                                        .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(item.message)
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(2)
                            }
                        }
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.04)))
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.10)))
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
