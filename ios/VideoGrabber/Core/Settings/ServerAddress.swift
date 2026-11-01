import Foundation

enum ServerAddress {
    /// Normaliza o endereço digitado: aceita "192.168.0.10:8080" (assume http) e remove "/" no fim.
    static func url(from text: String) -> URL? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.contains("://") {
            value = "http://" + value
        }
        while value.hasSuffix("/") {
            value.removeLast()
        }
        guard
            let components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host, !host.isEmpty,
            components.query == nil,
            components.fragment == nil
        else { return nil }
        return components.url
    }
}
