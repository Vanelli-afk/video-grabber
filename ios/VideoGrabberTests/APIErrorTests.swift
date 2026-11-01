import Foundation
import Testing
@testable import VideoGrabber

struct APIErrorTests {
    @Test(arguments: [
        (401, #"{"error_code":"unauthorized","message":"x"}"#, APIError.unauthorized),
        (404, #"{"error_code":"video_unavailable","message":"x"}"#, APIError.videoUnavailable),
        (422, #"{"error_code":"unsupported_content","message":"x"}"#, APIError.unsupportedContent),
        (502, #"{"error_code":"extractor_failed","message":"Atualize o yt-dlp."}"#,
         APIError.server(code: "extractor_failed", message: "Atualize o yt-dlp.")),
        (500, "Internal Server Error", APIError.unknown),
    ])
    func mapsServerResponses(statusCode: Int, body: String, expected: APIError) {
        #expect(APIError(statusCode: statusCode, body: Data(body.utf8)) == expected)
    }

    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, APIError.noConnection),
        (.networkConnectionLost, .noConnection),
        (.cannotFindHost, .serverUnreachable),
        (.timedOut, .serverUnreachable),
        (.appTransportSecurityRequiresSecureConnection, .serverUnreachable),
        (.badURL, .unknown),
    ])
    func mapsNetworkErrors(code: URLError.Code, expected: APIError) {
        #expect(APIError(urlError: URLError(code)) == expected)
    }

    @Test func everyCaseHasPortugueseMessage() {
        let cases: [APIError] = [
            .notConfigured, .noConnection, .unauthorized, .serverUnreachable,
            .videoUnavailable, .unsupportedContent, .server(code: "x", message: ""), .unknown,
        ]
        for error in cases {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}
