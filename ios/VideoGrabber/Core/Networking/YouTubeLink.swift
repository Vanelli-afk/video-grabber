import Foundation

/// Validação local do link antes de enviar ao servidor (que valida de novo).
enum YouTubeLink {
    static let allowedHosts: Set<String> = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be",
    ]

    /// Primeiro link do YouTube encontrado no texto. Aceita texto compartilhado
    /// ("Olha isto: https://youtu.be/abc") e links sem "https://".
    static func url(from text: String) -> URL? {
        for word in text.split(whereSeparator: \.isWhitespace) {
            var candidate = String(word)
            if !candidate.lowercased().hasPrefix("http") {
                candidate = "https://" + candidate
            }
            guard
                var components = URLComponents(string: candidate),
                let scheme = components.scheme?.lowercased(),
                scheme == "http" || scheme == "https",
                let host = components.host?.lowercased(),
                allowedHosts.contains(host)
            else { continue }
            components.host = host
            return components.url
        }
        return nil
    }
}
