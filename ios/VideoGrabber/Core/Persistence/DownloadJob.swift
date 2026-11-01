import Foundation
import SwiftData

/// Um download na fila. Só o `DownloadManager` muda o estado (`state`).
@Model
final class DownloadJob {
    @Attribute(.unique) var id: UUID
    var sourceURL: String
    var videoID: String
    var title: String
    var channel: String
    var durationSeconds: Int
    var thumbnailURL: String?
    var presetID: String
    var serverJobID: String?
    /// `DownloadState.rawValue`; use `state`.
    var stateRaw: String
    /// 0...1: preparo no servidor (30%) + transferência (70%).
    var progress: Double
    var errorMessage: String?
    var resumeData: Data?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceURL: String,
        videoID: String,
        title: String,
        channel: String,
        durationSeconds: Int,
        thumbnailURL: String?,
        presetID: String,
        state: DownloadState = .queued,
        createdAt: Date = .now
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.videoID = videoID
        self.title = title
        self.channel = channel
        self.durationSeconds = durationSeconds
        self.thumbnailURL = thumbnailURL
        self.presetID = presetID
        self.stateRaw = state.rawValue
        self.progress = 0
        self.createdAt = createdAt
    }

    var state: DownloadState {
        get { DownloadState(rawValue: stateRaw) ?? .failed }
        set { stateRaw = newValue.rawValue }
    }
}
