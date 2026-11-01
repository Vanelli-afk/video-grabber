import Foundation

/// Arquivos baixados e miniaturas. Ficam em Application Support: não são apagados
/// pelo sistema como os do cache.
struct VideoStore: Sendable {
    struct StoredVideo: Equatable, Sendable {
        let fileName: String
        let sizeBytes: Int64
    }

    let videosDirectory: URL
    let thumbnailsDirectory: URL

    init(baseDirectory: URL) {
        videosDirectory = baseDirectory.appending(path: "Videos", directoryHint: .isDirectory)
        thumbnailsDirectory = baseDirectory.appending(path: "Thumbnails", directoryHint: .isDirectory)
    }

    /// Move o arquivo baixado para a biblioteca com um nome único.
    func importVideo(from temporaryFile: URL, fileExtension: String) throws -> StoredVideo {
        try FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let destination = videoURL(for: fileName)
        try FileManager.default.moveItem(at: temporaryFile, to: destination)
        let size = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        return StoredVideo(fileName: fileName, sizeBytes: Int64(size))
    }

    func saveThumbnail(_ data: Data, id: UUID) throws -> String {
        try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        let fileName = "\(id.uuidString).jpg"
        try data.write(to: thumbnailURL(for: fileName), options: .atomic)
        return fileName
    }

    func videoURL(for fileName: String) -> URL {
        videosDirectory.appending(path: fileName)
    }

    func thumbnailURL(for fileName: String) -> URL {
        thumbnailsDirectory.appending(path: fileName)
    }

    func deleteFiles(videoFileName: String, thumbnailFileName: String?) {
        try? FileManager.default.removeItem(at: videoURL(for: videoFileName))
        if let thumbnailFileName {
            try? FileManager.default.removeItem(at: thumbnailURL(for: thumbnailFileName))
        }
    }
}
