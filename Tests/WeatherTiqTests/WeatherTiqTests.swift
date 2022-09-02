import XCTest
@testable import WeatherTiq

final class WeatherTiqTests: XCTestCase {
    func testWeather() async throws {
        do {
            let service = WeatherService.shared
            let location = WeatherLocation(latitude: 42.3600825, longitude: -71.0588801)
            let forcast = try await service.weather(for: location, including: .current)
            dump(forcast)
        } catch {
            XCTFail("\(error)")
        }
    }
}
