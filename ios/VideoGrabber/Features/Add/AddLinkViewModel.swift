import Foundation
import Observation

@MainActor
@Observable
final class AddLinkViewModel {
    enum State: Equatable {
        case idle
        case resolving
        case resolved(ResolveResponse)
        case failed(message: String)
    }

    var urlText = ""
    var selectedPresetID = ""
    private(set) var state: State = .idle

    @ObservationIgnored private let apiClient: any APIClientProtocol
    @ObservationIgnored private let downloadManager: DownloadManager
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let router: AppRouter

    init(apiClient: any APIClientProtocol, downloadManager: DownloadManager, settings: AppSettings, router: AppRouter) {
        self.apiClient = apiClient
        self.downloadManager = downloadManager
        self.settings = settings
        self.router = router
    }

    var link: URL? {
        YouTubeLink.url(from: urlText)
    }

    var canSearch: Bool {
        link != nil && state != .resolving
    }

    var showsInvalidLinkHint: Bool {
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && link == nil
    }

    /// Texto colado pode vir com mais coisas ("Olha isto: https://youtu.be/…"): fica só o link.
    func paste(_ text: String) {
        urlText = YouTubeLink.url(from: text)?.absoluteString ?? text
        state = .idle
    }

    func search() async {
        guard let link, state != .resolving else { return }
        state = .resolving
        do {
            let video = try await apiClient.resolve(url: link.absoluteString)
            let preferred = settings.defaultPreset.rawValue
            selectedPresetID = video.presets.contains { $0.id == preferred }
                ? preferred
                : (video.presets.first?.id ?? preferred)
            state = .resolved(video)
        } catch let error as APIError {
            state = .failed(message: error.localizedDescription)
        } catch {
            state = .failed(message: APIError.unknown.localizedDescription)
        }
    }

    func download() {
        guard case .resolved(let video) = state, let link else { return }
        downloadManager.enqueue(video, sourceURL: link.absoluteString, presetID: selectedPresetID)
        urlText = ""
        state = .idle
        router.selectedTab = .queue
    }
}
