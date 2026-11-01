import Foundation

/// Resposta de `POST /v1/resolve`.
struct ResolveResponse: Decodable, Equatable, Sendable {
    let videoId: String
    let title: String
    let channel: String
    let durationSeconds: Int
    let thumbnailUrl: String?
    let presets: [PresetOption]

    var thumbnail: URL? {
        thumbnailUrl.flatMap(URL.init(string:))
    }
}
