import CoreLocation
import Foundation
import GolfKit
import Observation
import WeatherKit

struct WeatherSnapshot: Equatable, Sendable {
    /// Direction the wind blows FROM, degrees.
    var windFromDeg: Double
    /// m/s
    var windSpeed: Double
    var temperatureC: Double
    var fetchedAt: Date
    var attributionMarkURL: URL?
    var legalURL: URL?
}

/// Hourly forecast near a tee time.
struct ForecastSnapshot: Equatable, Sendable {
    var date: Date
    var temperatureC: Double
    /// 0–1
    var precipitationChance: Double
    var windSpeed: Double
    var symbolName: String
    var conditionText: String

    var summary: String {
        String(localized: "預報 \(Int(temperatureC.rounded()))°C、降雨機率 \(Int((precipitationChance * 100).rounded()))%、風速 \(Int(windSpeed.rounded())) m/s。")
    }
}

/// Current wind / temperature from WeatherKit, cached 15 minutes. Returns nil without network or entitlement.
@MainActor @Observable
final class WeatherService {
    static let cacheSeconds: TimeInterval = 15 * 60
    /// Reuse the cache within this distance (m).
    static let cacheRadius = 2_000.0

    private(set) var latest: WeatherSnapshot?
    @ObservationIgnored private var cachedAt: GeoPoint?
    @ObservationIgnored private var inFlight = false

    func current(at p: GeoPoint) async -> WeatherSnapshot? {
        if let latest, let at = cachedAt, Date().timeIntervalSince(latest.fetchedAt) < Self.cacheSeconds,
           Geo.distance(at, p) < Self.cacheRadius {
            return latest
        }
        guard !inFlight else { return latest }
        inFlight = true
        defer { inFlight = false }
        do {
            let service = WeatherKit.WeatherService.shared
            let weather = try await service.weather(for: CLLocation(latitude: p.lat, longitude: p.lon), including: .current)
            let attribution = try? await service.attribution
            let snap = WeatherSnapshot(
                windFromDeg: weather.wind.direction.converted(to: .degrees).value,
                windSpeed: weather.wind.speed.converted(to: .metersPerSecond).value,
                temperatureC: weather.temperature.converted(to: .celsius).value,
                fetchedAt: Date(),
                attributionMarkURL: attribution?.combinedMarkDarkURL,
                legalURL: attribution?.legalPageURL)
            latest = snap
            cachedAt = p
            return snap
        } catch {
            // No network, no entitlement or quota: stay silent.
            return nil
        }
    }

    /// Hourly forecast closest to `date` (WeatherKit covers about 10 days). nil when unavailable.
    func forecast(at p: GeoPoint, date: Date) async -> ForecastSnapshot? {
        guard date.timeIntervalSinceNow < 10 * 86_400 else { return nil }
        do {
            let hourly = try await WeatherKit.WeatherService.shared.weather(
                for: CLLocation(latitude: p.lat, longitude: p.lon), including: .hourly)
            guard let hour = hourly.forecast.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }),
                  abs(hour.date.timeIntervalSince(date)) < 3 * 3600 else { return nil }
            return ForecastSnapshot(
                date: hour.date,
                temperatureC: hour.temperature.converted(to: .celsius).value,
                precipitationChance: hour.precipitationChance,
                windSpeed: hour.wind.speed.converted(to: .metersPerSecond).value,
                symbolName: hour.symbolName,
                conditionText: hour.condition.description)
        } catch {
            return nil
        }
    }
}
