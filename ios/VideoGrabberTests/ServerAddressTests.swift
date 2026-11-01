import Testing
@testable import VideoGrabber

struct ServerAddressTests {
    @Test(arguments: [
        ("http://192.168.0.10:8080", "http://192.168.0.10:8080"),
        ("192.168.0.10:8080", "http://192.168.0.10:8080"),
        ("  https://meu-servidor.example.com/  ", "https://meu-servidor.example.com"),
        ("http://mac-mini.local:8080//", "http://mac-mini.local:8080"),
    ])
    func acceptsAndNormalizes(input: String, expected: String) {
        #expect(ServerAddress.url(from: input)?.absoluteString == expected)
    }

    @Test(arguments: ["", "   ", "ftp://192.168.0.10", "http://", "http://host:8080/?x=1", "http://host#frag"])
    func rejectsInvalid(input: String) {
        #expect(ServerAddress.url(from: input) == nil)
    }
}
