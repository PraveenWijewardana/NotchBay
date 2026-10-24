import Foundation
import Combine

public struct LocationSearchResult: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let country: String?
    public let admin1: String?
    
    public var displayName: String {
        var parts: [String] = [name]
        if let admin = admin1, !admin.isEmpty {
            parts.append(admin)
        }
        if let country = country, !country.isEmpty {
            parts.append(country)
        }
        return parts.joined(separator: ", ")
    }
}

@MainActor
public final class WeatherService: ObservableObject {
    @Published public var weather: CurrentWeatherData = CurrentWeatherData()
    @Published public var currentCity: String = "Bengaluru"
    @Published public var latitude: Double = 12.9716
    @Published public var longitude: Double = 77.5946
    @Published public var searchResults: [LocationSearchResult] = []
    @Published public var isSearching: Bool = false
    @Published public var isShowingLocationPicker: Bool = false
    @Published public var searchQuery: String = ""
    @Published public var isLoading: Bool = false
    @Published public var lastUpdated: Date?
    
    private var refreshTimer: Timer?
    private let cityKey = "DynamicIsland_WeatherCity"
    private let latKey = "DynamicIsland_WeatherLat"
    private let lonKey = "DynamicIsland_WeatherLon"
    
    public static let popularLocations: [LocationSearchResult] = [
        LocationSearchResult(id: 1, name: "Cupertino", latitude: 37.323, longitude: -122.032, country: "United States", admin1: "California"),
        LocationSearchResult(id: 2, name: "New York", latitude: 40.7128, longitude: -74.006, country: "United States", admin1: "New York"),
        LocationSearchResult(id: 3, name: "London", latitude: 51.5074, longitude: -0.1278, country: "United Kingdom", admin1: "England"),
        LocationSearchResult(id: 4, name: "Tokyo", latitude: 35.6895, longitude: 139.6917, country: "Japan", admin1: "Tokyo"),
        LocationSearchResult(id: 5, name: "Paris", latitude: 48.8566, longitude: 2.3522, country: "France", admin1: "Île-de-France"),
        LocationSearchResult(id: 6, name: "Bengaluru", latitude: 12.9716, longitude: 77.5946, country: "India", admin1: "Karnataka"),
        LocationSearchResult(id: 7, name: "Sydney", latitude: -33.8688, longitude: 151.2093, country: "Australia", admin1: "New South Wales")
    ]
    
    public init() {
        if let savedCity = UserDefaults.standard.string(forKey: cityKey) {
            self.currentCity = savedCity
        }
        if let savedLat = UserDefaults.standard.object(forKey: latKey) as? Double {
            self.latitude = savedLat
        }
        if let savedLon = UserDefaults.standard.object(forKey: lonKey) as? Double {
            self.longitude = savedLon
        }
        
        populateDefaultData()
        fetchWeather()
        
        // Refresh every 30 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchWeather()
            }
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    public func selectLocation(_ location: LocationSearchResult) {
        self.currentCity = location.name
        self.latitude = location.latitude
        self.longitude = location.longitude
        
        UserDefaults.standard.set(location.name, forKey: cityKey)
        UserDefaults.standard.set(location.latitude, forKey: latKey)
        UserDefaults.standard.set(location.longitude, forKey: lonKey)
        
        self.searchResults = []
        self.isSearching = false
        self.weather.cityName = location.name
        
        fetchWeather()
    }
    
    public func searchLocations(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            self.searchResults = []
            self.isSearching = false
            return
        }
        
        self.isSearching = true
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=6&language=en&format=json") else {
            self.isSearching = false
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 4.0
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.isSearching = false
                return
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]] {
                self.searchResults = results.compactMap { dict in
                    guard let id = dict["id"] as? Int,
                          let name = dict["name"] as? String,
                          let lat = dict["latitude"] as? Double,
                          let lon = dict["longitude"] as? Double else { return nil }
                    return LocationSearchResult(
                        id: id,
                        name: name,
                        latitude: lat,
                        longitude: lon,
                        country: dict["country"] as? String,
                        admin1: dict["admin1"] as? String
                    )
                }
            } else {
                self.searchResults = []
            }
        } catch {
            self.searchResults = []
        }
        self.isSearching = false
    }
    
    public func fetchWeather() {
        isLoading = true
        
        Task {
            do {
                // Fetch dynamic coordinates
                let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&hourly=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto"
                
                guard let url = URL(string: urlString) else {
                    populateDefaultData()
                    self.isLoading = false
                    return
                }
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 5.0
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    self.isLoading = false
                    return
                }
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.parseWeatherData(json)
                }
            } catch {
                // Offline fallback with current city preserved
                self.populateDefaultData()
            }
            self.isLoading = false
            self.lastUpdated = Date()
        }
    }
    
    private func parseWeatherData(_ json: [String: Any]) {
        var newWeather = CurrentWeatherData()
        newWeather.cityName = self.currentCity
        
        // Current
        if let current = json["current"] as? [String: Any] {
            if let temp = current["temperature_2m"] as? Double {
                newWeather.temperature = Int(round(temp))
            }
            if let feels = current["apparent_temperature"] as? Double {
                newWeather.feelsLike = Int(round(feels))
            }
            if let code = current["weather_code"] as? Int {
                newWeather.condition = WeatherConditionType.from(wmoCode: code)
            }
            if let hum = current["relative_humidity_2m"] as? Int {
                newWeather.humidity = hum
            }
            if let wind = current["wind_speed_10m"] as? Double {
                newWeather.windSpeedKmh = wind
            }
        }
        
        // Daily
        if let daily = json["daily"] as? [String: Any],
           let times = daily["time"] as? [String],
           let maxTemps = daily["temperature_2m_max"] as? [Double],
           let minTemps = daily["temperature_2m_min"] as? [Double],
           let codes = daily["weather_code"] as? [Int] {
            
            if let todayMax = maxTemps.first, let todayMin = minTemps.first {
                newWeather.highTemp = Int(round(todayMax))
                newWeather.lowTemp = Int(round(todayMin))
            }
            
            var dailyItems: [DailyForecastItem] = []
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"
            let targetFormatter = DateFormatter()
            targetFormatter.dateFormat = "EEE"
            
            for i in 0..<min(times.count, 6) {
                let code = i < codes.count ? codes[i] : 0
                let cond = WeatherConditionType.from(wmoCode: code)
                let minT = i < minTemps.count ? Int(round(minTemps[i])) : 15
                let maxT = i < maxTemps.count ? Int(round(maxTemps[i])) : 24
                
                var name = "Day"
                if i == 0 {
                    name = "Today"
                } else if let date = dayFormatter.date(from: times[i]) {
                    name = targetFormatter.string(from: date)
                }
                
                dailyItems.append(DailyForecastItem(dayName: name, condition: cond, minTemp: minT, maxTemp: maxT))
            }
            newWeather.dailyForecast = dailyItems
        }
        
        // Hourly (next 12 hours)
        if let hourly = json["hourly"] as? [String: Any],
           let times = hourly["time"] as? [String],
           let temps = hourly["temperature_2m_max"] ?? hourly["temperature_2m"] as? [Double],
           let codes = hourly["weather_code"] as? [Int] {
            
            let isoFormatter = DateFormatter()
            isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            let hourDisplayFormatter = DateFormatter()
            hourDisplayFormatter.dateFormat = "ha"
            
            let now = Date()
            var hourlyItems: [HourlyForecastItem] = []
            
            if let tempArray = temps as? [Double] {
                for i in 0..<min(times.count, tempArray.count) {
                    if let d = isoFormatter.date(from: times[i]), d >= now.addingTimeInterval(-1800) {
                        let t = Int(round(tempArray[i]))
                        let code = i < codes.count ? codes[i] : 0
                        let cond = WeatherConditionType.from(wmoCode: code)
                        let timeStr = hourlyItems.isEmpty ? "Now" : hourDisplayFormatter.string(from: d).lowercased()
                        hourlyItems.append(HourlyForecastItem(time: timeStr, temperature: t, condition: cond))
                        if hourlyItems.count >= 8 { break }
                    }
                }
            }
            newWeather.hourlyForecast = hourlyItems
        }
        
        self.weather = newWeather
    }
    
    private func populateDefaultData() {
        var w = CurrentWeatherData()
        w.cityName = self.currentCity
        w.temperature = 0
        w.feelsLike = 0
        w.condition = .clear
        w.highTemp = 0
        w.lowTemp = 0
        w.humidity = 0
        w.windSpeedKmh = 0.0
        w.uvIndex = 0
        w.airQuality = "--"
        w.hourlyForecast = []
        w.dailyForecast = []
        self.weather = w
    }
}
