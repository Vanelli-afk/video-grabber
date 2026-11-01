import Foundation

protocol APIClientProtocol: Sendable {
    func health() async throws -> HealthResponse
    /// Confirma que o servidor aceita o token salvo.
    func verifyToken() async throws
    func resolve(url: String) async throws -> ResolveResponse
    /// Devolve o `job_id` criado no servidor.
    func createJob(url: String, presetID: String) async throws -> String
    func jobStatus(id: String) async throws -> JobStatusResponse
    /// Requisição autenticada do arquivo final, para o URLSession baixar.
    func fileRequest(id: String) async throws -> URLRequest
    func deleteJob(id: String) async throws
}
