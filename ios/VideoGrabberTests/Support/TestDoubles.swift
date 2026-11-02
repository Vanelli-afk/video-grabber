import Foundation
@testable import VideoGrabber

final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func readToken() -> String? {
        lock.withLock { token }
    }

    func saveToken(_ token: String) throws {
        lock.withLock { self.token = token }
    }

    func deleteToken() throws {
        lock.withLock { token = nil }
    }
}

/// APIClient falso. Configure os resultados antes de usar; é seguro entre threads.
final class StubAPIClient: APIClientProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _healthResult: Result<HealthResponse, APIError>
    private var _verifyTokenResult: Result<Void, APIError>
    private var _resolveResult: Result<ResolveResponse, APIError> = .success(.sample)
    private var _createJobResult: Result<String, APIError> = .success("server-job-1")
    /// Consumidos em ordem; o último se repete.
    private var _jobStatuses: [JobStatusResponse] = [.ready]
    private var _deletedJobIDs: [String] = []
    private var _resolveGate: Gate?

    init(
        healthResult: Result<HealthResponse, APIError> = .success(HealthResponse(status: "ok", ytdlpVersion: "2026.10.26")),
        verifyTokenResult: Result<Void, APIError> = .success(())
    ) {
        _healthResult = healthResult
        _verifyTokenResult = verifyTokenResult
    }

    var resolveResult: Result<ResolveResponse, APIError> {
        get { lock.withLock { _resolveResult } }
        set { lock.withLock { _resolveResult = newValue } }
    }

    /// Com uma trava, `resolve` só responde depois de `gate.open()`.
    var resolveGate: Gate? {
        get { lock.withLock { _resolveGate } }
        set { lock.withLock { _resolveGate = newValue } }
    }

    var jobStatuses: [JobStatusResponse] {
        get { lock.withLock { _jobStatuses } }
        set { lock.withLock { _jobStatuses = newValue } }
    }

    var deletedJobIDs: [String] {
        lock.withLock { _deletedJobIDs }
    }

    func health() async throws -> HealthResponse {
        try lock.withLock { _healthResult }.get()
    }

    func verifyToken() async throws {
        try lock.withLock { _verifyTokenResult }.get()
    }

    func resolve(url: String) async throws -> ResolveResponse {
        if let gate = resolveGate {
            await gate.wait()
        }
        return try resolveResult.get()
    }

    func createJob(url: String, presetID: String) async throws -> String {
        try lock.withLock { _createJobResult }.get()
    }

    func jobStatus(id: String) async throws -> JobStatusResponse {
        lock.withLock {
            _jobStatuses.count > 1 ? _jobStatuses.removeFirst() : _jobStatuses[0]
        }
    }

    func fileRequest(id: String) async throws -> URLRequest {
        URLRequest(url: URL(filePath: "/dev/null"))
    }

    func deleteJob(id: String) async throws {
        lock.withLock { _deletedJobIDs.append(id) }
    }
}

/// Grava um arquivo temporário. Com `gate`, só termina depois de `gate.open()`.
struct StubFileDownloader: FileDownloading {
    var contents = Data("video".utf8)
    var gate: Gate?

    func download(_ request: URLRequest, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        if let gate {
            await gate.wait()
        }
        progress(0.5)
        progress(1)
        let file = FileManager.default.temporaryDirectory.appending(path: "stub-\(UUID().uuidString)")
        try contents.write(to: file)
        return file
    }
}

actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

extension ResolveResponse {
    static let sample = ResolveResponse(
        videoId: "jNQXAC9IVRw",
        title: "Me at the zoo",
        channel: "jawed",
        durationSeconds: 19,
        thumbnailUrl: "https://i.ytimg.com/vi/jNQXAC9IVRw/hqdefault.jpg",
        presets: [
            PresetOption(id: "best_mp4", label: "Melhor qualidade (até 1080p)", kind: "video", estimatedBytes: 1_009_829),
            PresetOption(id: "mp4_720", label: "720p", kind: "video", estimatedBytes: 1_009_829),
            PresetOption(id: "audio_m4a", label: "Somente áudio (M4A)", kind: "audio", estimatedBytes: 309_288),
        ]
    )
}

extension JobStatusResponse {
    static let ready = JobStatusResponse(
        jobId: "server-job-1", status: .ready, progress: 1, fileSizeBytes: 5,
        fileName: "Me at the zoo.mp4", errorCode: nil, errorMessage: nil
    )

    static func preparing(_ progress: Double) -> JobStatusResponse {
        JobStatusResponse(
            jobId: "server-job-1", status: .preparing, progress: progress, fileSizeBytes: nil,
            fileName: nil, errorCode: nil, errorMessage: nil
        )
    }

    static func failed(code: String, message: String) -> JobStatusResponse {
        JobStatusResponse(
            jobId: "server-job-1", status: .failed, progress: 0, fileSizeBytes: nil,
            fileName: nil, errorCode: code, errorMessage: message
        )
    }
}
