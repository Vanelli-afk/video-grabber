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

    @Test func resolvePostsURLAndDecodesSnakeCase() async throws {
        let recorder = RequestRecorder()
        respond(status: 200, json: """
        {"video_id":"abc","title":"Título","channel":"Canal","duration_seconds":213,
         "thumbnail_url":"https://i.ytimg.com/vi/abc/hq.jpg",
         "presets":[{"id":"best_mp4","label":"Melhor","kind":"video","estimated_bytes":123},
                    {"id":"audio_m4a","label":"Áudio","kind":"audio","estimated_bytes":null}]}
        """, recorder: recorder)

        let video = try await makeClient().resolve(url: "https://youtu.be/abc")

        #expect(video.videoId == "abc")
        #expect(video.durationSeconds == 213)
        #expect(video.thumbnail?.host() == "i.ytimg.com")
        #expect(video.presets.map(\.id) == ["best_mp4", "audio_m4a"])
        #expect(video.presets[0].estimatedBytes == 123)
        #expect(video.presets[1].estimatedBytes == nil)

        let request = try #require(recorder.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/v1/resolve")
        #expect(request.timeoutInterval == 120)
        let body = try #require(recorder.bodies.first ?? nil)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json == ["url": "https://youtu.be/abc"])
    }

    @Test func createJobSendsPresetIDInSnakeCase() async throws {
        let recorder = RequestRecorder()
        respond(status: 202, json: #"{"job_id":"job-42"}"#, recorder: recorder)

        let jobID = try await makeClient().createJob(url: "https://youtu.be/abc", presetID: "mp4_720")

        #expect(jobID == "job-42")
        let body = try #require(recorder.bodies.first ?? nil)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json == ["url": "https://youtu.be/abc", "preset_id": "mp4_720"])
    }

    @Test func jobStatusDecodesAllFields() async throws {
        respond(status: 200, json: """
        {"job_id":"j","status":"failed","progress":0.25,"file_size_bytes":null,"file_name":null,
         "error_code":"video_unavailable","error_message":"Indisponível"}
        """)

        let status = try await makeClient().jobStatus(id: "j")

        #expect(status.status == .failed)
        #expect(status.progress == 0.25)
        #expect(status.errorCode == "video_unavailable")
    }

    @Test func deleteJobAcceptsNoContent() async throws {
        let recorder = RequestRecorder()
        respond(status: 204, json: "", recorder: recorder)

        try await makeClient().deleteJob(id: "j")

        let request = try #require(recorder.requests.first)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path == "/v1/jobs/j")
    }

    @Test func fileRequestIsAuthenticated() async throws {
        let request = try await makeClient().fileRequest(id: "j")

        #expect(request.url?.absoluteString == "http://192.168.0.10:8080/v1/jobs/j/file")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
    }

    @Test func malformedBodyMapsToUnknown() async {
        respond(status: 200, json: "<html>não é JSON</html>")

        await #expect(throws: APIError.unknown) {
            try await makeClient().health()
        }
    }
}
