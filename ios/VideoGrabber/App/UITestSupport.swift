import Foundation

/// Serviços falsos para o XCUITest (`-ui-testing`): o fluxo roda sem servidor nem internet.
/// Só existem em Debug.
enum UITestSupport {
    static let launchArgument = "-ui-testing"

    struct Services {
        let apiClient: any APIClientProtocol
        let fileDownloader: any FileDownloading
    }

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static func makeServices() -> Services? {
        #if DEBUG
        return Services(apiClient: UITestAPIClient(), fileDownloader: UITestFileDownloader())
        #else
        return nil
        #endif
    }
}

#if DEBUG
private struct UITestAPIClient: APIClientProtocol {
    func health() async throws -> HealthResponse {
        HealthResponse(status: "ok", ytdlpVersion: "ui-test")
    }

    func verifyToken() async throws {}

    func resolve(url: String) async throws -> ResolveResponse {
        ResolveResponse(
            videoId: "jNQXAC9IVRw",
            title: "Me at the zoo",
            channel: "jawed",
            durationSeconds: 19,
            thumbnailUrl: nil,
            presets: [
                PresetOption(id: "best_mp4", label: "Melhor qualidade (até 1080p)", kind: "video", estimatedBytes: 1_009_829),
                PresetOption(id: "mp4_720", label: "720p", kind: "video", estimatedBytes: 1_009_829),
                PresetOption(id: "audio_m4a", label: "Somente áudio (M4A)", kind: "audio", estimatedBytes: 309_288),
            ]
        )
    }

    func createJob(url: String, presetID: String) async throws -> String {
        "ui-test-job"
    }

    func jobStatus(id: String) async throws -> JobStatusResponse {
        JobStatusResponse(
            jobId: id, status: .ready, progress: 1, fileSizeBytes: 4,
            fileName: "Me at the zoo.mp4", errorCode: nil, errorMessage: nil
        )
    }

    func fileRequest(id: String) async throws -> URLRequest {
        URLRequest(url: URL(filePath: "/dev/null"))
    }

    func deleteJob(id: String) async throws {}
}

private struct UITestFileDownloader: FileDownloading {
    func download(_ request: URLRequest, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let file = FileManager.default.temporaryDirectory.appending(path: "ui-test-\(UUID().uuidString)")
        try Data("test".utf8).write(to: file)
        progress(1)
        return file
    }
}
#endif
