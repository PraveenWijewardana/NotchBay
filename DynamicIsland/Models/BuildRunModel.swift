import Foundation
import SwiftUI

public enum BuildRunStatus: String, Codable, Sendable, CaseIterable {
    case inProgress = "in_progress"
    case success = "success"
    case failure = "failure"
    case queued = "queued"
    
    public var title: String {
        switch self {
        case .inProgress: return "Running"
        case .success: return "Passed"
        case .failure: return "Failed"
        case .queued: return "Queued"
        }
    }
    
    public var iconName: String {
        switch self {
        case .inProgress: return "gearshape.arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .queued: return "clock.fill"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .inProgress: return Color(red: 0.2, green: 0.85, blue: 1.0) // Electric Cyan
        case .success: return Color(red: 0.25, green: 0.95, blue: 0.55) // Mint Emerald
        case .failure: return Color(red: 1.0, green: 0.35, blue: 0.35)  // Coral Red
        case .queued: return Color(red: 1.0, green: 0.8, blue: 0.2)    // Amber Yellow
        }
    }
    
    public var icon: String { iconName }
    public var color: Color { accentColor }
}

public struct BuildWorkflowRun: Identifiable, Sendable {
    public let id: String
    public let repoName: String
    public let workflowName: String
    public let branch: String
    public let commitHash: String
    public let commitMessage: String
    public let author: String
    public var status: BuildRunStatus
    public let startedAt: Date
    public var durationSeconds: Int
    public let htmlUrl: URL?
    
    public init(
        id: String = UUID().uuidString,
        repoName: String,
        workflowName: String,
        branch: String,
        commitHash: String,
        commitMessage: String,
        author: String,
        status: BuildRunStatus,
        startedAt: Date = Date(),
        durationSeconds: Int = 0,
        htmlUrl: URL? = nil
    ) {
        self.id = id
        self.repoName = repoName
        self.workflowName = workflowName
        self.branch = branch
        self.commitHash = commitHash
        self.commitMessage = commitMessage
        self.author = author
        self.status = status
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.htmlUrl = htmlUrl
    }
    
    public var durationFormatted: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
    
    public var shortCommit: String {
        String(commitHash.prefix(7))
    }
}
