import Foundation
import Testing
@testable import VideoGrabber

@Suite(.serialized)
struct APIClientTests {
    private static let baseURL = URL(string: "http://192.168.0.10:8080")!

    private func makeClient(baseURL: URL? = Self.baseURL, token: String? = "token-123") -> APIClient {
        APIClient(session: MockURLProtocol.makeSession()) {
            ServerConfiguration(baseURL: baseURL, token: token)
        }
    }

    private func respond(status: Int, json: String, recorder: RequestRecorder? = nil) {
        MockURLProtocol.handler = { request in
            recorder?.record(request)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(json.utf8))
        }
    }

    private func fail(with code: URLError.Code) {
        MockURLProtocol.handler = { _ in throw URLError(code) }
    }

    @Test func healthDecodesVersionWithoutToken() async throws {
        let recorder = RequestRecorder()
        respond(status: 200, json: #"{"status":"ok","ytdlp_version":"2026.10.26"}"#, recorder: recorder)

        let health = try await makeClient(token: nil).health()

        #expect(health == HealthResponse(status: "ok", ytdlpVersion: "2026.10.26"))
        let request = try #require(recorder.requests.first)
        #expect(request.url?.absoluteString == "http://192.168.0.10:8080/health")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.timeoutInterval == 15)
    }

    @Test func verifyTokenAcceptsJobNotFoundAndSendsBearer() async throws {
        let recorder = RequestRecorder()
        respond(status: 404, json: #"{"error_code":"job_not_found","message":"Job não encontrado."}"#, recorder: recorder)

        try await makeClient().verifyToken()

        let request = try #require(recorder.requests.first)
        #expect(request.url?.path == "/v1/jobs/00000000-0000-0000-0000-000000000000")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
    }

    @Test func verifyTokenRejectsInvalidToken() async {
        respond(status: 401, json: #"{"error_code":"unauthorized","message":"Token ausente ou inválido."}"#)

        await #expect(throws: APIError.unauthorized) {
            try await makeClient().verifyToken()
        }
    }

    @Test func missingServerAddressIsNotConfigured() async {
        await #expect(throws: APIError.notConfigured) {
            try await makeClient(baseURL: nil).health()
        }
    }

    @Test func missingTokenIsNotConfigured() async {
        await #expect(throws: APIError.notConfigured) {
            try await makeClient(token: "").verifyToken()
        }
    }

    @Test func offlineMapsToNoConnection() async {
        fail(with: .notConnectedToInternet)

        await #expect(throws: APIError.noConnection) {
            try await makeClient().health()
        }
    }

    @Test func refusedConnectionMapsToServerUnreachable() async {
        fail(with: .cannotConnectToHost)

        await #expect(throws: APIError.serverUnreachable) {
            try await makeClient().health()
        }
    }

    @Test func malformedBodyMapsToUnknown() async {
        respond(status: 200, json: "<html>não é JSON</html>")

        await #expect(throws: APIError.unknown) {
            try await makeClient().health()
        }
    }
}
