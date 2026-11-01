import Foundation
import SwiftData

/// Um vídeo (ou áudio) já baixado e guardado no aparelho.
@Model
final class VideoItem {
    @Attribute(.unique) var id: UUID
    /// ID do YouTube.
    var videoID: String
    var title: String
    var channel: String
    var durationSeconds: Int
    var presetID: String
    /// Relativo a `VideoStore.videosDirectory`.
    var fileName: String
    var fileSizeBytes: Int64
    /// Relativo a `VideoStore.thumbnailsDirectory`.
    var thumbnailFileName: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        videoID: String,
        title: String,
        channel: String,
        durationSeconds: Int,
        presetID: String,
        fileName: String,
        fileSizeBytes: Int64,
        thumbnailFileName: String?,
        createdAt: Date = .now
    ) {
        self.id = id
        self.videoID = videoID
        self.title = title
        self.channel = channel
        self.durationSeconds = durationSeconds
        self.presetID = presetID
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.thumbnailFileName = thumbnailFileName
        self.createdAt = createdAt
    }
}
