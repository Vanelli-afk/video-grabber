import Foundation

/// Presets oferecidos pelo backend (`preset_id` em docs/API.md).
enum DownloadPreset: String, CaseIterable, Identifiable, Sendable {
    case bestMP4 = "best_mp4"
    case mp4720 = "mp4_720"
    case audioM4A = "audio_m4a"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bestMP4: String(localized: "Melhor qualidade (até 1080p)")
        case .mp4720: String(localized: "720p")
        case .audioM4A: String(localized: "Somente áudio (M4A)")
        }
    }
}
