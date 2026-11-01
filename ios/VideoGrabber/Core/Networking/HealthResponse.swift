struct HealthResponse: Decodable, Equatable, Sendable {
    let status: String
    let ytdlpVersion: String
}
