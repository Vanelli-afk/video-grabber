import Foundation
import SwiftData
import Testing
@testable import VideoGrabber

@MainActor
struct DownloadStateTransitionTests {
    @Test(arguments: [
        (DownloadState.queued, DownloadState.resolving),
        (.resolving, .preparing),
        (.preparing, .downloading),
        (.downloading, .completed),
        (.downloading, .paused),
        (.paused, .downloading),
        (.downloading, .failed),
        (.preparing, .cancelled),
        (.failed, .queued),
        (.cancelled, .queued),
    ])
    func allowsValidTransitions(from current: DownloadState, to next: DownloadState) {
        #expect(DownloadManager.isValidTransition(from: current, to: next))
    }

    @Test(arguments: [
        (DownloadState.queued, DownloadState.completed),
        (.queued, .downloading),
        (.completed, .queued),
        (.completed, .cancelled),
        (.failed, .completed),
        (.cancelled, .downloading),
        (.downloading, .queued),
    ])
    func rejectsInvalidTransitions(from current: DownloadState, to next: DownloadState) {
        #expect(!DownloadManager.isValidTransition(from: current, to: next))
    }

    @Test func finishedStatesAreExactlyTheTerminalOnes() {
        #expect(DownloadState.allCases.filter(\.isFinished) == [.completed, .failed, .cancelled])
    }
}

@MainActor
struct DownloadManagerTests {
    private struct Harness {
        let container: ModelContainer
        let manager: DownloadManager
        let api: StubAPIClient
        let store: VideoStore

        var context: ModelContext { container.mainContext }

        func videos() throws -> [VideoItem] {
            try context.fetch(FetchDescriptor<VideoItem>())
        }
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: VideoItem.self, DownloadJob.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeHarness(
        container: ModelContainer? = nil,
        api: StubAPIClient = StubAPIClient(),
        downloader: StubFileDownloader = StubFileDownloader()
    ) throws -> Harness {
        let container = try container ?? makeContainer()
        let store = VideoStore(baseDirectory: FileManager.default.temporaryDirectory.appending(path: "tests-\(UUID().uuidString)"))
        let manager = DownloadManager(
            modelContext: container.mainContext,
            apiClient: api,
            fileDownloader: downloader,
            videoStore: store,
            pollInterval: .zero,
            thumbnailLoader: { _ in Data("jpg".utf8) }
        )
        return Harness(container: container, manager: manager, api: api, store: store)
    }

    private func waitUntil(_ condition: () throws -> Bool) async throws {
        for _ in 0..<500 {
            if try condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("A condição não foi atingida a tempo")
    }

    @Test func completedDownloadCreatesVideoItemAndCleansServer() async throws {
        let harness = try makeHarness()

        let job = harness.manager.enqueue(.sample, sourceURL: "https://youtu.be/jNQXAC9IVRw", presetID: "best_mp4")
        try await waitUntil { job.state == .completed }

        #expect(job.progress == 1)
        let video = try #require(try harness.videos().first)
        #expect(video.title == "Me at the zoo")
        #expect(video.videoID == "jNQXAC9IVRw")
        #expect(video.fileSizeBytes == 5)
        #expect(video.fileName.hasSuffix(".mp4"))
        #expect(FileManager.default.fileExists(atPath: harness.store.videoURL(for: video.fileName).path(percentEncoded: false)))
        let thumbnail = try #require(video.thumbnailFileName)
        #expect(FileManager.default.fileExists(atPath: harness.store.thumbnailURL(for: thumbnail).path(percentEncoded: false)))
        try await waitUntil { harness.api.deletedJobIDs == ["server-job-1"] }
    }

    @Test func audioPresetIsStoredAsM4A() async throws {
        let harness = try makeHarness()

        let job = harness.manager.enqueue(.sample, sourceURL: "https://youtu.be/x", presetID: "audio_m4a")
        try await waitUntil { job.state == .completed }

        #expect(try harness.videos().first?.fileName.hasSuffix(".m4a") == true)
    }

    @Test func pollsUntilServerIsReady() async throws {
        let api = StubAPIClient()
        api.jobStatuses = [.preparing(0.2), .preparing(0.8), .ready]
        let harness = try makeHarness(api: api)

        let job = harness.manager.enqueue(.sample, sourceURL: "https://youtu.be/x", presetID: "best_mp4")
        try await waitUntil { job.state == .completed }

        #expect(api.jobStatuses == [.ready])
    }

    @Test func serverFailureMarksJobFailedWithMessage() async throws {
        let api = StubAPIClient()
        api.jobStatuses = [.failed(code: "video_unavailable", message: "Indisponível")]
        let harness = try makeHarness(api: api)

        let job = harness.manager.enqueue(.sample, sourceURL: "https://youtu.be/x", presetID: "best_mp4")
        try await waitUntil { job.state == .failed }

        #expect(job.errorMessage == APIError.videoUnavailable.localizedDescription)
        #expect(try harness.videos().isEmpty)
        #expect(harness.manager.canRetry(job))
        #expect(!harness.manager.canCancel(job))
    }

    @Test func retryAfterFailureCompletes() async throws {
        let api = StubAPIClient()
        api.jobStatuses = [.failed(code: "extractor_failed", message: "Falhou"), .ready]
        let harness = try makeHarness(api: api)

        let job = harness.manager.enqueue(.sample, sourceURL: "https://youtu.be/x", presetID: "best_mp4")
        try await waitUntil { job.state == .failed }
        #expect(job.errorMessage == "Falhou")

        harness.manager.retry(job)
        try await waitUntil { job.state == .completed }
        #expect(job.errorMessage == nil)
    }

    @Test func cancelDuringTransferKeepsNoFile() async throws {
        let gate = Gate()
        let harness = try makeHarness(downloader: StubFileDownloader(gate: gate))

        let job = harness.manager.enqueue(.sample, sourceURL: "https://youtu.be/x", presetID: "best_mp4")
        try await waitUntil { job.state == .downloading }

        harness.manager.cancel(job)
        #expect(job.state == .cancelled)
        await gate.open()
        try await waitUntil { harness.api.deletedJobIDs == ["server-job-1"] }
        try await Task.sleep(for: .milliseconds(50))

        #expect(job.state == .cancelled)
        #expect(try harness.videos().isEmpty)
        #expect(harness.manager.canRetry(job))
    }

    @Test func runsAtMostTwoDownloadsAtOnce() async throws {
        let gate = Gate()
        let harness = try makeHarness(downloader: StubFileDownloader(gate: gate))

        let jobs = (0..<3).map { _ in
            harness.manager.enqueue(.sample, sourceURL: "https://youtu.be/x", presetID: "best_mp4")
        }
        try await waitUntil { jobs.filter { $0.state == .downloading }.count == 2 }
        #expect(jobs.filter { $0.state == .queued }.count == 1)

        await gate.open()
        try await waitUntil { jobs.allSatisfy { $0.state == .completed } }
        #expect(try harness.videos().count == 3)
    }

    @Test func removeOnlyDeletesFinishedJobs() async throws {
        let gate = Gate()
        let harness = try makeHarness(downloader: StubFileDownloader(gate: gate))
        let job = harness.manager.enqueue(.sample, sourceURL: "https://youtu.be/x", presetID: "best_mp4")
        try await waitUntil { job.state == .downloading }

        harness.manager.remove(job)
        #expect(try harness.context.fetch(FetchDescriptor<DownloadJob>()).count == 1)

        await gate.open()
        try await waitUntil { job.state == .completed }
        try await Task.sleep(for: .milliseconds(20))
        harness.manager.remove(job)
        #expect(try harness.context.fetch(FetchDescriptor<DownloadJob>()).isEmpty)
        #expect(try harness.videos().count == 1)
    }

    @Test func interruptedJobsFailWhenAppStarts() throws {
        let container = try makeContainer()
        let interrupted = DownloadJob(
            sourceURL: "https://youtu.be/x", videoID: "x", title: "T", channel: "C",
            durationSeconds: 1, thumbnailURL: nil, presetID: "best_mp4", state: .downloading
        )
        container.mainContext.insert(interrupted)

        _ = try makeHarness(container: container)

        #expect(interrupted.state == .failed)
        #expect(interrupted.errorMessage?.isEmpty == false)
    }
}
