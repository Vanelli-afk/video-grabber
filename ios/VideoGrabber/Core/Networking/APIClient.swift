import Foundation
import os

final class APIClient: APIClientProtocol {
    private static let logger = Logger(subsystem: "com.vanelliafk.videograbber", category: "APIClient")
    /// Job que nunca existe: consultá-lo valida o token sem efeito colateral (404 = token aceito).
    private static let probeJobID = "00000000-0000-0000-0000-000000000000"

    private let session: URLSession
    private let configuration: @Sendable () async -> ServerConfiguration

    init(session: URLSession = .shared, configuration: @escaping @Sendable () async -> ServerConfiguration) {
        self.session = session
        self.configuration = configuration
    }

    func health() async throws -> HealthResponse {
        let data = try await send(.health)
        return try decode(HealthResponse.self, from: data)
    }

    func verifyToken() async throws {
        do {
            _ = try await send(.job(id: Self.probeJobID))
        } catch APIError.server(code: "job_not_found", message: _) {
            return
        }
    }

    private func send(_ endpoint: Endpoint) async throws -> Data {
        let configuration = await configuration()
        guard let baseURL = configuration.baseURL else { throw APIError.notConfigured }

        var request = URLRequest(url: baseURL.appending(path: endpoint.path))
        request.httpMethod = endpoint.method
        request.timeoutInterval = endpoint.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.requiresAuthentication {
            guard let token = configuration.token, !token.isEmpty else { throw APIError.notConfigured }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch let error as URLError {
            Self.logger.error("Falha de rede em \(endpoint.path, privacy: .public): \(error.code.rawValue)")
            throw APIError(urlError: error)
        }

        let (data, response) = result
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.unknown }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError(statusCode: httpResponse.statusCode, body: data)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(type, from: data)
        } catch {
            Self.logger.error("Resposta inesperada do servidor: \(error.localizedDescription, privacy: .public)")
            throw APIError.unknown
        }
    }
}
