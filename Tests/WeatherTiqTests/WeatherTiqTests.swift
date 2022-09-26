import XCTest
import WeatherTiq
import LocationTiq

final class WeatherTiqTests: XCTestCase {
    func testWeather() async throws {
        do {
            let service = WeatherService.shared
            let location = Location(latitude: 42.3600825, longitude: -71.0588801)
            let forcast = try await service.weather(for: location, including: .current)
            dump(forcast)
        } catch {
            XCTFail("\(error)")
        }
    }
}
