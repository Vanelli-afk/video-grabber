import Foundation
import Observation

/// Preferências simples (nunca segredos: o token fica no Keychain).
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let serverAddress = "settings.serverAddress"
        static let defaultPreset = "settings.defaultPreset"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var serverAddress: String {
        didSet { defaults.set(serverAddress, forKey: Key.serverAddress) }
    }

    var defaultPreset: DownloadPreset {
        didSet { defaults.set(defaultPreset.rawValue, forKey: Key.defaultPreset) }
    }

    var serverURL: URL? {
        ServerAddress.url(from: serverAddress)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        serverAddress = defaults.string(forKey: Key.serverAddress) ?? ""
        defaultPreset = defaults.string(forKey: Key.defaultPreset).flatMap(DownloadPreset.init(rawValue:)) ?? .bestMP4
    }
}
