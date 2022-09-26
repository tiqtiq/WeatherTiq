import Foundation
import LocationTiq

/// A Service Provider Interface for communicating with various weather services.

/// A WeatherServiceAPI is an abstraction of a weather service
public protocol WeatherServiceSPI : AnyObject {
    var attribution: WeatherAttributionType { get async throws }
    associatedtype WeatherAttributionType : WeatherAttributionSPI

    func weather(for location: Location) async throws -> WeatherType
    associatedtype WeatherType : WeatherSPI
}

/// A location that contains a latitude, longitude, and altitude
public protocol WeatherLocation {
    var latitude: Double { get }
    var longitude: Double { get }
    var altitude: Double { get }
}

public protocol WeatherAttributionSPI {
    /// The weather data provider name.
    var serviceName: String { get }

    /// A link to the legal attribution page that contains copyright information about the weather data sources.
    var legalPageURL: URL { get }

    /// A URL for the square mark.
    var squareMarkURL: URL { get }

    /// A URL for the combined "<logo>" mark, in dark variant.
    var combinedMarkDarkURL: URL { get }

    /// A URL for the combined "<logo>" mark, in light variant.
    var combinedMarkLightURL: URL { get }
}

public protocol WeatherSPI {
    /// The current weather forecast.
    var currentWeather: CurrentWeatherType { get }
    associatedtype CurrentWeatherType : CurrentWeatherSPI

    /// The minute-by-minute forecast. Optional due to unsupported regions and availability of data.
    var minuteForecast: MinuteForecastType? { get }
    associatedtype MinuteForecastType : MinuteForecastSPI

    /// The hourly forecast.
    var hourlyForecast: HourForecastType { get }
    associatedtype HourForecastType : HourForecastSPI

    /// The daily forecast.
    var dailyForecast: DayForecastType { get }
    associatedtype DayForecastType : DayForecastSPI

    /// The severe weather alerts.
    var weatherAlerts: [WeatherAlertType]? { get }
    associatedtype WeatherAlertType : WeatherAlertSPI

    /// The flags containing information about data availability and attribution.
    var availability: WeatherAvailabilityType { get }
    associatedtype WeatherAvailabilityType : WeatherAvailabilitySPI
}

public protocol CurrentWeatherSPI {
}

public protocol MinuteForecastSPI {
}

public protocol HourForecastSPI {
}

public protocol DayForecastSPI {
}

public protocol WeatherAlertSPI {
}

public protocol WeatherAvailabilitySPI {
}
