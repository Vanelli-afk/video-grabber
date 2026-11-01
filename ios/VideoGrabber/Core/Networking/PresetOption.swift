/// Um preset oferecido pelo servidor para um vídeo específico.
struct PresetOption: Decodable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let label: String
    let kind: String
    let estimatedBytes: Int64?
}
