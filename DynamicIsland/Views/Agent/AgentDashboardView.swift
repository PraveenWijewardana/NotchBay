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
        VStack(spacing: 9) {
            // MARK: - Header: Title + Agent Selector + IPC Server Status
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("Code Agents")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // IPC Server status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(agentService.isServerRunning ? Color.green : Color.orange)
                            .frame(width: 5.5, height: 5.5)
                            .shadow(color: .green.opacity(0.8), radius: 2)
                        Text(agentService.isServerRunning ? "127.0.0.1:19842" : "Connecting")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                // Agent Selector Pills: Anti, Claude, Copilot, Cursor (compact, non-wrapping)
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
            }
            .padding(.horizontal, 2)
            
            // MARK: - Center Cards: Live Status & Activity Stream
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(agentService.currentMessage)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Spacer()
                            
                            // Interactive Simulation Bar (Test Antigravity / Claude / Copilot right now)
                            HStack(spacing: 6) {
                                testPill(title: "Working", icon: "brain") {
                                    agentService.simulateWorking(agent: agentService.selectedAgent)
                                }
                                
                                testPill(title: "Permission", icon: "shield") {
                                    agentService.simulatePermission(agent: agentService.selectedAgent)
                                }
                                
                                testPill(title: "Done", icon: "checkmark") {
                                    agentService.simulateCompletion(agent: agentService.selectedAgent)
                                }
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
    }
    
    private func testPill(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8.5))
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(Color.white.opacity(0.09))
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
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
