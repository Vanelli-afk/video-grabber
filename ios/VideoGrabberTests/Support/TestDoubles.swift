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

struct StubAPIClient: APIClientProtocol {
    var healthResult: Result<HealthResponse, APIError> = .success(HealthResponse(status: "ok", ytdlpVersion: "2026.10.26"))
    var verifyTokenResult: Result<Void, APIError> = .success(())

    func health() async throws -> HealthResponse {
        try healthResult.get()
    }

    func verifyToken() async throws {
        try verifyTokenResult.get()
    }
}
