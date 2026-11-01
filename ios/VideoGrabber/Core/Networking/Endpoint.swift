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

    var requiresAuthentication: Bool {
        switch self {
        case .health: false
        case .job: true
        }
    }
}
