import Foundation

/// Download em primeiro plano com progresso. A Fase 5 troca por uma sessão em segundo plano.
struct URLSessionFileDownloader: FileDownloading {
    func download(_ request: URLRequest, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let delegate = DownloadTaskDelegate(progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegate.start(session.downloadTask(with: request), continuation: continuation)
            }
        } onCancel: {
            delegate.cancel()
        }
    }
}

private final class DownloadTaskDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let progress: @Sendable (Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    private var task: URLSessionDownloadTask?
    private var isCancelled = false
    private var downloadedFile: URL?
    private var failure: Error?

    init(progress: @escaping @Sendable (Double) -> Void) {
        self.progress = progress
    }

    func start(_ task: URLSessionDownloadTask, continuation: CheckedContinuation<URL, Error>) {
        let cancelledEarly = lock.withLock {
            self.task = task
            self.continuation = continuation
            return isCancelled
        }
        task.resume()
        if cancelledEarly {
            task.cancel()
        }
    }

    func cancel() {
        let task = lock.withLock {
            isCancelled = true
            return self.task
        }
        task?.cancel()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // O arquivo temporário some quando este método retorna: precisa ser movido aqui.
        if let response = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            let body = (try? Data(contentsOf: location)) ?? Data()
            lock.withLock { failure = APIError(statusCode: response.statusCode, body: body) }
            return
        }
        let destination = FileManager.default.temporaryDirectory.appending(path: "download-\(UUID().uuidString)")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            lock.withLock { downloadedFile = destination }
        } catch {
            lock.withLock { failure = error }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let (continuation, file, failure) = lock.withLock {
            let pending = self.continuation
            self.continuation = nil
            return (pending, downloadedFile, self.failure)
        }
        if let error {
            continuation?.resume(throwing: error)
        } else if let failure {
            continuation?.resume(throwing: failure)
        } else if let file {
            continuation?.resume(returning: file)
        } else {
            continuation?.resume(throwing: APIError.unknown)
        }
    }
}
