/// Resposta de `GET /v1/jobs/{id}`.
struct JobStatusResponse: Decodable, Equatable, Sendable {
    enum Status: String, Decodable, Sendable {
        case queued
        case preparing
        case ready
        case failed
    }

    let jobId: String
    let status: Status
    /// Preparo no servidor, de 0 a 1.
    let progress: Double
    let fileSizeBytes: Int64?
    let fileName: String?
    let errorCode: String?
    let errorMessage: String?
}
