import SwiftUI

public struct TimerDashboardView: View {
    @ObservedObject public var viewModel: NotchViewModel
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            // Header: Timers title & Reset / New timer
            HStack {
                Text("Timers")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    if viewModel.timerMode == .stopwatch {
                        viewModel.resetStopwatch()
                    } else {
                        viewModel.resetTimer()
                    }
                } label: {
                    Text("Reset")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // Mode Selectors (Timer | Pomodoro | Stopwatch) & Action Button
            HStack {
                HStack(spacing: 16) {
                    ForEach(TimerMode.allCases) { mode in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                viewModel.timerMode = mode
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(mode.rawValue)
                                    .font(.system(size: 13, weight: viewModel.timerMode == mode ? .bold : .medium, design: .rounded))
                                    .foregroundColor(viewModel.timerMode == mode ? .white : .secondary)
                                
                                if viewModel.timerMode == mode {
                                    Capsule()
                                        .fill(Color.yellow)
                                        .frame(height: 2)
                                } else {
                                    Spacer()
                                        .frame(height: 2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Start / Pause Pill Button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        if viewModel.timerMode == .stopwatch {
                            viewModel.toggleStopwatch()
                        } else {
                            viewModel.toggleTimer()
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: viewModel.timerConfig.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(viewModel.timerConfig.isRunning ? "Pause" : "Start")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.yellow)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // Big Display & Preset Chips
            HStack(alignment: .center) {
                // Large digits display
                Text(viewModel.timerMode == .stopwatch ? viewModel.timerConfig.formattedStopwatch : viewModel.timerConfig.formattedTime)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                
                Spacer()
                
                // Quick preset pills (Timer & Pomodoro modes)
                if viewModel.timerMode != .stopwatch {
                    HStack(spacing: 6) {
                        presetChip(minutes: 5)
                        presetChip(minutes: 10)
                        presetChip(minutes: 25)
                    }
                } else {
                    // Lap button for stopwatch
                    Button {
                        viewModel.lapStopwatch()
                    } label: {
                        Text("Lap")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            
            // Interactive Ruler Slider (for setting duration)
            if viewModel.timerMode != .stopwatch {
                RulerSliderView(
                    selectedMinutes: Binding(
                        get: { viewModel.timerConfig.selectedDurationMinutes },
                        set: { newMin in
                            viewModel.setTimerMinutes(newMin)
                        }
                    ),
                    range: 1...30
                )
            } else if !viewModel.timerConfig.laps.isEmpty {
                // Show latest laps for stopwatch
                HStack(spacing: 12) {
                    Text("Laps: \(viewModel.timerConfig.laps.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    if let lastLap = viewModel.timerConfig.laps.last {
                        Text(String(format: "Last: %.1fs", lastLap))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            
            // Footer: Target time calculation or Pomodoro status
            HStack {
                if viewModel.timerMode == .pomodoro {
                    Text("\(viewModel.timerConfig.pomodoroPhase.rawValue) • Cycle \(viewModel.timerConfig.completedPomodoros + 1)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                } else if viewModel.timerMode == .timer {
                    Text(viewModel.timerConfig.endsAroundFormatted)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text("High-precision system stopwatch")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func presetChip(minutes: Int) -> some View {
        let isSelected = (viewModel.timerConfig.selectedDurationMinutes == minutes)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                viewModel.setTimerMinutes(minutes)
            }
        } label: {
            Text("\(minutes)m")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .yellow : .white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.yellow.opacity(0.18) : Color.white.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
