/// Corpo de erro do backend: `{ "error_code": "...", "message": "..." }`.
struct ServerErrorBody: Decodable, Sendable {
    let errorCode: String
    let message: String

    private enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case message
    }
}
