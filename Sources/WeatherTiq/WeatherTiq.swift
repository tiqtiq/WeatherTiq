import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@available(*, deprecated)
func wip<T>(_ item: T) -> T { item }

///
/// `WeatherService` is the entry point into the `WeatherTiq` service.
///
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
open class WeatherService : @unchecked Sendable {

    /// The shared weather service. Use to instantiate one instance of `WeatherService`
    /// for use throughout your application. If finer-grained optimizations are desired, create
    /// separate instances. See the `init` documentation for more details.
    public static let shared: WeatherService = WeatherService(serviceURL: URL(string: "https://api.met.no/weatherapi/locationforecast/2.0/complete")!)

    /// The endpoint for the weather service, defaulting to `"https://api.met.no/weatherapi/locationforecast/2.0/complete"`.
    ///
    /// This URL can be used for routing through a caching proxy, as recommended by https://api.met.no/doc/GettingStarted
    public let serviceURL: URL

    /// The default cache policy is ``URLRequest.CachePolicy.reloadRevalidatingCacheData``, as recommended at https://api.met.no/doc/GettingStarted#cachingdata
    public let cachePolicy: URLRequest.CachePolicy
    public let timeout: TimeInterval
    public let weatherAttribution: WeatherAttribution

    /// The decoder to re-user for parsing
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(serviceURL: URL, cachePolicy: URLRequest.CachePolicy = .reloadRevalidatingCacheData, timeout: TimeInterval = 60, attribution weatherAttribution: WeatherAttribution? = nil) {
        self.serviceURL = serviceURL
        self.cachePolicy = cachePolicy
        self.timeout = timeout

        // the default image URL
        let imgurl = URL(string: "https://www.met.no/en/About-us/logo/_/image/943fbdc6-eba8-4e19-aff1-75f453ba9c7f:4bbfe4ae9e1826b3e159a3fff6e5d3893a93b072/width-768/Met_RGB_Horisontal_ENG.jpg")!

        self.weatherAttribution = weatherAttribution ?? WeatherAttribution(serviceName: "Meteorologisk institutt", legalPageURL: URL(string: "https://api.met.no/doc/License")!, squareMarkURL: imgurl, combinedMarkDarkURL: imgurl, combinedMarkLightURL: imgurl)
    }

    /// The attribution for the data source
    final public var attribution: WeatherAttribution {
        get async throws {
            self.weatherAttribution
        }
    }

    ///
    /// Initializes the weather service. Use for creating different `WeatherService` instances for
    /// optimizations. For instance, may be used to separate out high-priority requests and low-priority
    /// requests for performance. If one instance of `WeatherService` is preferred, see the
    /// `shared` documentation.
    ///
    //    public convenience init()

    ///
    /// Returns the weather forecast for the requested location. Includes all available weather data sets.
    /// - Parameter location: The requested location.
    /// - Throws: Weather data error `WeatherError`
    /// - Returns: The aggregate weather.
    ///
    final public func weather(for location: Location) async throws -> Weather {
        guard var comps = URLComponents(url: self.serviceURL, resolvingAgainstBaseURL: false) else {
            throw WeatherError.unknown
        }
        var qitems = [
            URLQueryItem(name: "lat", value: location.coordinate.latitude.description),
            URLQueryItem(name: "lon", value: location.coordinate.longitude.description)
        ]

        if location.altitude.isNaN == false {
            qitems += [
                URLQueryItem(name: "altitude", value: Int64(location.altitude).description)
            ]
        }

        comps.queryItems = qitems

        guard let url = comps.url else {
            throw WeatherError.unknown
        }

        //print("requesting URL:", url)
        var req = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout)

        // “All requests must (if possible) include an identifying User Agent-string (UA) in the request with the application/domain name, optionally version number.”
        let info = Bundle.main.infoDictionary
        let name = (info?["CFBundleName"] as? String) ?? (info?["CFBundleDisplayName"] as? String) ?? "AppName"
        let version = (info?["CFBundleShortVersionString"] as? String) ?? "unknown"
        let bundleID = (info?["CFBundleIdentifier"] as? String) ?? "unknown"

        let userAgent = "\(name)/\(version) \(bundleID)"
        //print("sending userAgent:", userAgent)
        req.addValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let response = response as? HTTPURLResponse else {
            throw WeatherError.unknown
        }

        guard (200..<300).contains(response.statusCode) else {
            throw WeatherError.badResponse(response.statusCode)
        }

        let forecast = try decoder.decode(METService.JSONForecast.self, from: data)

        let units = forecast.properties.meta.units

        guard let step: METService.ForecastTimeStep = forecast.properties.timeseries.first else {
            throw WeatherError.noCurrentWeather
        }

        guard let inst: METService.ForecastTimeInstant = step.data.instant.details else {
            throw WeatherError.noCurrentWeather
        }

        // use "expires" cache header as recommended by the service
        let headers = response.allHeaderFields

        //dbg("headers:", headers) // headers: [AnyHashable("Date"): Fri, 02 Sep 2022 15:42:25 GMT, AnyHashable("access-control-allow-methods"): GET, AnyHashable("Last-Modified"): Fri, 02 Sep 2022 15:40:17 GMT, AnyHashable("Age"): 128, AnyHashable("x-backend-host"): b_157_249_75_149_loc, AnyHashable("Content-Length"): 4407, AnyHashable("Content-Type"): application/json, AnyHashable("Vary"): Accept, Accept-Encoding, AnyHashable("x-varnish"): 222428042 222351858, AnyHashable("Via"): 1.1 varnish (Varnish/7.0), AnyHashable("Access-Control-Allow-Origin"): *, AnyHashable("Server"): nginx/1.18.0 (Ubuntu), AnyHashable("Content-Encoding"): gzip, AnyHashable("Expires"): Fri, 02 Sep 2022 16:10:19 GMT, AnyHashable("access-control-allow-headers"): Origin, AnyHashable("Accept-Ranges"): bytes]


//        if let modDate = headers["Last-Modified"] as? String {
//        }
//
//        if let expDate = headers["Expires"] as? String {
//        }

        // Expires: "Fri, 02 Sep 2022 16:10:19 GMT"
        let meta = WeatherMetadata(date: step.time, expirationDate: wip(.distantFuture), location: location)

        let nextHour = step.data.next_1_hours
        let next6Hours = step.data.next_6_hours
        let next12Hours = step.data.next_12_hours

        let currentWeather = try CurrentWeather(date: step.time,
                                                cloudCover: inst.cloud_area_fraction ?? .nan,
                                                condition: nextHour?.summary.condition ?? wip(.smoky),
                                                symbolName: nextHour?.summary.condition.symbolName ?? "questionmark",
                                                dewPoint: .init(value: inst.dew_point_temperature ?? .nan, unit: units.dewPointTemperatureUnits),
                                                humidity: inst.relative_humidity ?? .nan,
                                                pressure: .init(value: inst.air_pressure_at_sea_level ?? .nan, unit: units.airPressureAtSeaLevelUnits),
                                                pressureTrend: wip(.rising),
                                                isDaylight: wip(false),
                                                temperature: .init(value: inst.air_temperature ?? .nan, unit: units.airTemperatureUnits),
                                                apparentTemperature: .init(value: inst.air_temperature ?? .nan, unit: units.airTemperatureUnits),
                                                uvIndex: wip(UVIndex(value: 0, category: .moderate)),
                                                visibility: wip(.init(value: .nan, unit: .meters)),
                                                wind: Wind(compassDirection: Wind.CompassDirection.from(degrees: inst.wind_from_direction ?? .nan), direction: .init(value: inst.wind_from_direction ?? .nan, unit: .degrees), speed: .init(value: inst.wind_speed ?? .nan, unit: units.windSpeedUnits)),
                                                metadata: meta)

        let minuteForecast: [MinuteWeather] = []
        let hourlyForecast: [HourWeather] = []
        let dailyForecast: [DayWeather] = []

        let weather = Weather(currentWeather: currentWeather,
                              minuteForecast: .init(forecast: minuteForecast, metadata: meta),
                              hourlyForecast: .init(forecast: hourlyForecast, metadata: meta),
                              dailyForecast: .init(forecast: dailyForecast, metadata: meta),
                              weatherAlerts: nil, // unsupported
                              availability: .init(minuteAvailability: .unknown, alertAvailability: .unsupported))

        return weather
    }

    private static let gmtDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, dd LLL yyyy HH:mm:ss zzz"
        return fmt
    }()

    ///
    /// Returns the weather forecast for the requested location. This is a variadic API in which any
    /// combination of data sets can be requested and returned as a tuple.
    /// - Parameter location: The requested location.
    /// - Throws: Weather data error `WeatherError`
    /// - Returns: The requested weather data set.
    ///
    /// Example usage:
    /// `let current = try await service.weather(for: newYork, including: .current)`
    ///
    final public func weather<T>(for location: Location, including dataSet: WeatherQuery<T>) async throws -> T {
        let w = try await self.weather(for: location)
        return w[keyPath: dataSet.path]
    }

    ///
    /// Returns the weather forecast for the requested location. This is a variadic API in which any
    /// combination of data sets can be requested and returned as a tuple.
    /// - Parameter location: The requested location.
    /// - Throws: Weather data error `WeatherError`
    /// - Returns: The requested weather data sets as a tuple.
    ///
    /// Example usage:
    /// `let (current, minute) = try await service.weather(for: newYork, including: .current, .minute)`
    ///
    final public func weather<T1, T2>(for location: Location, including dataSet1: WeatherQuery<T1>, _ dataSet2: WeatherQuery<T2>) async throws -> (T1, T2) {
        let w = try await self.weather(for: location)
        return (w[keyPath: dataSet1.path], w[keyPath: dataSet2.path])
    }

    final public func weather<T1, T2, T3>(for location: Location, including dataSet1: WeatherQuery<T1>, _ dataSet2: WeatherQuery<T2>, _ dataSet3: WeatherQuery<T3>) async throws -> (T1, T2, T3) {
        let w = try await self.weather(for: location)
        return (w[keyPath: dataSet1.path], w[keyPath: dataSet2.path], w[keyPath: dataSet3.path])
    }

    final public func weather<T1, T2, T3, T4>(for location: Location, including dataSet1: WeatherQuery<T1>, _ dataSet2: WeatherQuery<T2>, _ dataSet3: WeatherQuery<T3>, _ dataSet4: WeatherQuery<T4>) async throws -> (T1, T2, T3, T4) {
        let w = try await self.weather(for: location)
        return (w[keyPath: dataSet1.path], w[keyPath: dataSet2.path], w[keyPath: dataSet3.path], w[keyPath: dataSet4.path])
    }

    final public func weather<T1, T2, T3, T4, T5>(for location: Location, including dataSet1: WeatherQuery<T1>, _ dataSet2: WeatherQuery<T2>, _ dataSet3: WeatherQuery<T3>, _ dataSet4: WeatherQuery<T4>, _ dataSet5: WeatherQuery<T5>) async throws -> (T1, T2, T3, T4, T5) {
        let w = try await self.weather(for: location)
        return (w[keyPath: dataSet1.path], w[keyPath: dataSet2.path], w[keyPath: dataSet3.path], w[keyPath: dataSet4.path], w[keyPath: dataSet5.path])
    }

    final public func weather<T1, T2, T3, T4, T5, T6>(for location: Location, including dataSet1: WeatherQuery<T1>, _ dataSet2: WeatherQuery<T2>, _ dataSet3: WeatherQuery<T3>, _ dataSet4: WeatherQuery<T4>, _ dataSet5: WeatherQuery<T5>, _ dataSet6: WeatherQuery<T6>) async throws -> (T1, T2, T3, T4, T5, T6) {
        let w = try await self.weather(for: location)
        return (w[keyPath: dataSet1.path], w[keyPath: dataSet2.path], w[keyPath: dataSet3.path], w[keyPath: dataSet4.path], w[keyPath: dataSet5.path], w[keyPath: dataSet6.path])
    }
}

extension METService.ForecastSummary {
    /// Translated between `METService.ForecastSummary.WeatherSymbol` and `WeatherTiq.WeatherCondition`
    var condition: WeatherCondition {
        sections.primary
    }

    var sections: (primary: WeatherCondition, secondary: WeatherCondition?, day: Bool?) {
        switch symbol_code {
        case .clearsky_day: return (.clear, nil, true)
        case .clearsky_night: return (.clear, nil, false)
        case .clearsky_polartwilight: return (.clear, nil, nil)

        case .fair_day: return (.clear, nil, true)
        case .fair_night: return (.clear, nil, false)
        case .fair_polartwilight: return (.clear, nil, nil)

        case .lightssnowshowersandthunder_day: return (.snow, .thunderstorms, true)
        case .lightssnowshowersandthunder_night: return (.snow, .thunderstorms, false)
        case .lightssnowshowersandthunder_polartwilight: return (.snow, .thunderstorms, nil)

        case .lightsnowshowers_day: return (.snow, nil, true)
        case .lightsnowshowers_night: return (.snow, nil, false)
        case .lightsnowshowers_polartwilight: return (.snow, nil, nil)

        case .heavyrainandthunder: return (.heavyRain, .thunderstorms, nil)
        case .heavysnowandthunder: return (.heavySnow, .thunderstorms, nil)

        case .rainandthunder: return (.rain, .thunderstorms, nil)

        case .heavysleetshowersandthunder_day: return (.sleet, .thunderstorms, true)
        case .heavysleetshowersandthunder_night: return (.sleet, .thunderstorms, false)
        case .heavysleetshowersandthunder_polartwilight: return (.sleet, .thunderstorms, nil)

        case .heavysnow: return (.heavySnow, .clear, nil)

        case .heavyrainshowers_day: return (.heavyRain, nil, true)
        case .heavyrainshowers_night: return (.heavyRain, nil, false)
        case .heavyrainshowers_polartwilight: return (.heavyRain, nil, nil)

        case .lightsleet: return (.sleet, nil, nil)
        case .heavyrain: return (.heavyRain, nil, nil)

        case .lightrainshowers_day: return (.rain, nil, true)
        case .lightrainshowers_night: return (.rain, nil, false)
        case .lightrainshowers_polartwilight: return (.rain, nil, nil)

        case .heavysleetshowers_day: return (.sleet, nil, true)
        case .heavysleetshowers_night: return (.sleet, nil, false)
        case .heavysleetshowers_polartwilight: return (.sleet, nil, nil)

        case .lightsleetshowers_day: return (.sleet, nil, true)
        case .lightsleetshowers_night: return (.sleet, nil, false)
        case .lightsleetshowers_polartwilight: return (.sleet, nil, nil)

        case .snow: return (.snow, nil, nil)

        case .heavyrainshowersandthunder_day: return (.heavyRain, .thunderstorms, true)
        case .heavyrainshowersandthunder_night: return (.heavyRain, .thunderstorms, false)
        case .heavyrainshowersandthunder_polartwilight: return (.heavyRain, .thunderstorms, nil)

        case .snowshowers_day: return (.snow, nil, true)
        case .snowshowers_night: return (.snow, nil, false)
        case .snowshowers_polartwilight: return (.snow, nil, nil)

        case .fog: return (.foggy, nil, nil)

        case .snowshowersandthunder_day: return (.snow, .thunderstorms, true)
        case .snowshowersandthunder_night: return (.snow, .thunderstorms, false)
        case .snowshowersandthunder_polartwilight: return (.snow, .thunderstorms, nil)

        case .lightsnowandthunder: return (.snow, .thunderstorms, nil)
        case .heavysleetandthunder: return (.sleet, .thunderstorms, nil)
            
        case .lightrain: return (.rain, nil, nil)

        case .rainshowersandthunder_day: return (.rain, .thunderstorms, true)
        case .rainshowersandthunder_night: return (.rain, .thunderstorms, false)
        case .rainshowersandthunder_polartwilight: return (.rain, .thunderstorms, nil)

        case .rain: return (.rain, nil, nil)
        case .lightsnow: return (.snow, nil, nil)

        case .lightrainshowersandthunder_day: return (.rain, .thunderstorms, true)
        case .lightrainshowersandthunder_night: return (.rain, .thunderstorms, false)
        case .lightrainshowersandthunder_polartwilight: return (.rain, .thunderstorms, nil)

        case .heavysleet: return (.sleet, nil, nil)
        case .sleetandthunder: return (.sleet, .thunderstorms, nil)
        case .lightrainandthunder: return (.rain, .thunderstorms, nil)
        case .sleet: return (.sleet, nil, nil)

        case .lightssleetshowersandthunder_day: return (.sleet, .thunderstorms, true)
        case .lightssleetshowersandthunder_night: return (.sleet, .thunderstorms, false)
        case .lightssleetshowersandthunder_polartwilight: return (.sleet, .thunderstorms, nil)

        case .lightsleetandthunder: return (.sleet, .thunderstorms, nil)

        case .partlycloudy_day: return (.partlyCloudy, nil, true)
        case .partlycloudy_night: return (.partlyCloudy, nil, false)
        case .partlycloudy_polartwilight: return (.partlyCloudy, nil, nil)

        case .sleetshowersandthunder_day: return (.sleet, .thunderstorms, true)
        case .sleetshowersandthunder_night: return (.sleet, .thunderstorms, false)
        case .sleetshowersandthunder_polartwilight: return (.sleet, .thunderstorms, nil)

        case .rainshowers_day: return (.rain, nil, true)
        case .rainshowers_night: return (.rain, nil, false)
        case .rainshowers_polartwilight: return (.rain, nil, nil)

        case .snowandthunder: return (.snow, .thunderstorms, nil)

        case .sleetshowers_day: return (.sleet, nil, true)
        case .sleetshowers_night: return (.sleet, nil, false)
        case .sleetshowers_polartwilight: return (.sleet, nil, nil)

        case .cloudy: return (.cloudy, nil, nil)

        case .heavysnowshowersandthunder_day: return (.heavySnow, .thunderstorms, true)
        case .heavysnowshowersandthunder_night: return (.heavySnow, .thunderstorms, false)
        case .heavysnowshowersandthunder_polartwilight: return (.heavySnow, .thunderstorms, nil)

        case .heavysnowshowers_day: return (.heavySnow, nil, true)
        case .heavysnowshowers_night: return (.heavySnow, nil, false)
        case .heavysnowshowers_polartwilight: return (.heavySnow, nil, nil)
        }
    }
}

// MARK: Weather Models

///
/// A structure that provides additional weather information.
///
/// Metadata information includes the location, date of the request, the date the data will expire, and required provider attribution.
///
public struct WeatherMetadata : Equatable, Codable {

    /// The date of the weather data request.
    public var date: Date

    /// The time the weather data expires.
    public var expirationDate: Date

    private var latitude, longitude, altitude: Double

    /// The location of the request.
    public var location: Location {
        // this is created dynamically because Location = CoreLocation.CLLocation is not codable
        Location(latitude: latitude, longitude: longitude, altitude: altitude)
    }

    public init(date: Date, expirationDate: Date, location: Location) {
        self.date = date
        self.expirationDate = expirationDate
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
    }
}

///
/// A structure that encapsulates a generic weather dataset request.
///
///  Use the properties of this structure to create a weather query. You can combine multiple weather queries into a single ``WeatherService`` request.
///
/// `let (hourly, daily, alerts) = try await service.weather(for: newYork, including: .hourly, .daily, .alerts)`
///
public struct WeatherQuery<T> {
    fileprivate let path: KeyPath<Weather, T>
    fileprivate var startDate: Date? = nil
    fileprivate var endDate: Date? = nil

    /// The current weather query.
    public static var current: WeatherQuery<CurrentWeather> { .init(path: \.currentWeather) }

    /// The minute forecast query.
    public static var minute: WeatherQuery<Forecast<MinuteWeather>?> { .init(path: \.minuteForecast) }

    /// The hourly forecast query.
    public static var hourly: WeatherQuery<Forecast<HourWeather>> { .init(path: \.hourlyForecast) }

    /// The daily forecast query.
    public static var daily: WeatherQuery<Forecast<DayWeather>> { .init(path: \.dailyForecast) }

    /// The weather alerts query.
    public static var alerts: WeatherQuery<[WeatherAlert]?> { .init(path: \.weatherAlerts) }

    /// The availability query.
    public static var availability: WeatherQuery<WeatherAvailability> { .init(path: \.availability) }
}

extension WeatherQuery where T == Forecast<DayWeather> {
    /// The daily forecast query that takes a start date and end date for the request.
    public static func daily(startDate: Date, endDate: Date) -> WeatherQuery<T> {
        .init(path: \.dailyForecast, startDate: startDate, endDate: endDate)
    }
}

extension WeatherQuery where T == Forecast<HourWeather> {
    /// The hourly forecast query that takes a start date and end date for the request.
    public static func hourly(startDate: Date, endDate: Date) -> WeatherQuery<T> {
        .init(path: \.hourlyForecast, startDate: startDate, endDate: endDate)
    }
}

///
/// An error WeatherTiq returns.
///
public enum WeatherError : LocalizedError, Hashable {

    /// An error indicating permission denied.
    case permissionDenied

    /// An unknown error.
    case unknown

    case unsupportedVersion

    case badResponse(Int)

    case noCurrentWeather

    case badUnit(String, String?)

    case badDirection(Double)

//    /// A localized message describing what error occurred.
//    public var errorDescription: String? {
//        fatalError(wip("TODO"))
//    }
//
//    /// A localized message describing the reason for the failure.
//    public var failureReason: String? {
//        fatalError(wip("TODO"))
//    }
//
//    /// A localized message providing text if the user requests help.
//    public var helpAnchor: String? {
//        fatalError(wip("TODO"))
//    }
//
//    /// A localized message describing how to recover from the failure.
//    public var recoverySuggestion: String? {
//        fatalError(wip("TODO"))
//    }
}

/// A structure that describes the current conditions observed at the requested location.
///
/// The current conditions may not be a literal observation, but rather the result of a mathematical weather model predicting
/// conditions based on real observations.
///
public struct CurrentWeather : Equatable, Codable {

    /// The date of the current weather.
    public var date: Date

    /// Fraction of cloud cover, from 0 to 1. Cloud cover describes the fraction of
    /// sky obscured by clouds when observed from a given location.
    public var cloudCover: Double

    /// A description of the current weather condition.
    public var condition: WeatherCondition

    /// The SF Symbol icon that represents the current weather condition and whether it's
    /// daylight at the current date.
    public var symbolName: String

    /// The amount of moisture in the air.
    ///
    /// Dew point is the temperature at which air is saturated with water vapor.
    public var dewPoint: Measurement<UnitTemperature>

    /// The amount of water vapor in the air.
    ///
    /// Relative humidity measures the amount of water vapor in the air compared to the maximum amount that the air could normally hold at the current temperature.
    ///
    /// The range of this property is from 0 to 1, inclusive.
    public var humidity: Double

    /// The atmospheric pressure at sea level at a given location.
    ///
    /// This is a reduced pressure calculated by using observed conditions to remove the effects of elevation
    /// from pressure readings.
    public var pressure: Measurement<UnitPressure>

    /// The pressure trend, or barometric tendency, is the kind and amount of atmospheric pressure
    /// change over time.
    public var pressureTrend: PressureTrend

    /// The presence or absence of daylight at the requested location and current time.
    public var isDaylight: Bool

    /// The current temperature.
    public var temperature: Measurement<UnitTemperature>

    /// The apparent, or "feels like" temperature.
    public var apparentTemperature: Measurement<UnitTemperature>

    /// The expected intensity of ultraviolet radiation from the sun.
    public var uvIndex: UVIndex

    /// The distance at which an object can be clearly seen.
    ///
    /// The amount of light, and weather conditions like fog, mist, and smog affect visibility.
    public var visibility: Measurement<UnitLength>

    /// The wind speed, direction, and gust.
    public var wind: Wind

    /// The current weather metadata.
    public var metadata: WeatherMetadata
}

///
/// A structure that represents the weather conditions for the day.
///
public struct DayWeather : Equatable, Codable {

    /// The start date of the day weather.
    public var date: Date

    /// A description of the weather condition on this day.
    public var condition: WeatherCondition

    /// The SF Symbol icon that represents the day weather condition. Returns daytime symbol names.
    public var symbolName: String

    /// The daytime high temperature.
    public var highTemperature: Measurement<UnitTemperature>

    /// The overnight low temperature.
    public var lowTemperature: Measurement<UnitTemperature>

    /// Description of precipitation for this day.
    public var precipitation: Precipitation

    /// The probability of precipitation during the day, from 0 to 1.
    public var precipitationChance: Double

    /// The amount of rainfall for the day.
    public var rainfallAmount: Measurement<UnitLength>

    /// The amount of snowfall for the day.
    public var snowfallAmount: Measurement<UnitLength>

    /// The solar events for the day.
    public var sun: SunEvents

    /// The lunar events for the day.
    public var moon: MoonEvents

    /// The UV index provides the expected intensity of ultraviolet radiation from the sun.
    public var uvIndex: UVIndex

    /// Contains wind data of speed, bearing (direction), gust.
    public var wind: Wind
}

///
/// A forecast collection for minute, hourly, and daily forecasts.
///
/// ``Forecast`` conforms to the ``RandomAccessCollection`` protocol to support efficient random-access index traversal through
/// forecast types. The protocol involves forwarding the required properties
/// and methods to the underlying forecast collection. The implementation of `subscript` returns an
/// instance of the ``Element`` type.
///
public struct Forecast<Element> : Codable, Equatable where Element : Decodable, Element : Encodable, Element : Equatable {

    /// The forecast collection.
    public var forecast: [Element]

    /// The forecast metadata.
    public var metadata: WeatherMetadata
}

extension Forecast : RandomAccessCollection {
    /// The forecast index.
    public typealias Index = Int

    /// The forecast start index.
    public var startIndex: Forecast<Element>.Index {
        forecast.startIndex
    }

    /// The forecast end index.
    public var endIndex: Forecast<Element>.Index {
        forecast.endIndex
    }

    /// The forecast element at the provided index.
    public subscript(position: Forecast<Element>.Index) -> Element {
        forecast[position]
    }


    /// A type that represents the indices that are valid for subscripting the
    /// collection, in ascending order.
    public typealias Indices = Range<Forecast<Element>.Index>

    /// A type that provides the collection's iteration interface and
    /// encapsulates its iteration state.
    ///
    /// By default, a collection conforms to the `Sequence` protocol by
    /// supplying `IndexingIterator` as its associated `Iterator`
    /// type.
    public typealias Iterator = IndexingIterator<Forecast<Element>>

    /// A collection representing a contiguous subrange of this collection's
    /// elements. The subsequence shares indices with the original collection.
    ///
    /// The default subsequence type for collections that don't define their own
    /// is `Slice`.
    public typealias SubSequence = Slice<Forecast<Element>>
}

extension Forecast : DayForecastSPI where Element == DayWeather {
}

extension Forecast : HourForecastSPI where Element == HourWeather {
}

extension Forecast : MinuteForecastSPI where Element == MinuteWeather {

    /// A convenient localized description of the minute forecast.
    ///
    public var summary: String {
        wip(self.forecast.description)
    }
}

extension Forecast {
}

extension Forecast where Element == HourWeather {
}

extension Forecast where Element == DayWeather {
}

///
/// A structure that represents the weather conditions for the hour.
///
public struct HourWeather : Equatable, Codable {

    /// The start date of the hour weather.
    public var date: Date

    /// Fraction of cloud cover, from 0 to 1. Cloud cover describes the fraction of
    /// sky obscured by clouds when observed from a given location.
    public var cloudCover: Double

    /// A description of the weather condition for this hour.
    public var condition: WeatherCondition

    /// The SF Symbol icon that represents the hour weather condition and whether it's daylight on the hour.
    public var symbolName: String

    /// The dew point, which describes the amount of moisture in the air, is the temperature at which air
    /// is saturated with water vapor.
    public var dewPoint: Measurement<UnitTemperature>

    /// The humidity for the hour, from 0 to 1, inclusive. Relative humidity measures the amount of
    /// water vapor in the air compared to the maximum amount that the air could normally
    /// hold at the current temperature.
    public var humidity: Double

    /// The presence or absence of daylight at the requested location and hour.
    public var isDaylight: Bool

    /// Description of precipitation for this hour.
    public var precipitation: Precipitation

    /// The probability of precipitation during the hour, from 0 to 1.
    public var precipitationChance: Double

    /// The amount of precipitation for the hour. This value refers to the liquid equivalent of all
    /// precipitation amounts.
    public var precipitationAmount: Measurement<UnitLength>

    /// The sea level pressure, which describes the atmospheric pressure at sea level at a given location.
    /// It is a reduced pressure calculated by using observed conditions to remove the effects of elevation
    /// from pressure readings.
    public var pressure: Measurement<UnitPressure>

    /// The pressure trend, or barometric tendency, is the kind and amount of atmospheric pressure
    /// change over time.
    public var pressureTrend: PressureTrend

    /// The temperature during the hour.
    public var temperature: Measurement<UnitTemperature>

    /// The apparent or "feels like" temperature during the hour.
    public var apparentTemperature: Measurement<UnitTemperature>

    /// The UV index provides the expected intensity of ultraviolet radiation from the sun.
    public var uvIndex: UVIndex

    /// The visibility for the hour. Visibility is the distance at which an object can be clearly seen
    /// and is affected by the amount of light and weather conditions like fog, mist, and smog.
    public var visibility: Measurement<UnitLength>

    /// Contains wind data describing the wind speed, direction, and gust.
    public var wind: Wind
}

///
/// A structure that represents the next hour minute forecasts.
///
public struct MinuteWeather : Equatable, Codable {

    /// The start date of the minute weather.
    public var date: Date

    /// Description of precipitation for this minute.
    public var precipitation: Precipitation

    /// Probability of precipitation in this minute from 0.0 to 1.0.
    public var precipitationChance: Double

    /// Forecasted precipitation intensity in km/hr.
    public var precipitationIntensity: Measurement<UnitSpeed>
}

///
/// A structure that represents lunar events, including the moon phase, moonrise, and moonset.
///
public struct MoonEvents : Equatable, Codable {

    /// The moon phase.
    public var phase: MoonPhase

    /// The date of moonrise. Moonrise occurs when the moon first appears above Earth’s horizon.
    public var moonrise: Date?

    /// The date of moonset.
    ///
    /// Moonset occurs when the moon sets below Earth's horizon.
    public var moonset: Date?
}

///
/// An enumeration that represents dates of solar events, including sunrise, sunset, dawn, and dusk.
///
public struct SunEvents : Equatable, Codable {

    /// The time of astronomical sunrise when the sun’s center is 18° below the horizon.
    ///
    /// A small portion
    /// of the sun's rays begin to illuminate the sky and stars begin to disappear. This property is
    /// optional because it's possible for the sun to not rise on a given day, at extreme latitudes.
    public var astronomicalDawn: Date?

    /// The time of nautical sunrise when the sun’s center is 12° below the horizon.
    ///
    /// There is enough light
    /// for sailors to distinguish the horizon at sea, but the sky is too dark for outdoor activities. This
    /// property is optional because it's possible for the sun to not rise on a given day, at extreme latitudes.
    public var nauticalDawn: Date?

    /// The time of civil sunrise when the sun’s center is 6° below the horizon.
    ///
    /// Civil dawn begins when
    /// there's enough light for most objects to be seen, so it's often used to determine when outdoor
    /// activities may begin. This property is optional because it's possible for the sun to not rise on a
    /// given day, at extreme latitudes.
    public var civilDawn: Date?

    /// The sunrise time immediately before the solar transit closest to calendar noon.
    ///
    /// This property is
    /// optional because it's possible for the sun to not rise on a given day, at extreme latitudes. That calendar noon is used as a reference point due to variations in frequency of solar events at
    /// extreme latitudes.
    public var sunrise: Date?

    /// Represents solar noon, the time when the sun reaches its highest point in the sky.
    ///
    /// It may or
    /// may not be above the horizon at this time due to variations of solar events at extreme latitudes.
    /// If the highest point isn't above the horizon, this property is ``nil``.
    public var solarNoon: Date?

    /// The sunset time immediately after the solar transit closest to calendar noon.
    ///
    /// This property is
    /// optional because it's possible for the sun to not set on a given day, at extreme latitudes. That calendar noon is used as a reference point due to variations in frequency of solar events at
    /// extreme latitudes.
    public var sunset: Date?

    /// The time of civil sunset, when the sun’s center is 6° below the horizon.
    ///
    /// The sky is often colored
    /// orange or red, and objects are typically distinguishable. Beyond civil dusk, artificial light may be
    /// needed for outdoor activities, depending on weather conditions. This property is optional because
    /// it's possible for the sun to not set on a given day, at extreme latitudes.
    public var civilDusk: Date?

    /// The time of nautical sunset, when the sun’s center is 12° below the horizon.
    ///
    /// This property is
    /// optional because it's possible for the sun to not set on a given day, at extreme latitudes. At nautical
    /// dusk, most stars become visible, and in clear weather conditions the horizon is visible.
    public var nauticalDusk: Date?

    /// The time of astronomical sunset, when the sun’s center is 18° below the horizon.
    ///
    /// The sun no
    /// longer illuminates the sky, and does not interfere with astronomical observations. This property is
    /// optional because it's possible for the sun to not set on a given day, at extreme latitudes.
    public var astronomicalDusk: Date?

    /// Represents solar midnight, the time when the sun reaches its lowest point in the sky.
    ///
    /// It may or
    /// may not be above the horizon at this time due to variations of solar events at extreme latitudes.
    /// If the lowest point is not below the horizon, this property is ``nil``.
    public var solarMidnight: Date?
}

///
/// The expected intensity of ultraviolet radiation from the sun.
///
public struct UVIndex : Equatable, Codable {

    /// The UV Index value.
    public var value: Int

    /// The UV Index exposure category.
    public var category: UVIndex.ExposureCategory

    ///
    /// An enumeration that indicates risk of harm from unprotected sun exposure.
    ///
    public enum ExposureCategory : String, Codable, Comparable, CustomStringConvertible, CaseIterable, Hashable, Sendable {

        /// The UV index is low.
        ///
        /// The valid values of this property are 0, 1, and 2.
        case low

        /// The UV index is moderate.
        ///
        /// The valid values of this property are 3, 4, and 5.
        case moderate

        /// The UV index is high.
        ///
        /// The valid values of this property are 6 and 7.
        case high

        /// The UV index is very high.
        ///
        /// The valid values of this property are 8, 9, and 10.
        case veryHigh

        /// The UV index is extreme.
        ///
        /// The valid values of this property are 11 and higher.
        case extreme

        /// The range of UV index values that falls into this category.
        public var rangeValue: ClosedRange<Int> {
            switch self {
            case .low: return 0...2
            case .moderate: return 3...5
            case .high: return 6...7
            case .veryHigh: return 8...10
            case .extreme: return 11...(.max)

            }
        }

        /// The localized string describing the risk of harm from unprotected sun exposure.
        public var description: String {
            switch self {
            case .low: return NSLocalizedString("Low", bundle: .module, comment: "ExposureCategory description for: low")
            case .moderate: return NSLocalizedString("Moderate", bundle: .module, comment: "ExposureCategory description for: moderate")
            case .high: return NSLocalizedString("High", bundle: .module, comment: "ExposureCategory description for: high")
            case .veryHigh: return NSLocalizedString("Very High", bundle: .module, comment: "ExposureCategory description for: veryHigh")
            case .extreme: return NSLocalizedString("Extreme", bundle: .module, comment: "ExposureCategory description for: extreme")
            }
        }

        /// A localized accessibility description describing the UV Index Exposure Category,
        /// suitable for Voice Over and other assistive technologies.
        public var accessibilityDescription: String {
            description
        }

        public static func < (lhs: UVIndex.ExposureCategory, rhs: UVIndex.ExposureCategory) -> Bool {
            lhs.numericValue < rhs.numericValue
        }

        private var numericValue: Int {
            switch self {
            case .low: return 0
            case .moderate: return 1
            case .high: return 2
            case .veryHigh: return 3
            case .extreme: return 4
            }
        }
    }
}

///
/// Wrapper model representing the aggregate weather data requested by the caller.
///
public struct Weather : Equatable, Codable {

    /// The current weather forecast.
    public var currentWeather: CurrentWeather

    /// The minute-by-minute forecast. Optional due to unsupported regions and availability of data.
    public var minuteForecast: Forecast<MinuteWeather>?

    /// The hourly forecast.
    public var hourlyForecast: Forecast<HourWeather>

    /// The daily forecast.
    public var dailyForecast: Forecast<DayWeather>

    /// The severe weather alerts.
    public var weatherAlerts: [WeatherAlert]?

    /// The flags containing information about data availability and attribution.
    public var availability: WeatherAvailability
}


///
/// A weather alert issued for the requested  location by a governmental authority.
///
/// Weather alerts often contains severe weather information; however, not all alerts are severe. Alerts may or may not contain localized descriptions, depending on what is available from the
/// source. Due to data source restrictions, information contained is served raw.
///
public struct WeatherAlert : Equatable, Codable {

    /// The site for more details about the weather alert. Required link for attribution.
    public var detailsURL: URL

    /// The name of the source issuing the weather alert. Required to display for attribution.
    public var source: String

    /// The summary of the event type.
    ///
    /// The summary may or may not contain localized descriptions, depending on what is available from the source.
    public var summary: String

    /// The name of the affected area.
    public var region: String?

    /// The severity of the weather alert.
    public var severity: WeatherSeverity

    /// The current weather metadata.
    public var metadata: WeatherMetadata
}

/// A structure that  defines the necessary information for attributing a weather data provider.
///
/// Attribution is required for publishing software using WeatherTiq.
///
public struct WeatherAttribution : Equatable, Codable {
    /// The weather data provider name.
    public var serviceName: String

    /// A link to the legal attribution page that contains copyright information
    /// about the weather data sources.
    public var legalPageURL: URL

    /// A URL for the square mark.
    public var squareMarkURL: URL

    /// A URL for the combined "<logo>" mark, in dark variant.
    public var combinedMarkDarkURL: URL

    /// A URL for the combined "<logo>" mark, in light variant.
    public var combinedMarkLightURL: URL

    public init(serviceName: String, legalPageURL: URL, squareMarkURL: URL, combinedMarkDarkURL: URL, combinedMarkLightURL: URL) {
        self.serviceName = serviceName
        self.legalPageURL = legalPageURL
        self.squareMarkURL = squareMarkURL
        self.combinedMarkDarkURL = combinedMarkDarkURL
        self.combinedMarkLightURL = combinedMarkLightURL
    }
}

/// A structure that indicates the availability of data at the requested location.
///
/// `WeatherAvailability` represents the availability of data at the requested location.
/// Weather alerts, or minute forecast data may be temporarily unavailable from
/// the data provider, or unsupported in some regions. Other data sets are expected
/// to be supported for all geographic locations, for example, current weather,
/// and therefore are not included in `WeatherAvailability`.
///
public struct WeatherAvailability : Equatable, Codable {

    /// The minute forecast availability.
    public var minuteAvailability: WeatherAvailability.AvailabilityKind

    /// The weather alerts availability.
    public var alertAvailability: WeatherAvailability.AvailabilityKind

    /// The availability kind.
    public enum AvailabilityKind : String, Codable, Hashable {

        /// The data is available.
        case available

        /// The data is supported for the location but is temporarily unavailable.
        case temporarilyUnavailable

        /// The data isn't supported for the location.
        case unsupported

        case unknown
    }
}

///
/// Contains wind data of speed, direction, and gust.
///
public struct Wind: Equatable, Codable {

    /// General indicator of wind direction, often referred to as "due north", "due south", etc.
    /// Refers to the direction the wind is coming from, for instance, a north wind blows from
    /// north to south.
    public var compassDirection: Wind.CompassDirection

    /// Direction the wind is coming from in degrees, with true north at 0 and progressing clockwise from north.
    public var direction: Measurement<UnitAngle>

    /// Sustained wind speed.
    public var speed: Measurement<UnitSpeed>

    /// Wind gust speed, or the sudden increase in wind speed due to friction, wind shear, or by heating.
    public var gust: Measurement<UnitSpeed>?

    /// Specifies the 16-wind compass rose composed of the cardinal directions—north, east, south, and
    /// west—and its intercardinal directions. `Wind.CompassDirection` represents true headings.
    /// It's the direction the wind is coming from in degrees, measured clockwise from true north.
    public enum CompassDirection : String, Codable, CaseIterable, CustomStringConvertible, Hashable, Sendable {
        case north
        case northNortheast
        case northeast
        case eastNortheast
        case east
        case eastSoutheast
        case southeast
        case southSoutheast
        case south
        case southSouthwest
        case southwest
        case westSouthwest
        case west
        case westNorthwest
        case northwest
        case northNorthwest

        ///
        /// The short abbreviation of the wind compass direction, e.g. .north is "N".
        ///
        public var abbreviation: String {
            switch self {
            case .north: return NSLocalizedString("N", bundle: .module, comment: "CompassDirection abbreviation for: north")
            case .northNortheast: return NSLocalizedString("NNE", bundle: .module, comment: "CompassDirection abbreviation for: northNortheast")
            case .northeast: return NSLocalizedString("NE", bundle: .module, comment: "CompassDirection abbreviation for: northeast")
            case .eastNortheast: return NSLocalizedString("ENE", bundle: .module, comment: "CompassDirection abbreviation for: eastNortheast")
            case .east: return NSLocalizedString("E", bundle: .module, comment: "CompassDirection abbreviation for: east")
            case .eastSoutheast: return NSLocalizedString("ESE", bundle: .module, comment: "CompassDirection abbreviation for: eastSoutheast")
            case .southeast: return NSLocalizedString("SE", bundle: .module, comment: "CompassDirection abbreviation for: southeast")
            case .southSoutheast: return NSLocalizedString("SSE", bundle: .module, comment: "CompassDirection abbreviation for: southSoutheast")
            case .south: return NSLocalizedString("S", bundle: .module, comment: "CompassDirection abbreviation for: south")
            case .southSouthwest: return NSLocalizedString("SSW", bundle: .module, comment: "CompassDirection abbreviation for: southSouthwest")
            case .southwest: return NSLocalizedString("SW", bundle: .module, comment: "CompassDirection abbreviation for: southwest")
            case .westSouthwest: return NSLocalizedString("WSW", bundle: .module, comment: "CompassDirection abbreviation for: westSouthwest")
            case .west: return NSLocalizedString("W", bundle: .module, comment: "CompassDirection abbreviation for: west")
            case .westNorthwest: return NSLocalizedString("WNW", bundle: .module, comment: "CompassDirection abbreviation for: westNorthwest")
            case .northwest: return NSLocalizedString("NW", bundle: .module, comment: "CompassDirection abbreviation for: northwest")
            case .northNorthwest: return NSLocalizedString("NNW", bundle: .module, comment: "CompassDirection abbreviation for: northNorthwest")
            }
        }

        /// Localized string describing the wind compass direction. Represents the direction the
        /// wind is coming from.
        public var description: String {
            switch self {
            case .north: return NSLocalizedString("North", bundle: .module, comment: "CompassDirection description for: north")
            case .northNortheast: return NSLocalizedString("North Northeast", bundle: .module, comment: "CompassDirection description for: northNortheast")
            case .northeast: return NSLocalizedString("Northeast", bundle: .module, comment: "CompassDirection description for: northeast")
            case .eastNortheast: return NSLocalizedString("East Northeast", bundle: .module, comment: "CompassDirection description for: eastNortheast")
            case .east: return NSLocalizedString("East", bundle: .module, comment: "CompassDirection description for: east")
            case .eastSoutheast: return NSLocalizedString("East Southeast", bundle: .module, comment: "CompassDirection description for: eastSoutheast")
            case .southeast: return NSLocalizedString("Southeast", bundle: .module, comment: "CompassDirection description for: southeast")
            case .southSoutheast: return NSLocalizedString("South Southeast", bundle: .module, comment: "CompassDirection description for: southSoutheast")
            case .south: return NSLocalizedString("South", bundle: .module, comment: "CompassDirection description for: south")
            case .southSouthwest: return NSLocalizedString("South Southwest", bundle: .module, comment: "CompassDirection description for: southSouthwest")
            case .southwest: return NSLocalizedString("Southwest", bundle: .module, comment: "CompassDirection description for: southwest")
            case .westSouthwest: return NSLocalizedString("West Southwest", bundle: .module, comment: "CompassDirection description for: westSouthwest")
            case .west: return NSLocalizedString("West", bundle: .module, comment: "CompassDirection description for: west")
            case .westNorthwest: return NSLocalizedString("West Northwest", bundle: .module, comment: "CompassDirection description for: westNorthwest")
            case .northwest: return NSLocalizedString("Northwest", bundle: .module, comment: "CompassDirection description for: northwest")
            case .northNorthwest: return NSLocalizedString("North Northwest", bundle: .module, comment: "CompassDirection description for: northNorthwest")
            }
        }

        ///
        /// A description of the wind compass direction suitable for use in accessibility strings for
        /// Voice Over and other assistive technologies, e.g. .northNortheast is "North Northeast".
        ///
        public var accessibilityDescription: String {
            description
        }

        static func from(degrees: Double) throws -> CompassDirection {
            func seg(_ index: Double) -> Range<Double> {
                let s = 360 / 16.0
                return ((s*index)-(s/2))..<((s*(index+1))-(s/2))
            }

            switch degrees {
            case seg(0): return .north
            case seg(1): return .northNortheast
            case seg(2): return .northeast
            case seg(3): return .eastNortheast
            case seg(4): return .east
            case seg(5): return .eastSoutheast
            case seg(6): return .southeast
            case seg(7): return .southSoutheast
            case seg(8): return .south
            case seg(9): return .southSouthwest
            case seg(10): return .southwest
            case seg(11): return .westSouthwest
            case seg(12): return .west
            case seg(13): return .westNorthwest
            case seg(14): return .northwest
            case seg(15): return .northNorthwest
            case seg(16): return .north
            default: throw WeatherError.badDirection(degrees)
            }
        }
    }
}


// MARK: Enumerations

///
/// A description of the current weather condition.
///
public enum WeatherCondition : String, CaseIterable, CustomStringConvertible, Hashable, Codable {
    case blizzard
    case blowingDust
    case blowingSnow
    case breezy
    case clear
    case cloudy
    case drizzle
    case flurries
    case foggy
    case freezingDrizzle
    case freezingRain
    case frigid
    case hail
    case haze
    case heavyRain
    case heavySnow
    case hot
    case hurricane
    case isolatedThunderstorms
    case mostlyClear
    case mostlyCloudy
    case partlyCloudy
    case rain
    case scatteredThunderstorms
    case sleet
    case smoky
    case snow
    case strongStorms
    case sunFlurries
    case sunShowers
    case thunderstorms
    case tropicalStorm
    case windy
    case wintryMix

    /// Standard string describing the current condition.
    public var description: String {
        localizedDescription
    }

    /// Standard string describing the current condition.
    public var localizedDescription: String {
        switch self {
        case .blizzard: return NSLocalizedString("Blizzard", bundle: .module, comment: "WeatherCondition description for: blizzard")
        case .blowingDust: return NSLocalizedString("Blowing Dust", bundle: .module, comment: "WeatherCondition description for: blowingDust")
        case .blowingSnow: return NSLocalizedString("Blowing Snow", bundle: .module, comment: "WeatherCondition description for: blowingSnow")
        case .breezy: return NSLocalizedString("Breezy", bundle: .module, comment: "WeatherCondition description for: breezy")
        case .clear: return NSLocalizedString("Clear", bundle: .module, comment: "WeatherCondition description for: clear")
        case .cloudy: return NSLocalizedString("Cloudy", bundle: .module, comment: "WeatherCondition description for: cloudy")
        case .drizzle: return NSLocalizedString("Drizzle", bundle: .module, comment: "WeatherCondition description for: drizzle")
        case .flurries: return NSLocalizedString("Flurries", bundle: .module, comment: "WeatherCondition description for: flurries")
        case .foggy: return NSLocalizedString("Foggy", bundle: .module, comment: "WeatherCondition description for: foggy")
        case .freezingDrizzle: return NSLocalizedString("Freezing Drizzle", bundle: .module, comment: "WeatherCondition description for: freezingDrizzle")
        case .freezingRain: return NSLocalizedString("Freezing Rain", bundle: .module, comment: "WeatherCondition description for: freezingRain")
        case .frigid: return NSLocalizedString("Frigid", bundle: .module, comment: "WeatherCondition description for: frigid")
        case .hail: return NSLocalizedString("Hail", bundle: .module, comment: "WeatherCondition description for: hail")
        case .haze: return NSLocalizedString("Haze", bundle: .module, comment: "WeatherCondition description for: haze")
        case .heavyRain: return NSLocalizedString("Heavy Rain", bundle: .module, comment: "WeatherCondition description for: heavyRain")
        case .heavySnow: return NSLocalizedString("Heavy Snow", bundle: .module, comment: "WeatherCondition description for: heavySnow")
        case .hot: return NSLocalizedString("Hot", bundle: .module, comment: "WeatherCondition description for: hot")
        case .hurricane: return NSLocalizedString("Hurricane", bundle: .module, comment: "WeatherCondition description for: hurricane")
        case .isolatedThunderstorms: return NSLocalizedString("Isolated Thunderstorms", bundle: .module, comment: "WeatherCondition description for: isolatedThunderstorms")
        case .mostlyClear: return NSLocalizedString("Mostly Clear", bundle: .module, comment: "WeatherCondition description for: mostlyClear")
        case .mostlyCloudy: return NSLocalizedString("Mostly Cloudy", bundle: .module, comment: "WeatherCondition description for: mostlyCloudy")
        case .partlyCloudy: return NSLocalizedString("Partly Cloudy", bundle: .module, comment: "WeatherCondition description for: partlyCloudy")
        case .rain: return NSLocalizedString("Rain", bundle: .module, comment: "WeatherCondition description for: rain")
        case .scatteredThunderstorms: return NSLocalizedString("Scattered Thunderstorms", bundle: .module, comment: "WeatherCondition description for: scatteredThunderstorms")
        case .sleet: return NSLocalizedString("Sleet", bundle: .module, comment: "WeatherCondition description for: sleet")
        case .smoky: return NSLocalizedString("Smoky", bundle: .module, comment: "WeatherCondition description for: smoky")
        case .snow: return NSLocalizedString("Snow", bundle: .module, comment: "WeatherCondition description for: snow")
        case .strongStorms: return NSLocalizedString("Strong Storms", bundle: .module, comment: "WeatherCondition description for: strongStorms")
        case .sunFlurries: return NSLocalizedString("Sun Flurries", bundle: .module, comment: "WeatherCondition description for: sunFlurries")
        case .sunShowers: return NSLocalizedString("Sun Showers", bundle: .module, comment: "WeatherCondition description for: sunShowers")
        case .thunderstorms: return NSLocalizedString("Thunderstorms", bundle: .module, comment: "WeatherCondition description for: thunderstorms")
        case .tropicalStorm: return NSLocalizedString("Tropical Storm", bundle: .module, comment: "WeatherCondition description for: tropicalStorm")
        case .windy: return NSLocalizedString("Windy", bundle: .module, comment: "WeatherCondition description for: windy")
        case .wintryMix: return NSLocalizedString("Wintry Mix", bundle: .module, comment: "WeatherCondition description for: wintryMix")
        }
    }

    var symbolName: String {
        switch self {
        case .blizzard: return "cloud.snow"
        case .blowingDust: return "sun.dust"
        case .blowingSnow: return "cloud.snow"
        case .breezy: return "wind"
        case .clear: return "sun.max"
        case .cloudy: return "cloud"
        case .drizzle: return "cloud.drizzle"
        case .flurries: return "cloud.snow"
        case .foggy: return "cloud.fog"
        case .freezingDrizzle: return "cloud.drizzle"
        case .freezingRain: return "cloud.rain"
        case .frigid: return "thermometer.snowflake"
        case .hail: return "cloud.hail"
        case .haze: return "sun.haze"
        case .heavyRain: return "cloud.heavyrain"
        case .heavySnow: return "cloud.snow"
        case .hot: return "thermometer.sun"
        case .hurricane: return "hurricane"
        case .isolatedThunderstorms: return "cloud.bolt"
        case .mostlyClear: return "sun.min"
        case .mostlyCloudy: return "cloud"
        case .partlyCloudy: return "cloud.sun"
        case .rain: return "cloud.rain"
        case .scatteredThunderstorms: return "cloud.bolt"
        case .sleet: return "cloud.sleet"
        case .smoky: return "smoke"
        case .snow: return "cloud.snow"
        case .strongStorms: return "cloud.bolt.rain"
        case .sunFlurries: return "snowflake.circle"
        case .sunShowers: return "cloud.sun.rain"
        case .thunderstorms: return "cloud.bolt"
        case .tropicalStorm: return "tropicalstorm"
        case .windy: return "wind"
        case .wintryMix: return "cloud.sleet"
        }

    }

    /// A localized accessibility description describing the weather condition, suitable for
    /// Voice Over and other assistive technologies.
    public var accessibilityDescription: String {
        description
    }
}

///
/// A description of the severity of the severe weather event.
///
public enum WeatherSeverity : String, CaseIterable, CustomStringConvertible, Hashable, Codable {

    /// Specifies "minimal" or no threat to life or property.
    case minor

    /// Specifies "possible" threat to life or property.
    case moderate

    /// Specifies "significant" threat to life or property.
    case severe

    /// Specifies "extraordinary" threat to life or property.
    case extreme

    /// Specifies unknown severity.
    case unknown

    /// Localized string describing the weather severity.
    public var description: String {
        switch self {
        case .minor: return NSLocalizedString("Minor", bundle: .module, comment: "WeatherCondition description for: minor")
        case .moderate: return NSLocalizedString("Moderate", bundle: .module, comment: "WeatherCondition description for: moderate")
        case .severe: return NSLocalizedString("Severe", bundle: .module, comment: "WeatherCondition description for: severe")
        case .extreme: return NSLocalizedString("Extreme", bundle: .module, comment: "WeatherCondition description for: extreme")
        case .unknown: return NSLocalizedString("Unknown", bundle: .module, comment: "WeatherCondition description for: unknown")
        }
    }

    /// A localized accessibility description describing the weather severity, suitable for
    /// Voice Over and other assistive technologies.
    public var accessibilityDescription: String {
        description
    }
}


///
/// An enumeration that specifies the moon phase kind.
///
/// Waxing and waning provide information about direction. Crescent
/// and gibbous describe shape.
///
public enum MoonPhase : String, CustomStringConvertible, CaseIterable, Hashable, Codable, Sendable {

    /// The disk is unlit where the moon is not visible.
    case new

    /// The disk is partially lit as the moon is waxing.
    case waxingCrescent

    /// The disk is half lit.
    case firstQuarter

    /// The disk is half lit as the moon is waxing.
    case waxingGibbous

    /// The disk is fully lit where the moon is visible.
    case full

    /// The disk is half lit as the moon is waning.
    case waningGibbous

    /// The disk is half lit.
    case lastQuarter

    /// The disk is partially lit as the moon is waning.
    case waningCrescent

    /// A localized string describing the moon phase.
    public var description: String {
        switch self {
        case .new: return NSLocalizedString("New", bundle: .module, comment: "MoonPhase description for: new")
        case .waxingCrescent: return NSLocalizedString("Waxing Crescent", bundle: .module, comment: "MoonPhase description for: waxingCrescent")
        case .firstQuarter: return NSLocalizedString("First Quarter", bundle: .module, comment: "MoonPhase description for: firstQuarter")
        case .waxingGibbous: return NSLocalizedString("Waxing Gibbous", bundle: .module, comment: "MoonPhase description for: waxingGibbous")
        case .full: return NSLocalizedString("Full", bundle: .module, comment: "MoonPhase description for: full")
        case .waningGibbous: return NSLocalizedString("Waning Gibbous", bundle: .module, comment: "MoonPhase description for: waningGibbous")
        case .lastQuarter: return NSLocalizedString("Last Quarter", bundle: .module, comment: "MoonPhase description for: lastQuarter")
        case .waningCrescent: return NSLocalizedString("Waning Crescent", bundle: .module, comment: "MoonPhase description for: waningCrescent")
        }
    }

    /// A localized accessibility description describing the moon phase, suitable for Voice Over
    /// and other assistive technologies.
    public var accessibilityDescription: String {
        description
    }

    ///
    /// The SF Symbol icon that represents the moon phase.
    ///
    public var symbolName: String {
        wip("")
    }
}

///
/// The form of precipitation.
///
public enum Precipitation : String, CaseIterable, CustomStringConvertible, Hashable, Codable {

    /// No precipitation.
    case none

    /// A form of precipitation consisting of solid ice.
    case hail

    /// Mixed precipitation.
    case mixed

    /// Rain.
    case rain

    /// A form of precipitation consisting of ice pellets.
    case sleet

    /// Snow.
    case snow

    /// A localized string describing the form of precipitation.
    public var description: String {
        switch self {
        case .none: return NSLocalizedString("None", bundle: .module, comment: "Precipitation description for: none")
        case .hail: return NSLocalizedString("Hail", bundle: .module, comment: "Precipitation description for: hail")
        case .mixed: return NSLocalizedString("Mixed", bundle: .module, comment: "Precipitation description for: mixed")
        case .rain: return NSLocalizedString("Rain", bundle: .module, comment: "Precipitation description for: rain")
        case .sleet: return NSLocalizedString("Sleet", bundle: .module, comment: "Precipitation description for: sleet")
        case .snow: return NSLocalizedString("Snow", bundle: .module, comment: "Precipitation description for: snow")
        }
    }

    /// A localized accessibility description describing the form of precipitation, suitable for
    /// Voice Over and other assistive technologies.
    public var accessibilityDescription: String {
        description
    }
}

///
/// The atmospheric pressure change over time.
///
public enum PressureTrend : String, CaseIterable, CustomStringConvertible, Hashable, Codable {

    /// The pressure is rising.
    case rising

    /// The pressure is falling.
    case falling

    /// The pressure is not changing.
    case steady

    /// The localized string describing the pressure trend.
    public var description: String {
        switch self {
        case .rising: return NSLocalizedString("Rising", bundle: .module, comment: "PressureTrend description for: rising")
        case .falling: return NSLocalizedString("Falling", bundle: .module, comment: "PressureTrend description for: falling")
        case .steady: return NSLocalizedString("Steady", bundle: .module, comment: "PressureTrend description for: steady")
        }
    }

    /// A localized accessibility description describing the pressure change over time,
    /// suitable for Voice Over and other assistive technologies.
    public var accessibilityDescription: String {
        description
    }
}


// MARK: Service Protocol Implementation

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension WeatherService : WeatherServiceSPI {
}

extension WeatherAttribution : WeatherAttributionSPI {
}

extension Weather : WeatherSPI {
}

extension WeatherAvailability : WeatherAvailabilitySPI {
}

extension WeatherAlert : WeatherAlertSPI {
}

extension CurrentWeather : CurrentWeatherSPI {
}
