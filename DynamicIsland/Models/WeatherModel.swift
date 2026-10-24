import Foundation
import SwiftUI

public enum WeatherConditionType: String, Sendable, CaseIterable {
    case clear = "Clear"
    case partlyCloudy = "Partly Cloudy"
    case cloudy = "Cloudy"
    case overcast = "Overcast"
    case fog = "Fog"
    case lightRain = "Light Rain"
    case heavyRain = "Heavy Rain"
    case thunderstorm = "Thunderstorm"
    case snow = "Snow"
    case windy = "Windy"
    
    public var iconName: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .overcast: return "smoke.fill"
        case .fog: return "cloud.fog.fill"
        case .lightRain: return "cloud.drizzle.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .snow: return "snowflake"
        case .windy: return "wind"
        }
    }
    
    public var gradientColors: [Color] {
        switch self {
        case .clear:
            return [Color.orange, Color.yellow]
        case .partlyCloudy:
            return [Color.blue.opacity(0.8), Color.orange.opacity(0.8)]
        case .cloudy, .overcast:
            return [Color.gray, Color.blue.opacity(0.6)]
        case .fog:
            return [Color(white: 0.5), Color(white: 0.3)]
        case .lightRain, .heavyRain:
            return [Color.cyan, Color.blue]
        case .thunderstorm:
            return [Color.purple, Color.indigo]
        case .snow:
            return [Color.cyan, Color.white.opacity(0.8)]
        case .windy:
            return [Color.teal, Color.cyan]
        }
    }
    
    public static func from(wmoCode: Int) -> WeatherConditionType {
        switch wmoCode {
        case 0: return .clear
        case 1, 2: return .partlyCloudy
        case 3: return .cloudy
        case 45, 48: return .fog
        case 51, 53, 55, 61, 63: return .lightRain
        case 65, 80, 81, 82: return .heavyRain
        case 71, 73, 75, 77, 85, 86: return .snow
        case 95, 96, 99: return .thunderstorm
        default: return .clear
        }
    }
}

public struct HourlyForecastItem: Identifiable, Sendable {
    public let id = UUID()
    public let time: String
    public let temperature: Int
    public let condition: WeatherConditionType
    
    public init(time: String, temperature: Int, condition: WeatherConditionType) {
        self.time = time
        self.temperature = temperature
        self.condition = condition
    }
}

public struct DailyForecastItem: Identifiable, Sendable {
    public let id = UUID()
    public let dayName: String
    public let condition: WeatherConditionType
    public let minTemp: Int
    public let maxTemp: Int
    
    public init(dayName: String, condition: WeatherConditionType, minTemp: Int, maxTemp: Int) {
        self.dayName = dayName
        self.condition = condition
        self.minTemp = minTemp
        self.maxTemp = maxTemp
    }
}

public struct CurrentWeatherData: Sendable {
    public var cityName: String = "Cupertino"
    public var temperature: Int = 22
    public var feelsLike: Int = 23
    public var condition: WeatherConditionType = .clear
    public var highTemp: Int = 26
    public var lowTemp: Int = 16
    public var humidity: Int = 54
    public var windSpeedKmh: Double = 12.0
    public var uvIndex: Int = 5
    public var airQuality: String = "Good (28)"
    public var hourlyForecast: [HourlyForecastItem] = []
    public var dailyForecast: [DailyForecastItem] = []
    
    public init() {}
}
