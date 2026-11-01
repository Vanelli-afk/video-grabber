import Foundation

enum Endpoint: Sendable {
    case health
    case job(id: String)

    var path: String {
        switch self {
        case .health: "health"
        case .job(let id): "v1/jobs/\(id)"
        }
    }

    var method: String {
        switch self {
        case .health, .job: "GET"
        }
    }

    /// Curto para consultas rápidas: um endereço errado falha logo em vez de esperar 60 s.
    /// Rotas que esperam o yt-dlp (resolve, Fase 3) precisam de um valor maior.
    var timeout: TimeInterval {
        switch self {
        case .health, .job: 15
        }
    }

    var requiresAuthentication: Bool {
        switch self {
        case .health: false
        case .job: true
        }
    }
}
