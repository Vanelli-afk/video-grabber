import Testing
@testable import VideoGrabber

struct FormattersTests {
    @Test(arguments: [
        (0, "0:00"),
        (9, "0:09"),
        (213, "3:33"),
        (3599, "59:59"),
        (3600, "1:00:00"),
        (3723, "1:02:03"),
        (-5, "0:00"),
    ])
    func formatsDuration(seconds: Int, expected: String) {
        #expect(Formatters.duration(seconds) == expected)
    }

    @Test func formatsByteCount() {
        #expect(Formatters.byteCount(0).isEmpty == false)
        #expect(Formatters.byteCount(12_300_000).contains("MB"))
        #expect(Formatters.byteCount(2_000_000_000).contains("GB"))
    }
}
