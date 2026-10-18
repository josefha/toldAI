import XCTest

final class ToldUITests: XCTestCase {
    @MainActor func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func onboard(_ app: XCUIApplication, extraArguments: [String] = []) {
        app.launchArguments = ["--reset-demo", "--ui-testing"] + extraArguments
        app.launch()
        let email = app.textFields["emailField"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap(); email.typeText("josef@example.com")
        app.buttons["authContinue"].tap()
        let code = app.textFields["codeField"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.tap(); code.typeText("123456")
        app.buttons["authContinue"].tap()
        let finish = app.buttons["finishOnboarding"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        app.swipeUp(); finish.tap()
        XCTAssertTrue(app.buttons["playBriefing"].waitForExistence(timeout: 10))
        capture(app, "home")
    }
    @MainActor func testListeningQuestionAndResumeJourney() throws {
        let app = XCUIApplication(); onboard(app)
        app.buttons["playBriefing"].tap()
        let ask = app.buttons["typeQuestion"]
        XCTAssertTrue(ask.waitForExistence(timeout: 5))
        capture(app, "player")
        app.swipeUp(); ask.tap()
        let question = app.descendants(matching: .any)["questionField"].firstMatch
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        question.tap(); question.typeText("Why does this matter?")
        app.swipeUp(); app.buttons["sendQuestion"].tap()
        XCTAssertTrue(app.staticTexts["answerText"].waitForExistence(timeout: 5))
        app.swipeUp(); app.buttons["continueListening"].tap()
        XCTAssertTrue(app.buttons["playerTransport"].waitForExistence(timeout: 5))
        app.buttons["collapsePlayer"].tap()
        XCTAssertTrue(app.buttons["miniPlayer"].waitForExistence(timeout: 5))
        capture(app, "mini-player")
        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.buttons["signOut"].waitForExistence(timeout: 5))
    }
    @MainActor func testAskStartsSharedPlayer() throws {
        let app = XCUIApplication(); onboard(app)
        app.tabBars.buttons["Ask"].tap()
        capture(app, "ask-tab")
        app.buttons["topictypeQuestion"].tap()
        let field = app.descendants(matching: .any)["researchField"].firstMatch
        field.tap(); field.typeText("Explain ocean science")
        app.buttons["dismissAskKeyboard"].tap()
        reveal(app.buttons["submitResearch"], in: app); app.buttons["submitResearch"].tap()
        XCTAssertTrue(app.buttons["playerTransport"].waitForExistence(timeout: 5))
        let ask = app.buttons["askButton"]; reveal(ask, in: app); ask.tap()
        XCTAssertTrue(app.otherElements["listeningState"].exists || app.staticTexts["Listening…"].exists)
        reveal(app.buttons["sendVoiceQuestion"], in: app); app.buttons["sendVoiceQuestion"].tap()
        XCTAssertTrue(app.staticTexts["answerText"].waitForExistence(timeout: 5))
        capture(app, "ask-deep-dive")
        app.buttons["collapsePlayer"].tap()
        XCTAssertTrue(app.buttons["miniPlayer"].exists)
    }

    @MainActor func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 { if element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor func testDetailsDemoRecordingAndSignOut() throws {
        let app = XCUIApplication(); onboard(app, extraArguments: ["--dark"])
        capture(app, "home-dark")
        app.buttons["dailyBriefing"].tap()
        XCTAssertTrue(app.buttons["playAll"].waitForExistence(timeout: 5))
        app.staticTexts["The next wave of AI"].firstMatch.tap()
        let listen = app.buttons["Listen to Story"]
        XCTAssertTrue(listen.waitForExistence(timeout: 5))
        reveal(app.buttons["View Sources"], in: app); app.buttons["View Sources"].tap()
        XCTAssertTrue(app.navigationBars["Sources"].waitForExistence(timeout: 5))
        capture(app, "sources-dark")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        for _ in 0..<4 { if listen.isHittable { break }; app.swipeDown() }
        listen.tap()
        let ask = app.buttons["askButton"]; XCTAssertTrue(ask.waitForExistence(timeout: 5)); capture(app, "player-dark")
        reveal(ask, in: app); ask.tap()
        app.buttons["sendVoiceQuestion"].tap()
        XCTAssertTrue(app.staticTexts["answerText"].waitForExistence(timeout: 5))
        capture(app, "answer-dark")
        reveal(app.buttons["continueListening"], in: app); app.buttons["continueListening"].tap()
        app.buttons["collapsePlayer"].tap()
        app.tabBars.buttons["You"].tap()
        app.buttons["signOut"].tap()
        let confirm = app.buttons["confirmSignOut"]; XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.textFields["emailField"].waitForExistence(timeout: 5))
    }
    @MainActor func testOfflineAndMicrophoneFallback() throws {
        let app = XCUIApplication(); onboard(app)
        app.tabBars.buttons["You"].tap(); app.buttons["Developer Tools"].tap()
        let offline = app.switches["Offline"]
        offline.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(offline.value as? String, "1")
        let microphone = app.switches["Deny microphone access"]
        microphone.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(microphone.value as? String, "1")
        capture(app, "demo-settings")
        app.tabBars.buttons["Home"].tap()
        app.buttons["playBriefing"].tap()
        let ask = app.buttons["askButton"]; XCTAssertTrue(ask.waitForExistence(timeout: 5)); reveal(ask, in: app); ask.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Microphone access is denied")).firstMatch.waitForExistence(timeout: 5))
        let question = app.descendants(matching: .any)["questionField"].firstMatch
        question.tap(); question.typeText("Explain this")
        reveal(app.buttons["sendQuestion"], in: app); app.buttons["sendQuestion"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "You’re offline")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "offline-question")
        reveal(app.buttons["Cancel"], in: app); app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["playerTransport"].exists)
    }


    @MainActor func testLargeTextLayout() throws {
        let app = XCUIApplication(); onboard(app)
        app.terminate()
        app.launchArguments = ["--ui-testing", "--large-type", "--dark"]
        app.launch()
        let play = app.buttons["playBriefing"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        capture(app, "home-accessibility")
        reveal(play, in: app); play.tap()
        let ask = app.buttons["askButton"]
        XCTAssertTrue(ask.waitForExistence(timeout: 5)); reveal(ask, in: app)
        capture(app, "player-accessibility")
        ask.tap()
        let resume = app.buttons["Cancel"]
        reveal(resume, in: app); resume.tap()
        XCTAssertTrue(app.buttons["playerTransport"].exists)
    }

}
