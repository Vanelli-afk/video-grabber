import Foundation
import Testing
@testable import VideoGrabber

@MainActor
struct AppSettingsTests {
    @Test func defaultsWhenEmpty() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)

        #expect(settings.serverAddress.isEmpty)
        #expect(settings.serverURL == nil)
        #expect(settings.defaultPreset == .bestMP4)
    }

    @Test func persistsChanges() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        settings.serverAddress = "192.168.0.10:8080"
        settings.defaultPreset = .audioM4A

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.serverAddress == "192.168.0.10:8080")
        #expect(reloaded.serverURL?.absoluteString == "http://192.168.0.10:8080")
        #expect(reloaded.defaultPreset == .audioM4A)
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suite = "tests.\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: suite)), suite)
    }
}
