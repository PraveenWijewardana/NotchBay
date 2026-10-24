import Foundation

public enum TimerMode: String, CaseIterable, Identifiable, Sendable {
    case timer = "Timer"
    case pomodoro = "Pomodoro"
    case stopwatch = "Stopwatch"
    
    public var id: String { rawValue }
}

public enum PomodoroPhase: String, Sendable {
    case work = "Focus Session"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
}

public struct TimerConfig: Sendable {
    public var selectedDurationMinutes: Int = 10
    public var remainingSeconds: Int = 600
    public var isRunning: Bool = false
    public var targetDate: Date? = nil
    
    // Pomodoro settings
    public var pomodoroPhase: PomodoroPhase = .work
    public var completedPomodoros: Int = 0
    public var workDurationMinutes: Int = 25
    public var breakDurationMinutes: Int = 5
    
    // Stopwatch
    public var stopwatchElapsedSeconds: Double = 0
    public var laps: [Double] = []
    
    public init() {}
    
    public var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public var formattedStopwatch: String {
        let minutes = Int(stopwatchElapsedSeconds) / 60
        let seconds = Int(stopwatchElapsedSeconds) % 60
        let tenths = Int((stopwatchElapsedSeconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
    
    public var endsAroundFormatted: String {
        let target = targetDate ?? Date().addingTimeInterval(TimeInterval(remainingSeconds))
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Ends around \(formatter.string(from: target))"
    }
}
