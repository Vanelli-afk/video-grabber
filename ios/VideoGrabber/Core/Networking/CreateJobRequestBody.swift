struct CreateJobRequestBody: Encodable, Sendable {
    let url: String
    let presetId: String
}
