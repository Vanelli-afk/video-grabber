import Foundation

enum Endpoint: Sendable {
    case health
    case resolve
    case createJob
    case job(id: String)
    case jobFile(id: String)
    case deleteJob(id: String)

    var path: String {
        switch self {
        case .health: "health"
        case .resolve: "v1/resolve"
        case .createJob: "v1/jobs"
        case .job(let id), .deleteJob(let id): "v1/jobs/\(id)"
        case .jobFile(let id): "v1/jobs/\(id)/file"
        }
    }

    var method: String {
        switch self {
        case .resolve, .createJob: "POST"
        case .deleteJob: "DELETE"
        case .health, .job, .jobFile: "GET"
        }
    }

    /// Curto para consultas rápidas: um endereço errado falha logo em vez de esperar 60 s.
    var timeout: TimeInterval {
        switch self {
        case .health, .createJob, .job, .deleteJob: 15
        // O servidor só responde depois que o yt-dlp extrai os dados do vídeo.
        case .resolve: 120
        // Tempo máximo sem receber dados (não é o limite da transferência inteira).
        case .jobFile: 60
        }
    }

    var requiresAuthentication: Bool {
        switch self {
        case .health: false
        case .resolve, .createJob, .job, .jobFile, .deleteJob: true
        }
    }
}
