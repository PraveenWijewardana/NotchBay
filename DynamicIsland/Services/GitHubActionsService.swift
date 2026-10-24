import Foundation
import Combine
import AppKit

@MainActor
public final class GitHubActionsService: ObservableObject {
    @Published public var runs: [BuildWorkflowRun] = []
    @Published public var activeRun: BuildWorkflowRun? = nil
    @Published public var currentRepoName: String = "NotchBay"
    @Published public var currentBranch: String = "main"
    @Published public var lastCommitHash: String = "60ac53e"
    @Published public var lastCommitMessage: String = "Resolve all Xcode build warnings"
    @Published public var isGhCliAvailable: Bool = false
    
    public var onBuildCompleted: ((BuildWorkflowRun) -> Void)?
    
    private var liveTickerTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        detectLocalGitInfo()
        loadInitialRuns()
    }
    
    deinit {
        liveTickerTimer?.invalidate()
    }
    
    // MARK: - Git & GitHub Detection
    public func detectLocalGitInfo() {
        Task.detached(priority: .utility) {
            let repoPath = "/Users/praveen/Desktop/dynamic island"
            
            // Branch
            let branch = GitHubActionsService.executeShell("git -C \"\(repoPath)\" branch --show-current")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "main"
            
            // Latest Commit
            let log = GitHubActionsService.executeShell("git -C \"\(repoPath)\" log -1 --format=\"%h|||%s\"")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let parts = log.components(separatedBy: "|||")
            let commitHash = parts.count > 0 && !parts[0].isEmpty ? parts[0] : "main"
            let commitMsg = parts.count > 1 ? parts[1] : "Latest changes"
            
            // Remote repo name
            let remote = GitHubActionsService.executeShell("git -C \"\(repoPath)\" remote get-url origin")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let repoName: String
            if !remote.isEmpty {
                let clean = remote.replacingOccurrences(of: ".git", with: "")
                repoName = clean.components(separatedBy: "/").last ?? "NotchBay"
            } else {
                repoName = "NotchBay"
            }
            
            // Check gh CLI
            let ghPath = GitHubActionsService.executeShell("which gh")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hasGh = !ghPath.isEmpty && !ghPath.contains("not found")
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.currentBranch = branch.isEmpty ? "main" : branch
                self.currentRepoName = repoName
                self.lastCommitHash = commitHash
                self.lastCommitMessage = commitMsg
                self.isGhCliAvailable = hasGh
            }
        }
    }
    
    private func loadInitialRuns() {
        runs = [
            BuildWorkflowRun(
                id: "run-101",
                repoName: "NotchBay",
                workflowName: "Swift Build & Test",
                branch: "main",
                commitHash: "60ac53e",
                commitMessage: "Resolve all Xcode build warnings",
                author: "Praveen",
                status: .success,
                startedAt: Date().addingTimeInterval(-3600),
                durationSeconds: 78,
                htmlUrl: URL(string: "https://github.com")
            ),
            BuildWorkflowRun(
                id: "run-102",
                repoName: "NotchBay",
                workflowName: "Release DMG Export",
                branch: "main",
                commitHash: "20ba33f",
                commitMessage: "Enhance compact island UI, add audio controls",
                author: "Praveen",
                status: .success,
                startedAt: Date().addingTimeInterval(-7200),
                durationSeconds: 114,
                htmlUrl: URL(string: "https://github.com")
            )
        ]
    }
    
    // MARK: - Trigger Build / Workflow Simulation
    public func triggerBuild(workflowName: String = "CI / Xcode Build") {
        guard activeRun == nil else { return }
        
        let newRun = BuildWorkflowRun(
            id: UUID().uuidString,
            repoName: currentRepoName,
            workflowName: workflowName,
            branch: currentBranch,
            commitHash: lastCommitHash,
            commitMessage: lastCommitMessage,
            author: "You",
            status: .inProgress,
            startedAt: Date(),
            durationSeconds: 0,
            htmlUrl: URL(string: "https://github.com")
        )
        
        activeRun = newRun
        runs.insert(newRun, at: 0)
        
        NSSound(named: "Tink")?.play()
        
        // Start live ticker
        liveTickerTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, var run = self.activeRun else { return }
                run.durationSeconds += 1
                self.activeRun = run
                
                // Simulate build completion after 12-16 seconds or real build completion
                if run.durationSeconds >= 14 {
                    self.completeBuild(success: true)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        liveTickerTimer = timer
    }
    
    public func completeBuild(success: Bool) {
        liveTickerTimer?.invalidate()
        liveTickerTimer = nil
        
        guard var run = activeRun else { return }
        run.status = success ? .success : .failure
        activeRun = nil
        
        // Update in run history
        if let idx = runs.firstIndex(where: { $0.id == run.id }) {
            runs[idx] = run
        }
        
        if success {
            NSSound(named: "Glass")?.play()
        } else {
            NSSound(named: "Basso")?.play()
        }
        
        onBuildCompleted?(run)
    }
    
    public func cancelBuild() {
        liveTickerTimer?.invalidate()
        liveTickerTimer = nil
        
        guard var run = activeRun else { return }
        run.status = .failure
        activeRun = nil
        
        if let idx = runs.firstIndex(where: { $0.id == run.id }) {
            runs[idx] = run
        }
        
        NSSound(named: "Basso")?.play()
        onBuildCompleted?(run)
    }
    
    nonisolated private static func executeShell(_ cmd: String) -> String? {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", cmd]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
