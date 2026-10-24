import SwiftUI
import AppKit

public struct AgentDashboardView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var agentService: AgentCompanionService
    @ObservedObject private var githubService: GitHubActionsService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.agentService = viewModel.agentService
        self.githubService = viewModel.githubActionsService
    }
    
    public var body: some View {
        VStack(spacing: 9) {
            // MARK: - Header: Developer Segmented Switcher + Sub-controls
            HStack(alignment: .center) {
                // Segmented Selector: [Agents] [GitHub CI/CD]
                HStack(spacing: 3) {
                    ForEach(NotchViewModel.DeveloperDashboardTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                viewModel.selectedDeveloperTab = tab
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: tab == .agents ? "sparkles" : "arrow.triangle.branch")
                                    .font(.system(size: 10, weight: .bold))
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                
                                if tab == .gitHub, githubService.activeRun != nil {
                                    Circle()
                                        .fill(Color.yellow)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .foregroundColor(viewModel.selectedDeveloperTab == tab ? .white : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(
                                viewModel.selectedDeveloperTab == tab
                                    ? (tab == .agents ? Color.cyan.opacity(0.3) : Color.purple.opacity(0.3))
                                    : Color.white.opacity(0.06)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        viewModel.selectedDeveloperTab == tab
                                            ? (tab == .agents ? Color.cyan.opacity(0.7) : Color.purple.opacity(0.7))
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                if viewModel.selectedDeveloperTab == .agents {
                    // Agent Selector Pills: Anti, Claude, Copilot, Cursor
                    HStack(spacing: 4) {
                        ForEach(CodeAgentType.allCases) { agent in
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    agentService.selectedAgent = agent
                                }
                            } label: {
                                HStack(spacing: 3.5) {
                                    Image(systemName: agent.iconName)
                                        .font(.system(size: 8.5))
                                    Text(agentShortName(agent))
                                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
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
                } else {
                    // GitHub Actions Header Info + Trigger Action
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.purple)
                            Text(githubService.currentRepoName)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text("(\(githubService.currentBranch))")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                        
                        Button {
                            if githubService.activeRun != nil {
                                githubService.cancelBuild()
                            } else {
                                githubService.triggerBuild(workflowName: "CI / Swift Build")
                            }
                        } label: {
                            HStack(spacing: 3.5) {
                                Image(systemName: githubService.activeRun != nil ? "xmark.circle.fill" : "play.fill")
                                    .font(.system(size: 8.5, weight: .bold))
                                Text(githubService.activeRun != nil ? "Cancel" : "Run Build")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundColor(githubService.activeRun != nil ? .red : .white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(githubService.activeRun != nil ? Color.red.opacity(0.2) : Color.purple.opacity(0.35))
                            .overlay(Capsule().stroke(githubService.activeRun != nil ? Color.red.opacity(0.5) : Color.purple.opacity(0.7), lineWidth: 1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 2)
            
            // MARK: - Center Content Cards
            if viewModel.selectedDeveloperTab == .agents {
                agentsCardsView
            } else {
                gitHubActionsCardsView
            }
        }
    }
    
    // MARK: - Agents Cards View
    private var agentsCardsView: some View {
        HStack(spacing: 10) {
            // Card 1: Active Status & Action
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: agentService.selectedAgent.iconName)
                            .foregroundColor(agentService.selectedAgent.accentColor)
                            .font(.system(size: 11))
                        Text(agentService.selectedAgent.rawValue.uppercased())
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status Badge
                    HStack(spacing: 4) {
                        Image(systemName: agentService.status.icon)
                            .font(.system(size: 8.5, weight: .bold))
                        Text(agentService.status.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(agentService.status.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(agentService.status.color.opacity(0.18))
                    .clipShape(Capsule())
                }
                
                if let req = agentService.activePermissionRequest {
                    // High-Priority Permission Prompt Card
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 10))
                            Text("PERMISSION REQUESTED")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundColor(.yellow)
                        }
                        
                        Text(req.actionOrTool)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(6)
                        
                        HStack(spacing: 8) {
                            Button {
                                agentService.approveRequest(id: req.id)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("Approve")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4.5)
                                .background(Color.green)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                agentService.denyRequest(id: req.id)
                            } label: {
                                Text("Deny")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4.5)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    // Normal Agent Status Card
                    VStack(alignment: .leading, spacing: 6) {
                        Text(agentService.currentMessage)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Spacer()
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(agentService.status == .idle ? Color.secondary : agentService.status.color)
                                .frame(width: 6, height: 6)
                            
                            Text(agentService.status == .idle ? "Listening for agent activity" : "Live session active")
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.12)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            // Card 2: Recent Activity Stream & CLI Hook Snippet
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                        Text("ACTIVITY STREAM")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Live Hook")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(agentService.activityLog) { item in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(item.status.color)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 4)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack {
                                        Text(item.agent.rawValue)
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(item.formattedTime)
                                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Text(item.message)
                                        .font(.system(size: 9.5))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                            .padding(5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.12)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .frame(height: 140)
    }
    
    // MARK: - GitHub Actions Cards View
    private var gitHubActionsCardsView: some View {
        HStack(spacing: 10) {
            // Card 1: Active or Latest Build
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape.2.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 11))
                        Text("ACTIVE WORKFLOW")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let _ = githubService.activeRun {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 8, height: 8)
                            Text("BUILDING")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.18))
                        .clipShape(Capsule())
                    } else if let latest = githubService.runs.first {
                        HStack(spacing: 4) {
                            Image(systemName: latest.status.icon)
                                .font(.system(size: 8.5, weight: .bold))
                            Text(latest.status.rawValue.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(latest.status.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(latest.status.color.opacity(0.18))
                        .clipShape(Capsule())
                    }
                }
                
                if let active = githubService.activeRun {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(active.workflowName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(active.commitMessage)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                Text(active.durationFormatted)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Text("commit \(active.shortCommit)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let latest = githubService.runs.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(latest.workflowName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(latest.commitMessage)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(latest.status.color)
                                Text("Finished in \(latest.durationFormatted)")
                                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            Text(latest.shortCommit)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No workflow runs yet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.12)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            // Card 2: Workflow History List
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                        Text("RUN HISTORY")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(githubService.isGhCliAvailable ? "gh CLI active" : "local git")
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundColor(githubService.isGhCliAvailable ? .green : .secondary)
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(githubService.runs) { run in
                            HStack(alignment: .center, spacing: 6) {
                                Image(systemName: run.status.icon)
                                    .foregroundColor(run.status.color)
                                    .font(.system(size: 10, weight: .bold))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack {
                                        Text(run.workflowName)
                                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(run.durationFormatted)
                                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text(run.commitMessage)
                                            .font(.system(size: 8.5))
                                            .foregroundColor(.white.opacity(0.7))
                                            .lineLimit(1)
                                        Spacer()
                                        Text(run.shortCommit)
                                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                                            .foregroundColor(.secondary.opacity(0.8))
                                    }
                                }
                            }
                            .padding(5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.12)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .frame(height: 140)
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
