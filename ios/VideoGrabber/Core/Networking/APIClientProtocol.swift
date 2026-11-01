protocol APIClientProtocol: Sendable {
    func health() async throws -> HealthResponse
    /// Confirma que o servidor aceita o token salvo.
    func verifyToken() async throws
}
