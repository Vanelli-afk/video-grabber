import Foundation
import os
import SwiftData

/// Instâncias únicas do app, criadas uma vez e repassadas às telas.
@MainActor
final class AppDependencies {
    private static let logger = Logger(subsystem: "com.vanelliafk.videograbber", category: "AppDependencies")

    let settings: AppSettings
    let router: AppRouter
    let tokenStore: any TokenStore
    let apiClient: any APIClientProtocol
    let modelContainer: ModelContainer
    let downloadManager: DownloadManager

    init() {
        let isUITesting = UITestSupport.isActive
        let settings = AppSettings()
        let tokenStore: any TokenStore = KeychainStore()

        let apiClient: any APIClientProtocol
        let fileDownloader: any FileDownloading
        if isUITesting, let services = UITestSupport.makeServices() {
            apiClient = services.apiClient
            fileDownloader = services.fileDownloader
        } else {
            apiClient = APIClient { @MainActor in
                ServerConfiguration(baseURL: settings.serverURL, token: tokenStore.readToken())
            }
            fileDownloader = URLSessionFileDownloader()
        }

        let modelContainer = Self.makeModelContainer(inMemory: isUITesting)
        let storageDirectory = isUITesting
            ? FileManager.default.temporaryDirectory.appending(path: "UITests", directoryHint: .isDirectory)
            : URL.applicationSupportDirectory

        self.settings = settings
        self.router = AppRouter()
        self.tokenStore = tokenStore
        self.apiClient = apiClient
        self.modelContainer = modelContainer
        self.downloadManager = DownloadManager(
            modelContext: modelContainer.mainContext,
            apiClient: apiClient,
            fileDownloader: fileDownloader,
            videoStore: VideoStore(baseDirectory: storageDirectory),
            thumbnailLoader: { url in try await URLSession.shared.data(from: url).0 }
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(settings: settings, tokenStore: tokenStore, apiClient: apiClient)
    }

    func makeAddLinkViewModel() -> AddLinkViewModel {
        AddLinkViewModel(apiClient: apiClient, downloadManager: downloadManager, settings: settings, router: router)
    }

    private static func makeModelContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema([VideoItem.self, DownloadJob.self])
        // Na primeira abertura a pasta ainda não existe e o CoreData registra vários erros antes de criá-la.
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
            )
        } catch {
            // Banco corrompido ou incompatível: o app ainda abre, sem histórico, em vez de fechar.
            logger.fault("Falha ao abrir o banco de dados: \(error.localizedDescription, privacy: .public)")
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                )
            } catch {
                fatalError("Não foi possível criar nem o banco de dados em memória: \(error)")
            }
        }
    }
}
