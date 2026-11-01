import Foundation

enum APIError: Error, Equatable, LocalizedError {
    case notConfigured
    case noConnection
    case unauthorized
    case serverUnreachable
    case videoUnavailable
    case unsupportedContent
    /// Outros erros com corpo `{ error_code, message }` do servidor.
    case server(code: String, message: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            String(localized: "Configure o endereço do servidor e o token em Ajustes.")
        case .noConnection:
            String(localized: "Sem conexão. Confira o Wi-Fi ou os dados móveis. Se o servidor estiver na sua casa, confira também a permissão de Rede Local (Ajustes › Privacidade e Segurança › Rede Local).")
        case .unauthorized:
            String(localized: "Token de acesso inválido.")
        case .serverUnreachable:
            String(localized: "Não foi possível alcançar o servidor. Confira o endereço e se ele está ligado.")
        case .videoUnavailable:
            String(localized: "Vídeo indisponível, privado ou com restrição de acesso.")
        case .unsupportedContent:
            String(localized: "Conteúdo não suportado (playlist, transmissão ao vivo ou protegido).")
        case .server(_, let message):
            message.isEmpty ? String(localized: "O servidor recusou o pedido.") : message
        case .unknown:
            String(localized: "Ocorreu um erro inesperado.")
        }
    }
}

extension APIError {
    init(urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            self = .noConnection
        case .cannotFindHost, .cannotConnectToHost, .timedOut, .dnsLookupFailed,
             .secureConnectionFailed, .appTransportSecurityRequiresSecureConnection:
            self = .serverUnreachable
        default:
            self = .unknown
        }
    }

    /// A partir do `error_code` do servidor (corpo de erro HTTP ou job com `status = failed`).
    init(serverCode: String, message: String) {
        switch serverCode {
        case "unauthorized":
            self = .unauthorized
        case "video_unavailable":
            self = .videoUnavailable
        case "unsupported_content":
            self = .unsupportedContent
        default:
            self = .server(code: serverCode, message: message)
        }
    }

    init(statusCode: Int, body: Data) {
        if statusCode == 401 {
            self = .unauthorized
        } else if let serverError = try? JSONDecoder().decode(ServerErrorBody.self, from: body) {
            self = APIError(serverCode: serverError.errorCode, message: serverError.message)
        } else {
            self = .unknown
        }
    }
}
