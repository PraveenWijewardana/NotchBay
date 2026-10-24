import SwiftUI
import AppKit

public struct HomeView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var mediaService: MediaControllerService
    @ObservedObject private var weatherService: WeatherService
    @ObservedObject private var calendarService: CalendarService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.mediaService = viewModel.mediaService
        self.weatherService = viewModel.weatherService
        self.calendarService = viewModel.calendarService
    }
    
    // MARK: - Clock & Calendar Formatted Properties
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: viewModel.currentDate)
    }
    
    private var formattedAmPm: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: viewModel.currentDate)
    }
    
    private var formattedHeaderDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: viewModel.currentDate)
    }
    
    private var nextEventItem: CalendarEventItem? {
        let now = Date()
        return calendarService.todayEvents.first(where: { $0.endDate >= now }) ??
               calendarService.todayEvents.first ??
               calendarService.userEvents.first
    }
    
    private var eventCount: Int {
        calendarService.todayEvents.count + calendarService.userEvents.count
    }
    
    private var eventTitle: String {
        nextEventItem?.title ?? "No Upcoming Events"
    }
    
    private var eventTime: String {
        if let event = nextEventItem {
            if event.isAllDay {
                return "All Day"
            }
            return event.timeFormatted
        }
        return "Tap to add an event"
    }
    
    private var eventColorHex: String {
        nextEventItem?.colorHex ?? "#BF5AF2"
    }
    
    // MARK: - Media Formatted Duration
    private var durationFormatted: String {
        let total = Int(mediaService.currentTrack.duration)
        guard total > 0 else { return "0:00" }
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - Column 1: Music Player / Now Playing (Left)
            musicColumn
                .frame(width: 215)
            
            // Vertical Divider 1
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 8)
            
            // MARK: - Column 2: Calendar / Agenda (Middle)
            calendarColumn
                .frame(width: 154)
            
            // Vertical Divider 2
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 8)
            
            // MARK: - Column 3: Live Weather (Right)
            weatherColumn
                .frame(width: 154)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }
    
    // MARK: - Column 1: Music Player
    private var musicColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Track Title & Artist
            VStack(alignment: .leading, spacing: 2) {
                Text(mediaService.currentTrack.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(mediaService.currentTrack.artist)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    viewModel.selectedPageIndex = 3 // Jump to Now Playing
                }
            }
            
            Spacer(minLength: 0)
            
            // Artwork & Playback Buttons
            HStack(spacing: 12) {
                // Squircle Artwork (54x54) with glowing reflection
                Group {
                    if let data = mediaService.currentTrack.artworkData,
                       let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.22, green: 0.40, blue: 0.28),
                                            Color(red: 0.12, green: 0.22, blue: 0.16)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 52, height: 52)
                            
                            Image(systemName: "music.note")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
                .shadow(color: Color.green.opacity(0.25), radius: 6, x: 0, y: 2)
                
                // Controls: Backward, Circular Play/Pause, Forward
                HStack(spacing: 8) {
                    Button {
                        mediaService.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        mediaService.togglePlayPause()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.14))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: mediaService.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        mediaService.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer(minLength: 0)
            
            // Progress Bar & Timestamps
            VStack(spacing: 4) {
                // Interactive Progress Track
                GeometryReader { geo in
                    let fraction = max(0.0, min(1.0, CGFloat(mediaService.currentTrack.progressFraction)))
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 3)
                        
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * fraction)), height: 3)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let target = max(0.0, min(1.0, Double(value.location.x / geo.size.width)))
                                mediaService.seek(to: target * mediaService.currentTrack.duration)
                            }
                    )
                }
                .frame(height: 8)
                
                // Timestamps: Elapsed on left, Total Duration on right
                HStack {
                    Text(mediaService.currentTrack.elapsedFormatted)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Text(durationFormatted)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.20, blue: 0.12).opacity(0.4),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Column 2: Clock & Agenda (Center Column)
    private var calendarColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Live Digital Time (Center of Home) - Tapping jumps to Timers & Clock
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    viewModel.selectedPageIndex = 2 // Jump to Timers & Clock
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formattedTime)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(formattedAmPm)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
            .help("Open Clock & Timers")
            
            // Date Header: "Sat, 24 Oct"
            Text(formattedHeaderDate)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
            
            // Subtitle
            Text(eventCount == 0 ? "No events today" : "\(eventCount) event\(eventCount == 1 ? "" : "s") coming up")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            
            Spacer(minLength: 8)
            
            // Event Item Preview or Clean Empty State
            if let event = nextEventItem {
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(Color(hex: event.colorHex))
                        .frame(width: 6, height: 6)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        Text(event.isAllDay ? "All Day" : event.timeFormatted)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No upcoming events")
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("Tap to add an event")
                            .font(.system(size: 10.5, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                viewModel.selectedPageIndex = 6 // Jump to Calendar Dashboard
            }
        }
    }
    
    // MARK: - Column 3: Weather
    private var weatherColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cloud Icon & Big Temperature
            HStack(spacing: 8) {
                Image(systemName: weatherService.weather.condition.iconName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(weatherService.weather.temperature)°")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(weatherService.weather.condition.rawValue)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            // City Name: Bengaluru
            Text(weatherService.currentCity)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer(minLength: 0)
            
            // High & Low Temperatures
            HStack(spacing: 16) {
                // High
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                        Text("High")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Text("\(weatherService.weather.highTemp)°")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Low
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 0.25, green: 0.70, blue: 1.0))
                        Text("Low")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Text("\(weatherService.weather.lowTemp)°")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                viewModel.selectedPageIndex = 7 // Jump to Weather Dashboard
            }
        }
    }
}
