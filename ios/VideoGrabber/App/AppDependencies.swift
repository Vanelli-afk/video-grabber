import Foundation

/// Instâncias únicas do app, criadas uma vez e repassadas às telas.
@MainActor
final class AppDependencies {
    let settings: AppSettings
    let router: AppRouter
    let tokenStore: any TokenStore
    let apiClient: any APIClientProtocol

    init() {
        let settings = AppSettings()
        let tokenStore: any TokenStore = KeychainStore()
        self.settings = settings
        self.router = AppRouter()
        self.tokenStore = tokenStore
        self.apiClient = APIClient { @MainActor in
            ServerConfiguration(baseURL: settings.serverURL, token: tokenStore.readToken())
        }
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(settings: settings, tokenStore: tokenStore, apiClient: apiClient)
    }
}
