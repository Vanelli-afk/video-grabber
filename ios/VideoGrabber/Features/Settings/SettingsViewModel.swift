import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var serverAddress: String
    var token: String
    var defaultPreset: DownloadPreset
    private(set) var status: ConnectionStatus = .idle
    private(set) var saveErrorMessage: String?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let tokenStore: any TokenStore
    @ObservationIgnored private let apiClient: any APIClientProtocol

    init(settings: AppSettings, tokenStore: any TokenStore, apiClient: any APIClientProtocol) {
        self.settings = settings
        self.tokenStore = tokenStore
        self.apiClient = apiClient
        serverAddress = settings.serverAddress
        token = tokenStore.readToken() ?? ""
        defaultPreset = settings.defaultPreset
    }

    /// Campo vazio não é erro (ainda não configurado); texto que não vira URL é.
    var isServerAddressValid: Bool {
        serverAddress.trimmingCharacters(in: .whitespaces).isEmpty || ServerAddress.url(from: serverAddress) != nil
    }

    var canTestConnection: Bool {
        ServerAddress.url(from: serverAddress) != nil && !trimmedToken.isEmpty && status != .testing
    }

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func save() {
        settings.serverAddress = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.defaultPreset = defaultPreset
        do {
            if trimmedToken.isEmpty {
                try tokenStore.deleteToken()
            } else {
                try tokenStore.saveToken(trimmedToken)
            }
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = String(localized: "Não foi possível salvar o token no Keychain.")
        }
    }

    func testConnection() async {
        save()
        status = .testing
        do {
            let health = try await apiClient.health()
            try await apiClient.verifyToken()
            status = .connected(ytdlpVersion: health.ytdlpVersion)
        } catch let error as APIError {
            status = .failed(message: error.localizedDescription)
        } catch {
            status = .failed(message: APIError.unknown.localizedDescription)
        }
    }
}
