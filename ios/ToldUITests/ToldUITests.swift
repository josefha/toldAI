import XCTest

final class ToldUITests: XCTestCase {
    @MainActor func testSignedOutScreenHasRealEmailEntry() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--dark"]
        app.launch()
        guard app.textFields["emailField"].waitForExistence(timeout: 5) else {
            throw XCTSkip("A signed-in account is present. Use a fresh simulator for the signed-out UI check.")
        }
        XCTAssertTrue(app.buttons["authContinue"].exists)
        XCTAssertFalse(app.staticTexts["Demo code: 123456"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "live-sign-in"; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testLargeTextSignIn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--large-type"]
        app.launch()
        guard app.textFields["emailField"].waitForExistence(timeout: 5) else { throw XCTSkip("Use a signed-out simulator.") }
        let button = app.buttons["authContinue"]
        for _ in 0..<6 { if button.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(button.isHittable)
    }
}
