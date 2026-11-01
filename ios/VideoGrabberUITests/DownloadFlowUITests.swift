import XCTest

/// Fluxo principal com serviços falsos (`-ui-testing`): colar URL → buscar → baixar → Biblioteca.
final class DownloadFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testPasteResolveAndDownload() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let urlField = app.textFields["add.url"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 10))
        urlField.tap()
        urlField.typeText("https://www.youtube.com/watch?v=jNQXAC9IVRw")

        app.buttons["add.search"].tap()

        let downloadButton = app.buttons["add.download"]
        XCTAssertTrue(downloadButton.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Me at the zoo"].exists)
        downloadButton.tap()

        // O app troca sozinho para a aba Fila, onde o download termina.
        XCTAssertTrue(app.staticTexts["Concluído"].waitForExistence(timeout: 10))

        app.tabBars.buttons["Biblioteca"].tap()
        XCTAssertTrue(app.staticTexts["Me at the zoo"].waitForExistence(timeout: 10))
    }
}
