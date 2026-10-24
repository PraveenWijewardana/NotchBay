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
            // Left Hero Card: Current Temp, Animated Condition, Key Metrics
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(weatherService.weather.temperature)°")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Feels like \(weatherService.weather.feelsLike)°")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Condition Icon with Glowing Gradient
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: weatherService.weather.condition.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .opacity(0.25)
                            .blur(radius: 6)
                        
                        Image(systemName: weatherService.weather.condition.iconName)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(LinearGradient(colors: weatherService.weather.condition.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                
                Spacer(minLength: 0)
                
                // Weather Metrics Grid (3 Readouts)
                HStack(spacing: 5) {
                    metricItem(icon: "humidity.fill", title: "HUMIDITY", value: "\(weatherService.weather.humidity)%", color: .cyan)
                    metricItem(icon: "wind", title: "WIND", value: String(format: "%.0f km/h", weatherService.weather.windSpeedKmh), color: .teal)
                    metricItem(icon: "sun.max.trianglebadge.exclamationmark.fill", title: "UV INDEX", value: "\(weatherService.weather.uvIndex)", color: .orange)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.12)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            // Right Forecast Card: Hourly Scroll + 4-Day Glance
            VStack(alignment: .leading, spacing: 7) {
                Text("HOURLY FORECAST")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                // Horizontal Hourly Scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(weatherService.weather.hourlyForecast) { item in
                            VStack(spacing: 3) {
                                Text(item.time)
                                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                Image(systemName: item.condition.iconName)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                Text("\(item.temperature)°")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                        }
                    }
                }
                
                Divider().background(Color.white.opacity(0.08))
                
                Text("NEXT DAYS")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                // Compact Daily Rows
                VStack(spacing: 4) {
                    ForEach(weatherService.weather.dailyForecast.prefix(3)) { day in
                        HStack {
                            Text(day.dayName)
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 42, alignment: .leading)
                            
                            Image(systemName: day.condition.iconName)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("\(day.minTemp)°")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            // Mini Temperature Bar
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 45, height: 3.5)
                                Capsule()
                                    .fill(LinearGradient(colors: [.blue, .orange], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: 28, height: 3.5)
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
    
    private func metricItem(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 7.5))
                    .foregroundColor(color)
                Text(title)
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
