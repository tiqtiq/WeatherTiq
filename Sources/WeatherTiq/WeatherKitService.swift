#if canImport(WeatherKit)
import WeatherKit

extension WeatherServiceSPI {
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public static var weatherKit: WeatherKit.WeatherService { WeatherKit.WeatherService.shared }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension WeatherKit.WeatherService : WeatherServiceSPI {
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension WeatherKit.WeatherAttribution : WeatherAttributionSPI {
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension WeatherKit.WeatherAvailability : WeatherAvailabilitySPI {
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension WeatherKit.Weather : WeatherSPI {
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension WeatherKit.Forecast : DayForecastSPI where Element == WeatherKit.DayWeather {
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension WeatherKit.Forecast : HourForecastSPI where Element == WeatherKit.HourWeather {
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension WeatherKit.Forecast : MinuteForecastSPI where Element == WeatherKit.MinuteWeather {
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension WeatherKit.WeatherAlert : WeatherAlertSPI {
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension WeatherKit.CurrentWeather : CurrentWeatherSPI {
}

#endif
