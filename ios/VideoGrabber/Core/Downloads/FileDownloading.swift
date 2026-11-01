import Foundation

protocol FileDownloading: Sendable {
    /// Baixa para um arquivo temporário que passa a ser do chamador (ele move ou apaga).
    /// `progress` recebe a fração transferida (0...1), em qualquer thread.
    func download(_ request: URLRequest, progress: @escaping @Sendable (Double) -> Void) async throws -> URL
}
