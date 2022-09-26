import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: Model

enum METService {
    struct JSONForecast: Codable {
        enum ModelType: String, Codable { case Feature }
        var type: ModelType
        var geometry: PointGeometry
        var properties: Forecast
    }

    struct Forecast: Codable {
        var meta: Metadata
        var timeseries: [ForecastTimeStep]
    }

    struct Metadata: Codable {
        var units: ForecastUnits
        /// Update time for this forecast
        var updated_at: Date
    }

    /// Summary of weather conditions.
    struct ForecastSummary: Codable {
        var symbol_code: WeatherSymbol
    }

    /// Weather parameters valid for a specific point in time.
    struct ForecastTimeInstant: Codable {
        /// Air pressure at sea level
        var air_pressure_at_sea_level: Double?
        /// Air temperature
        var air_temperature: Double?
        /// Amount of sky covered by clouds.
        var cloud_area_fraction: Double?
        /// Amount of sky covered by clouds at high elevation.
        var cloud_area_fraction_high: Double?
        /// Amount of sky covered by clouds at low elevation.
        var cloud_area_fraction_low: Double?
        /// Amount of sky covered by clouds at medium elevation.
        var cloud_area_fraction_medium: Double?
        /// Dew point temperature at sea level
        var dew_point_temperature: Double?
        /// Amount of area covered by fog.
        var fog_area_fraction: Double?
        /// Amount of humidity in the air.
        var relative_humidity: Double?
        /// The directon which moves towards
        var wind_from_direction: Double?
        /// Speed of wind
        var wind_speed: Double?
        /// Speed of wind gust
        var wind_speed_of_gust: Double?
    }

    /// Weather parameters valid for a specified time period.
    struct ForecastTimePeriod: Codable {
        /// Maximum air temperature in period
        var airTemperatureMax: Double?
        /// Minimum air temperature in period
        var airTemperatureMin: Double?
        /// Best estimate for amount of precipitation for this period
        var precipitationAmount: Double?
        /// Maximum amount of precipitation for this period
        var precipitationAmountMax: Double?
        /// Minimum amount of precipitation for this period
        var precipitationAmountMin: Double?
        /// Probability of any precipitation coming for this period
        var probabilityOfPrecipitation: Double?
        /// Probability of any thunder coming for this period
        var probabilityOfThunder: Double?
        /// Maximum ultraviolet index if sky is clear
        var ultravioletIndexClearSkyMax: Double?
    }

    struct ForecastTimeStep: Codable {
        var data: ForecastTimeStepData
        /// The time these forecast values are valid for. Timestamp in format YYYY-MM-DDThh:mm:ssZ (ISO 8601)
        var time: Date
    }

    /// Forecast for a specific time
    struct ForecastTimeStepData: Codable {
        var instant: ForecastTimeStepDataInstant
        var next_12_hours: ForecastTimeStepDataNext12Hours?
        var next_1_hours: ForecastTimeStepDataNext1Hours?
        var next_6_hours: ForecastTimeStepDataNext6Hours?
    }

    /// Parameters which applies to this exact point in time
    struct ForecastTimeStepDataInstant: Codable {
        var details: ForecastTimeInstant?
    }

    /// Parameters with validity times over twelve hours. Will not exist for all time steps.
    struct ForecastTimeStepDataNext12Hours: Codable {
        var details: ForecastTimePeriod?
        var summary: ForecastSummary
    }

    /// Parameters with validity times over one hour. Will not exist for all time steps.
    struct ForecastTimeStepDataNext1Hours: Codable {
        var details: ForecastTimePeriod?
        var summary: ForecastSummary
    }

    /// Parameters with validity times over six hours. Will not exist for all time steps.
    struct ForecastTimeStepDataNext6Hours: Codable {
        var details: ForecastTimePeriod?
        var summary: ForecastSummary
    }

    struct ForecastUnits: Codable {
        var air_pressure_at_sea_level: String?
        var air_temperature: String?
        var air_temperature_max: String?
        var air_temperature_min: String?
        var cloud_area_fraction: String?
        var cloud_area_fraction_high: String?
        var cloud_area_fraction_low: String?
        var cloud_area_fraction_medium: String?
        var dew_point_temperature: String?
        var fog_area_fraction: String?
        var precipitation_amount: String?
        var precipitation_amount_max: String?
        var precipitation_amount_min: String?
        var probability_of_precipitation: String?
        var probability_of_thunder: String?
        var relative_humidity: String?
        var ultraviolet_index_clear_sky_max: String?
        var wind_from_direction: String?
        var wind_speed: String?
        var wind_speed_of_gust: String?
    }

    struct PointGeometry: Codable {
        enum ModelType: String, Codable { case Point }
        var type: ModelType
        /// [longitude, latitude, altitude]. All numbers in Double.
        var coordinates: [Double]
    }

    /// A identifier that sums up the weather condition for this time period. May be used with https://api.met.no/weatherapi/weathericon/2.0/.
    enum WeatherSymbol: String, Codable {
        case clearsky_day, clearsky_night, clearsky_polartwilight, fair_day, fair_night, fair_polartwilight, lightssnowshowersandthunder_day, lightssnowshowersandthunder_night, lightssnowshowersandthunder_polartwilight, lightsnowshowers_day, lightsnowshowers_night, lightsnowshowers_polartwilight, heavyrainandthunder, heavysnowandthunder, rainandthunder, heavysleetshowersandthunder_day, heavysleetshowersandthunder_night, heavysleetshowersandthunder_polartwilight, heavysnow, heavyrainshowers_day, heavyrainshowers_night, heavyrainshowers_polartwilight, lightsleet, heavyrain, lightrainshowers_day, lightrainshowers_night, lightrainshowers_polartwilight, heavysleetshowers_day, heavysleetshowers_night, heavysleetshowers_polartwilight, lightsleetshowers_day, lightsleetshowers_night, lightsleetshowers_polartwilight, snow, heavyrainshowersandthunder_day, heavyrainshowersandthunder_night, heavyrainshowersandthunder_polartwilight, snowshowers_day, snowshowers_night, snowshowers_polartwilight, fog, snowshowersandthunder_day, snowshowersandthunder_night, snowshowersandthunder_polartwilight, lightsnowandthunder, heavysleetandthunder, lightrain, rainshowersandthunder_day, rainshowersandthunder_night, rainshowersandthunder_polartwilight, rain, lightsnow, lightrainshowersandthunder_day, lightrainshowersandthunder_night, lightrainshowersandthunder_polartwilight, heavysleet, sleetandthunder, lightrainandthunder, sleet, lightssleetshowersandthunder_day, lightssleetshowersandthunder_night, lightssleetshowersandthunder_polartwilight, lightsleetandthunder, partlycloudy_day, partlycloudy_night, partlycloudy_polartwilight, sleetshowersandthunder_day, sleetshowersandthunder_night, sleetshowersandthunder_polartwilight, rainshowers_day, rainshowers_night, rainshowers_polartwilight, snowandthunder, sleetshowers_day, sleetshowers_night, sleetshowers_polartwilight, cloudy, heavysnowshowersandthunder_day, heavysnowshowersandthunder_night, heavysnowshowersandthunder_polartwilight, heavysnowshowers_day, heavysnowshowers_night, heavysnowshowers_polartwilight
    }
}


/// Conversion utilities from the names units to ``Foundation.Dimension``
extension METService.ForecastUnits {
    var airTemperatureUnits: UnitTemperature { get throws { try Self.temp(air_temperature) } }
    var airTemperatureMaxUnits: UnitTemperature { get throws { try Self.temp(air_temperature_max) } }
    var airTemperatureMinUnits: UnitTemperature { get throws { try Self.temp(air_temperature_min) } }
    var dewPointTemperatureUnits: UnitTemperature { get throws { try Self.temp(dew_point_temperature) } }

    var precipitationAmountUnits: UnitLength { get throws { try Self.length(precipitation_amount) } }
    var precipitationAmountMaxUnits: UnitLength { get throws { try Self.length(precipitation_amount_max) } }
    var precipitationAmountMinUnits: UnitLength { get throws { try Self.length(precipitation_amount_min) } }

    var windSpeedUnits: UnitSpeed { get throws { try Self.speed(wind_speed) } }
    var windSpeedOfGustUnits: UnitSpeed { get throws { try Self.speed(wind_speed_of_gust) } }

    var airPressureAtSeaLevelUnits: UnitPressure { get throws { try Self.pressure(air_pressure_at_sea_level) } }

    private static func temp(_ value: String?, path: String = #function) throws -> UnitTemperature {
        switch value {
        case "C": return .celsius
        case "celsius": return .celsius // observed, but not in the API
        //case "F": return .fahrenheit
        //case "K": return .kelvin
        default: throw WeatherError.badUnit(path, value)
        }
    }

    private static func length(_ value: String?, path: String = #function) throws -> UnitLength {
        switch value {
        case "mm": return .millimeters
        default: throw WeatherError.badUnit(path, value)
        }
    }

    private static func pressure(_ value: String?, path: String = #function) throws -> UnitPressure {
        switch value {
        case "hPa": return .hectopascals
        default: throw WeatherError.badUnit(path, value)
        }
    }

    private static func speed(_ value: String?, path: String = #function) throws -> UnitSpeed {
        switch value {
        case "m/s": return .metersPerSecond
        default: throw WeatherError.badUnit(path, value)
        }
    }
}
