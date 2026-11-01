import Foundation

/// Guarda as requisições vistas pelo MockURLProtocol (que roda em outra thread).
final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []

    var requests: [URLRequest] {
        lock.withLock { storage }
    }

    func record(_ request: URLRequest) {
        lock.withLock { storage.append(request) }
    }
}
