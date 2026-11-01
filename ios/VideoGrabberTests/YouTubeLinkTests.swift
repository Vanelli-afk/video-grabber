import Testing
@testable import VideoGrabber

struct YouTubeLinkTests {
    @Test(arguments: [
        ("https://www.youtube.com/watch?v=abc", "https://www.youtube.com/watch?v=abc"),
        ("https://youtu.be/abc?si=xyz", "https://youtu.be/abc?si=xyz"),
        ("youtu.be/abc", "https://youtu.be/abc"),
        ("m.youtube.com/watch?v=abc", "https://m.youtube.com/watch?v=abc"),
        ("https://music.youtube.com/watch?v=abc", "https://music.youtube.com/watch?v=abc"),
        ("Veja isto: https://youtu.be/abc 😄", "https://youtu.be/abc"),
        ("  https://YOUTUBE.com/shorts/abc  ", "https://youtube.com/shorts/abc"),
    ])
    func findsYouTubeLinks(text: String, expected: String) {
        #expect(YouTubeLink.url(from: text)?.absoluteString == expected)
    }

    @Test(arguments: [
        "",
        "abc",
        "https://vimeo.com/1",
        "https://youtube.com.evil.example/watch?v=abc",
        "ftp://youtube.com/watch?v=abc",
    ])
    func rejectsOtherText(text: String) {
        #expect(YouTubeLink.url(from: text) == nil)
    }
}
