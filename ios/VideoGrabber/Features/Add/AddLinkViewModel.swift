import Foundation
import Observation

@MainActor
@Observable
final class AddLinkViewModel {
    enum State: Equatable {
        case idle
        case resolving
        /// `sourceURL` é o link que foi buscado: o download usa ele, não o que estiver no campo depois.
        case resolved(ResolveResponse, sourceURL: String)
        case failed(message: String)
    }

    var urlText = "" {
        didSet {
            // O card mostrado tem que ser sempre do link que está no campo.
            if urlText != oldValue, state != .resolving {
                state = .idle
            }
        }
    }
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
    }

    func search() async {
        guard let link, state != .resolving else { return }
        let sourceURL = link.absoluteString
        state = .resolving

        let result: Result<ResolveResponse, APIError>
        do {
            result = .success(try await apiClient.resolve(url: sourceURL))
        } catch let error as APIError {
            result = .failure(error)
        } catch {
            result = .failure(.unknown)
        }

        // O campo mudou durante a busca: o resultado é de outro link.
        guard link?.absoluteString == sourceURL else {
            state = .idle
            return
        }
        switch result {
        case .success(let video):
            let preferred = settings.defaultPreset.rawValue
            selectedPresetID = video.presets.contains { $0.id == preferred }
                ? preferred
                : (video.presets.first?.id ?? preferred)
            state = .resolved(video, sourceURL: sourceURL)
        case .failure(let error):
            state = .failed(message: error.localizedDescription)
        }
    }

    func download() {
        guard case .resolved(let video, let sourceURL) = state else { return }
        downloadManager.enqueue(video, sourceURL: sourceURL, presetID: selectedPresetID)
        urlText = ""
        router.selectedTab = .queue
    }
}
