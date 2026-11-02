import Foundation
import SwiftData
import Testing
@testable import VideoGrabber

@MainActor
struct AddLinkViewModelTests {
    private struct Harness {
        let container: ModelContainer
        let viewModel: AddLinkViewModel
        let settings: AppSettings
        let router: AppRouter
    }

    private func makeHarness(api: StubAPIClient = StubAPIClient(), defaultPreset: DownloadPreset = .bestMP4) throws -> Harness {
        let container = try ModelContainer(
            for: VideoItem.self, DownloadJob.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let settings = AppSettings(defaults: try #require(UserDefaults(suiteName: "tests.\(UUID().uuidString)")))
        settings.defaultPreset = defaultPreset
        let router = AppRouter()
        let gate = Gate()  // nunca aberto: o download enfileirado fica parado
        let manager = DownloadManager(
            modelContext: container.mainContext,
            apiClient: api,
            fileDownloader: StubFileDownloader(gate: gate),
            videoStore: VideoStore(baseDirectory: FileManager.default.temporaryDirectory.appending(path: "tests-\(UUID().uuidString)")),
            pollInterval: .zero,
            thumbnailLoader: { _ in Data() }
        )
        let viewModel = AddLinkViewModel(apiClient: api, downloadManager: manager, settings: settings, router: router)
        return Harness(container: container, viewModel: viewModel, settings: settings, router: router)
    }

    @Test func invalidTextCannotBeSearched() throws {
        let viewModel = try makeHarness().viewModel
        #expect(!viewModel.canSearch)
        #expect(!viewModel.showsInvalidLinkHint)

        viewModel.urlText = "https://vimeo.com/123"
        #expect(!viewModel.canSearch)
        #expect(viewModel.showsInvalidLinkHint)

        viewModel.urlText = "youtu.be/abc"
        #expect(viewModel.canSearch)
        #expect(!viewModel.showsInvalidLinkHint)
    }

    @Test func pasteKeepsOnlyTheLink() throws {
        let viewModel = try makeHarness().viewModel
        viewModel.paste("Olha que legal: https://youtu.be/abc123 haha")
        #expect(viewModel.urlText == "https://youtu.be/abc123")
    }

    @Test func searchShowsVideoAndPicksDefaultPreset() async throws {
        let harness = try makeHarness(defaultPreset: .audioM4A)
        harness.viewModel.urlText = "https://www.youtube.com/watch?v=jNQXAC9IVRw"

        await harness.viewModel.search()

        #expect(harness.viewModel.state == .resolved(.sample, sourceURL: "https://www.youtube.com/watch?v=jNQXAC9IVRw"))
        #expect(harness.viewModel.selectedPresetID == "audio_m4a")
    }

    @Test func searchFallsBackToFirstPresetWhenDefaultIsMissing() async throws {
        let api = StubAPIClient()
        api.resolveResult = .success(ResolveResponse(
            videoId: "x", title: "T", channel: "C", durationSeconds: 1, thumbnailUrl: nil,
            presets: [PresetOption(id: "mp4_720", label: "720p", kind: "video", estimatedBytes: nil)]
        ))
        let harness = try makeHarness(api: api, defaultPreset: .bestMP4)
        harness.viewModel.urlText = "https://youtu.be/x"

        await harness.viewModel.search()

        #expect(harness.viewModel.selectedPresetID == "mp4_720")
    }

    @Test func searchFailureShowsMessage() async throws {
        let api = StubAPIClient()
        api.resolveResult = .failure(.videoUnavailable)
        let harness = try makeHarness(api: api)
        harness.viewModel.urlText = "https://youtu.be/x"

        await harness.viewModel.search()

        #expect(harness.viewModel.state == .failed(message: APIError.videoUnavailable.localizedDescription))
    }

    @Test func editingTheFieldAfterSearchHidesTheOldVideo() async throws {
        let harness = try makeHarness()
        harness.viewModel.urlText = "https://youtu.be/jNQXAC9IVRw"
        await harness.viewModel.search()

        harness.viewModel.urlText = "https://youtu.be/outroVideo"
        harness.viewModel.download()

        #expect(harness.viewModel.state == .idle)
        #expect(try harness.container.mainContext.fetch(FetchDescriptor<DownloadJob>()).isEmpty)
    }

    @Test func resultForALinkNoLongerInTheFieldIsDiscarded() async throws {
        let api = StubAPIClient()
        let gate = Gate()
        api.resolveGate = gate
        let harness = try makeHarness(api: api)
        harness.viewModel.urlText = "https://youtu.be/A"

        let search = Task { await harness.viewModel.search() }
        for _ in 0..<1000 where harness.viewModel.state != .resolving {
            await Task.yield()
        }
        #expect(harness.viewModel.state == .resolving)
        harness.viewModel.paste("https://youtu.be/B")
        await gate.open()
        await search.value

        #expect(harness.viewModel.state == .idle)
        #expect(harness.viewModel.urlText == "https://youtu.be/B")
        #expect(harness.viewModel.canSearch)
    }

    @Test func downloadEnqueuesJobAndOpensQueue() async throws {
        let harness = try makeHarness()
        harness.viewModel.urlText = "https://youtu.be/jNQXAC9IVRw"
        await harness.viewModel.search()
        harness.viewModel.selectedPresetID = "mp4_720"

        harness.viewModel.download()

        let jobs = try harness.container.mainContext.fetch(FetchDescriptor<DownloadJob>())
        #expect(jobs.count == 1)
        #expect(jobs.first?.presetID == "mp4_720")
        #expect(jobs.first?.sourceURL == "https://youtu.be/jNQXAC9IVRw")
        #expect(harness.router.selectedTab == .queue)
        #expect(harness.viewModel.state == .idle)
        #expect(harness.viewModel.urlText.isEmpty)
    }
}
