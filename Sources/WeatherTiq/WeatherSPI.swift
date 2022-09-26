import Foundation

/// A Service Provider Interface for communicating with various weather services.

/// A WeatherServiceAPI is an abstraction of a weather service
public protocol WeatherServiceSPI : AnyObject {
    var attribution: WeatherAttributionType { get async throws }
    associatedtype WeatherAttributionType : WeatherAttributionSPI

    func weather(for location: Location) async throws -> WeatherType
    associatedtype WeatherType : WeatherSPI
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


#if canImport(CoreLocation)

import class CoreLocation.CLLocation
import struct CoreLocation.CLLocationCoordinate2D
import func CoreLocation.CLLocationCoordinate2DIsValid
import typealias CoreLocation.CLLocationDegrees

public typealias Degrees = CoreLocation.CLLocationDegrees

public typealias Location = CoreLocation.CLLocation

/// An abastraction of a latitude and longitude
///
/// Equivalent to `CoreLocation.CLLocationCoordinate2D` when `CoreLocation` can be imported.
public typealias Coordinate = CoreLocation.CLLocationCoordinate2D

extension Coordinate {
    /// Returns `true` if the specified coordinate is valid, `false` otherwise.
    public var isValid: Bool {
        CLLocationCoordinate2DIsValid(self)
    }
}

extension Location {
    public convenience init(latitude: Double, longitude: Double, altitude: Double = .nan) {
        self.init(coordinate: .init(latitude: latitude, longitude: longitude), altitude: altitude, horizontalAccuracy: .nan, verticalAccuracy: .nan, timestamp: Date(timeIntervalSinceReferenceDate: 0))
    }
}

#else // Linux, Windows, etc.

public typealias Degrees = Double

open class Location : Hashable {
    public var coordinate: Coordinate
    public var altitude: Double

    public init(latitude: Double, longitude: Double, altitude: Double = .nan) {
        self.coordinate = Coordinate(latitude: latitude, longitude: longitude)
        self.altitude = altitude
    }

    public static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.coordinate == rhs.coordinate
        && lhs.altitude == rhs.altitude
    }

    public func hash(into hasher: inout Hasher) {
        coordinate.hashValue.hash(into: &hasher)
        altitude.hashValue.hash(into: &hasher)
    }
}

/// An abastraction of a latitude and longitude
///
/// Equivalent to `CoreLocation.CLLocationCoordinate2D` when `CoreLocation` can be imported.
public struct Coordinate : Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

extension Coordinate {
    /// Returns `true` if the specified coordinate is valid, `false` otherwise.
    public var isValid: Bool {
        wip(true) // TODO: validate
    }
}


#endif
