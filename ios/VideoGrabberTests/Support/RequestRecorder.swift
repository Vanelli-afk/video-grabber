import Foundation

/// Guarda as requisições vistas pelo MockURLProtocol (que roda em outra thread).
final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []
    private var bodyStorage: [Data?] = []

    var requests: [URLRequest] {
        lock.withLock { storage }
    }

    /// Corpo de cada requisição (no URLProtocol ele chega como stream, não em `httpBody`).
    var bodies: [Data?] {
        lock.withLock { bodyStorage }
    }

    func record(_ request: URLRequest) {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll)
        lock.withLock {
            storage.append(request)
            bodyStorage.append(body)
        }
    }

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
