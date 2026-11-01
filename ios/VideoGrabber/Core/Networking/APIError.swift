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

    init(statusCode: Int, body: Data) {
        let serverError = try? JSONDecoder().decode(ServerErrorBody.self, from: body)
        switch (statusCode, serverError?.errorCode) {
        case (401, _):
            self = .unauthorized
        case (_, "video_unavailable"):
            self = .videoUnavailable
        case (_, "unsupported_content"):
            self = .unsupportedContent
        case (_, let code?):
            self = .server(code: code, message: serverError?.message ?? "")
        default:
            self = .unknown
        }
    }
}
