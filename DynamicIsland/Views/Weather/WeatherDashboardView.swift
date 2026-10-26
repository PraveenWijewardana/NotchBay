import SwiftUI

public struct WeatherDashboardView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var weatherService: WeatherService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.weatherService = viewModel.weatherService
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - Header: Location & High/Low & Refresh
            HStack(alignment: .center) {
                // Interactive Location Button
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        weatherService.isShowingLocationPicker.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                        Text(weatherService.weather.cityName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Image(systemName: weatherService.isShowingLocationPicker ? "chevron.up.circle.fill" : "magnifyingglass.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.cyan.opacity(0.85))
                        
                        if !weatherService.isShowingLocationPicker {
                            Text("\(weatherService.weather.condition.rawValue)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(weatherService.isShowingLocationPicker ? 0.12 : 0.05)))
                }
                .buttonStyle(.plain)
                .help("Change Weather Location")
                
                Spacer()
                
                HStack(spacing: 8) {
                    if weatherService.isShowingLocationPicker {
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                weatherService.isShowingLocationPicker = false
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Close")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 4) {
                            Text("H: \(weatherService.weather.highTemp)°")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                            Text("L: \(weatherService.weather.lowTemp)°")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                        
                        Button {
                            weatherService.fetchWeather()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(weatherService.isLoading ? .cyan : .white.opacity(0.7))
                                .rotationEffect(.degrees(weatherService.isLoading ? 360 : 0))
                                .animation(weatherService.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: weatherService.isLoading)
                                .padding(5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Refresh Weather")
                    }
                }
            }
            .padding(.horizontal, 2)
            
            // MARK: - Main Content: Either Location Picker or Weather Dashboard Cards
            if weatherService.isShowingLocationPicker {
                locationPickerPanel
                    .frame(height: 146)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                weatherCards
                    .frame(height: 146)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .onAppear {
            weatherService.startAnimations()
        }
    }
    
    // MARK: - Location Picker View
    private var locationPickerPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Search Input Row
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyan)
                
                TextField("Search any city worldwide (e.g. London, Tokyo, New York)...", text: $weatherService.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .onChange(of: weatherService.searchQuery) { _, query in
                        Task {
                            await weatherService.searchLocations(query: query)
                        }
                    }
                
                if !weatherService.searchQuery.isEmpty {
                    Button {
                        weatherService.searchQuery = ""
                        weatherService.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5.5)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
            
            if weatherService.isSearching {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Searching cities...")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !weatherService.searchResults.isEmpty {
                // Live Search Results
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(weatherService.searchResults) { loc in
                            Button {
                                weatherService.selectLocation(loc)
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    weatherService.isShowingLocationPicker = false
                                    weatherService.searchQuery = ""
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.cyan)
                                    Text(loc.displayName)
                                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("Select")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(.cyan)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4.5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                // Popular Cities Shortcut Chips
                VStack(alignment: .leading, spacing: 6) {
                    Text("POPULAR CITIES")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(WeatherService.popularLocations) { loc in
                                Button {
                                    weatherService.selectLocation(loc)
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                        weatherService.isShowingLocationPicker = false
                                        weatherService.searchQuery = ""
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "building.2.fill")
                                            .font(.system(size: 8.5))
                                            .foregroundColor(.cyan)
                                        Text(loc.name)
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4.5)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan.opacity(0.8))
                        Text("Type any city name above to get real-time worldwide weather.")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
    
    // MARK: - Weather Cards
    private var weatherCards: some View {
        HStack(spacing: 10) {
            // Left Hero Card: Current Temp, Animated Condition, Key Metrics & Atmosphere
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(weatherService.weather.temperature)°")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(
                                color: (weatherService.weather.condition.gradientColors.first ?? .cyan).opacity(weatherService.isAnimated ? 0.45 : 0.15),
                                radius: weatherService.isAnimated ? 10 : 4,
                                x: 0,
                                y: 2
                            )
                            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: weatherService.isAnimated)
                        
                        HStack(spacing: 3) {
                            Text("Feels like")
                                .foregroundColor(.secondary)
                            Text("\(weatherService.weather.feelsLike)°")
                                .foregroundColor(.white.opacity(0.85))
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 10, design: .rounded))
                    }
                    
                    Spacer()
                    
                    // Condition Icon with Multi-layer Pulsing & Floating Glow
                    ZStack {
                        // Outer breathing ambient glow aura
                        Circle()
                            .fill(LinearGradient(colors: weatherService.weather.condition.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 48, height: 48)
                            .opacity(weatherService.isAnimated ? 0.38 : 0.15)
                            .scaleEffect(weatherService.isAnimated ? 1.18 : 0.94)
                            .blur(radius: 8)
                            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: weatherService.isAnimated)
                        
                        // Gentle floating & breathing weather icon
                        Image(systemName: weatherService.weather.condition.iconName)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(LinearGradient(colors: weatherService.weather.condition.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .offset(y: weatherService.isAnimated ? -2.5 : 2.5)
                            .rotationEffect(.degrees(weatherService.weather.condition == .clear ? (weatherService.isAnimated ? 12 : -10) : (weatherService.isAnimated ? 2 : -2)))
                            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: weatherService.isAnimated)
                    }
                    .frame(width: 44, height: 44)
                }
                
                Spacer(minLength: 0)
                
                // Weather Metrics Grid (3 Readouts with Custom Animated Glyphs)
                HStack(spacing: 5) {
                    metricItem(type: .humidity, value: "\(weatherService.weather.humidity)%")
                    metricItem(type: .wind, value: String(format: "%.0f km/h", weatherService.weather.windSpeedKmh))
                    metricItem(type: .uv, value: "\(weatherService.weather.uvIndex)")
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.11))
                    
                    WeatherAtmosphereView(condition: weatherService.weather.condition, isAnimated: weatherService.isAnimated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                (weatherService.weather.condition.gradientColors.first ?? .cyan).opacity(weatherService.isAnimated ? 0.25 : 0.08),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: weatherService.isAnimated)
            )
            
            // Right Forecast Card: Hourly Scroll + 3-Day Glance
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("HOURLY FORECAST")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if weatherService.weather.condition == .clear || weatherService.weather.condition == .partlyCloudy {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 4, height: 4)
                                .scaleEffect(weatherService.isAnimated ? 1.2 : 0.8)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: weatherService.isAnimated)
                            Text("Sun")
                                .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.orange.opacity(0.8))
                        }
                    }
                }
                
                // Horizontal Hourly Scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(weatherService.weather.hourlyForecast) { item in
                            let isNow = item.time == "Now"
                            VStack(spacing: 3) {
                                HStack(spacing: 2) {
                                    if isNow {
                                        Circle()
                                            .fill(Color.cyan)
                                            .frame(width: 3.5, height: 3.5)
                                            .scaleEffect(weatherService.isAnimated ? 1.25 : 0.8)
                                            .opacity(weatherService.isAnimated ? 1.0 : 0.5)
                                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: weatherService.isAnimated)
                                    }
                                    Text(item.time)
                                        .font(.system(size: 8.5, weight: isNow ? .bold : .medium, design: .rounded))
                                        .foregroundColor(isNow ? .cyan : .secondary)
                                }
                                
                                Image(systemName: item.condition.iconName)
                                    .font(.system(size: 13))
                                    .foregroundStyle(isNow ? LinearGradient(colors: item.condition.gradientColors, startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [.white, .white.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                                    .offset(y: (isNow && weatherService.isAnimated) ? -1 : 1)
                                    .animation(isNow ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : .default, value: weatherService.isAnimated)
                                
                                Text("\(item.temperature)°")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isNow ? Color.cyan.opacity(0.12) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(isNow ? Color.cyan.opacity(0.35) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
                
                Divider().background(Color.white.opacity(0.08))
                
                Text("NEXT DAYS")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                // Compact Daily Rows with Dynamic Range Bars & Today Indicator
                let days = Array(weatherService.weather.dailyForecast.prefix(3))
                let globalMin = days.map(\.minTemp).min() ?? 10
                let globalMax = days.map(\.maxTemp).max() ?? 30
                let totalRange = max(1, globalMax - globalMin)
                
                VStack(spacing: 4) {
                    ForEach(days) { day in
                        HStack {
                            Text(day.dayName)
                                .font(.system(size: 9.5, weight: day.dayName == "Today" ? .bold : .medium, design: .rounded))
                                .foregroundColor(day.dayName == "Today" ? .cyan : .white)
                                .frame(width: 42, alignment: .leading)
                            
                            Image(systemName: day.condition.iconName)
                                .font(.system(size: 10))
                                .foregroundStyle(LinearGradient(colors: day.condition.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            
                            Spacer()
                            
                            Text("\(day.minTemp)°")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            // Dynamic Temperature Range Bar
                            let startRatio = CGFloat(day.minTemp - globalMin) / CGFloat(totalRange)
                            let endRatio = CGFloat(day.maxTemp - globalMin) / CGFloat(totalRange)
                            let trackWidth: CGFloat = 46
                            let barWidth = max(14, (endRatio - startRatio) * trackWidth)
                            let barOffset = startRatio * (trackWidth - barWidth)
                            
                            ZStack(alignment: .leading) {
                                // Background Track
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: trackWidth, height: 3.5)
                                
                                // Temperature Range Gradient Fill
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.cyan.opacity(0.85), Color.yellow, Color.orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: barWidth, height: 3.5)
                                    .offset(x: barOffset)
                                    .overlay(
                                        // Shimmer sweep highlight
                                        LinearGradient(
                                            colors: [.clear, Color.white.opacity(0.6), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        .frame(width: 14, height: 3.5)
                                        .offset(x: weatherService.isAnimated ? (barOffset + barWidth) : (barOffset - 14))
                                        .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: false), value: weatherService.isAnimated)
                                        .clipShape(Capsule())
                                    )
                                
                                // Live Current Temperature Indicator Dot for "Today"
                                if day.dayName == "Today" {
                                    let currentTempRatio = max(0, min(1, CGFloat(weatherService.weather.temperature - globalMin) / CGFloat(totalRange)))
                                    let dotX = min(max(2, currentTempRatio * trackWidth), trackWidth - 4)
                                    
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 5, height: 5)
                                        .shadow(color: .white.opacity(0.9), radius: 2)
                                        .scaleEffect(weatherService.isAnimated ? 1.2 : 0.85)
                                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: weatherService.isAnimated)
                                        .offset(x: dotX - 2.5)
                                }
                            }
                            
                            Text("\(day.maxTemp)°")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.12)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }
    
    private enum MetricType {
        case humidity
        case wind
        case uv
        
        var icon: String {
            switch self {
            case .humidity: return "humidity.fill"
            case .wind: return "wind"
            case .uv: return "sun.max.trianglebadge.exclamationmark.fill"
            }
        }
        
        var title: String {
            switch self {
            case .humidity: return "HUMIDITY"
            case .wind: return "WIND"
            case .uv: return "UV INDEX"
            }
        }
        
        var color: Color {
            switch self {
            case .humidity: return .cyan
            case .wind: return .teal
            case .uv: return .orange
            }
        }
    }
    
    private func metricItem(type: MetricType, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                // Customized Animated Icon for each Metric
                Group {
                    switch type {
                    case .humidity:
                        Image(systemName: type.icon)
                            .scaleEffect(weatherService.isAnimated ? 1.15 : 0.9)
                            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: weatherService.isAnimated)
                    case .wind:
                        Image(systemName: type.icon)
                            .offset(x: weatherService.isAnimated ? 2 : -2)
                            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: weatherService.isAnimated)
                    case .uv:
                        Image(systemName: type.icon)
                            .scaleEffect(weatherService.isAnimated ? 1.12 : 0.94)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: weatherService.isAnimated)
                    }
                }
                .font(.system(size: 7.5))
                .foregroundColor(type.color)
                
                Text(type.title)
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
    }
}

// MARK: - Weather Atmosphere Background View
private struct WeatherAtmosphereView: View {
    let condition: WeatherConditionType
    let isAnimated: Bool
    
    var body: some View {
        ZStack {
            // Ambient soft glowing orbs matching condition colors
            RadialGradient(
                colors: [
                    condition.gradientColors.first?.opacity(isAnimated ? 0.28 : 0.14) ?? Color.cyan.opacity(0.18),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 5,
                endRadius: isAnimated ? 90 : 70
            )
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isAnimated)
            
            // Condition specific particles/effects
            switch condition {
            case .clear, .partlyCloudy:
                // Gentle pulsing sunbeam aura
                Circle()
                    .fill(RadialGradient(colors: [Color.yellow.opacity(0.18), Color.orange.opacity(0.08), Color.clear], center: .center, startRadius: 0, endRadius: 60))
                    .frame(width: 120, height: 120)
                    .offset(x: 50, y: -20)
                    .scaleEffect(isAnimated ? 1.15 : 0.95)
                    .opacity(isAnimated ? 0.9 : 0.4)
                    .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: isAnimated)
                
            case .lightRain, .heavyRain, .thunderstorm:
                // Rain streaks falling diagonally
                GeometryReader { geo in
                    ForEach(0..<6, id: \.self) { i in
                        Capsule()
                            .fill(LinearGradient(colors: [Color.cyan.opacity(0.0), Color.cyan.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 1.5, height: CGFloat(10 + (i % 3) * 4))
                            .rotationEffect(.degrees(16))
                            .offset(
                                x: CGFloat(15 + i * 28),
                                y: isAnimated ? geo.size.height + 15 : -25
                            )
                            .animation(
                                .linear(duration: Double(0.9 + Double(i % 3) * 0.25))
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.18),
                                value: isAnimated
                            )
                    }
                }
                
            case .snow:
                // Gentle floating snowflakes
                GeometryReader { geo in
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: CGFloat(2.5 + (i % 2 == 0 ? 1.0 : 0.0)), height: CGFloat(2.5 + (i % 2 == 0 ? 1.0 : 0.0)))
                            .offset(
                                x: CGFloat(20 + i * 26) + (isAnimated ? 6 : -6),
                                y: isAnimated ? geo.size.height + 10 : -10
                            )
                            .animation(
                                .easeInOut(duration: Double(2.2 + Double(i % 3) * 0.4))
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.35),
                                value: isAnimated
                            )
                    }
                }
                
            case .cloudy, .overcast, .fog:
                // Soft drifting fog/cloud layers
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 110, height: 40)
                    .blur(radius: 10)
                    .offset(x: isAnimated ? 25 : -20, y: -15)
                    .animation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true), value: isAnimated)
                
            case .windy:
                // Wind swoosh lines
                GeometryReader { _ in
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(Color.teal.opacity(0.25))
                            .frame(width: CGFloat(30 + i * 15), height: 1.5)
                            .offset(x: isAnimated ? 40 : -40, y: CGFloat(25 + i * 30))
                            .animation(
                                .easeInOut(duration: Double(1.6 + Double(i) * 0.3))
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.4),
                                value: isAnimated
                            )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
