import Foundation
import Testing
@testable import VideoGrabber

struct VideoStoreTests {
    private let store = VideoStore(
        baseDirectory: FileManager.default.temporaryDirectory.appending(path: "store-tests-\(UUID().uuidString)")
    )

    private func makeTemporaryFile(_ contents: String) throws -> URL {
        let file = FileManager.default.temporaryDirectory.appending(path: "tmp-\(UUID().uuidString)")
        try Data(contents.utf8).write(to: file)
        return file
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    @Test func importMovesFileAndReportsSize() throws {
        let temporary = try makeTemporaryFile("12345678")

        let stored = try store.importVideo(from: temporary, fileExtension: "mp4")

        #expect(stored.sizeBytes == 8)
        #expect(stored.fileName.hasSuffix(".mp4"))
        #expect(exists(store.videoURL(for: stored.fileName)))
        #expect(!exists(temporary))
    }

    @Test func importedFilesGetUniqueNames() throws {
        let first = try store.importVideo(from: try makeTemporaryFile("a"), fileExtension: "m4a")
        let second = try store.importVideo(from: try makeTemporaryFile("b"), fileExtension: "m4a")
        #expect(first.fileName != second.fileName)
    }

    @Test func savesAndDeletesFiles() throws {
        let stored = try store.importVideo(from: try makeTemporaryFile("video"), fileExtension: "mp4")
        let thumbnail = try store.saveThumbnail(Data("jpg".utf8), id: UUID())
        #expect(exists(store.thumbnailURL(for: thumbnail)))

        store.deleteFiles(videoFileName: stored.fileName, thumbnailFileName: thumbnail)

        #expect(!exists(store.videoURL(for: stored.fileName)))
        #expect(!exists(store.thumbnailURL(for: thumbnail)))
    }
}
