import Foundation
import Testing
@testable import VideoGrabber

@MainActor
struct SettingsViewModelTests {
    private let suite = "tests.\(UUID().uuidString)"

    private func makeViewModel(
        token: String? = nil,
        apiClient: StubAPIClient = StubAPIClient()
    ) throws -> (SettingsViewModel, AppSettings, InMemoryTokenStore) {
        let settings = AppSettings(defaults: try #require(UserDefaults(suiteName: suite)))
        let tokenStore = InMemoryTokenStore(token: token)
        let viewModel = SettingsViewModel(settings: settings, tokenStore: tokenStore, apiClient: apiClient)
        return (viewModel, settings, tokenStore)
    }

    @Test func loadsSavedToken() throws {
        let (viewModel, _, _) = try makeViewModel(token: "salvo-123")
        #expect(viewModel.token == "salvo-123")
    }

    @Test func savePersistsAddressPresetAndToken() throws {
        let (viewModel, settings, tokenStore) = try makeViewModel()
        viewModel.serverAddress = " 192.168.0.10:8080 "
        viewModel.token = " novo-token "
        viewModel.defaultPreset = .mp4720

        viewModel.save()

        #expect(settings.serverAddress == "192.168.0.10:8080")
        #expect(settings.defaultPreset == .mp4720)
        #expect(tokenStore.readToken() == "novo-token")
    }

    @Test func emptyTokenIsDeleted() throws {
        let (viewModel, _, tokenStore) = try makeViewModel(token: "antigo")
        viewModel.token = ""
        viewModel.save()
        #expect(tokenStore.readToken() == nil)
    }

    @Test func canTestOnlyWithAddressAndToken() throws {
        let (viewModel, _, _) = try makeViewModel()
        #expect(!viewModel.canTestConnection)

        viewModel.serverAddress = "192.168.0.10:8080"
        #expect(!viewModel.canTestConnection)

        viewModel.token = "token-123"
        #expect(viewModel.canTestConnection)

        viewModel.serverAddress = "ftp://x"
        #expect(!viewModel.canTestConnection)
        #expect(!viewModel.isServerAddressValid)
    }

    @Test func successfulTestShowsConnectedWithVersion() async throws {
        let (viewModel, _, _) = try makeViewModel()
        viewModel.serverAddress = "192.168.0.10:8080"
        viewModel.token = "token-123"

        await viewModel.testConnection()

        #expect(viewModel.status == .connected(ytdlpVersion: "2026.10.26"))
    }

    @Test func invalidTokenShowsError() async throws {
        let (viewModel, _, _) = try makeViewModel(apiClient: StubAPIClient(verifyTokenResult: .failure(.unauthorized)))
        viewModel.serverAddress = "192.168.0.10:8080"
        viewModel.token = "errado"

        await viewModel.testConnection()

        #expect(viewModel.status == .failed(message: APIError.unauthorized.localizedDescription))
    }

    @Test func unreachableServerShowsError() async throws {
        let (viewModel, _, _) = try makeViewModel(apiClient: StubAPIClient(healthResult: .failure(.serverUnreachable)))
        viewModel.serverAddress = "192.168.0.99:8080"
        viewModel.token = "token-123"

        await viewModel.testConnection()

        #expect(viewModel.status == .failed(message: APIError.serverUnreachable.localizedDescription))
    }
}
