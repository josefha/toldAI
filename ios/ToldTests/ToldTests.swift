import XCTest
@testable import Told

@MainActor final class ToldTests: XCTestCase {
    var local: LocalStore!
    var controls: DemoControls!
    var backend: MockBackend!
    override func setUp() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        local = LocalStore(defaults: defaults); controls = DemoControls()
        backend = MockBackend(controls: controls, store: local, latency: .milliseconds(10))
    }
    func testOTPVerificationAndOneTimeUse() async throws {
        _ = try await backend.sendCode(email: "test@example.com")
        do { _ = try await backend.verifyCode(email: "test@example.com", code: "000000"); XCTFail("Wrong code accepted") } catch { }
        let session = try await backend.verifyCode(email: "test@example.com", code: "123456")
        XCTAssertEqual(session.email, "test@example.com")
        do { _ = try await backend.verifyCode(email: "test@example.com", code: "123456"); XCTFail("Code reused") } catch { }
    }
    func testExpiredCodeAndOfflineRecovery() async throws {
        _ = try await backend.sendCode(email: "test@example.com")
        controls.expireCode = true
        do { _ = try await backend.verifyCode(email: "test@example.com", code: "123456"); XCTFail() } catch { }
        controls.offline = true
        do { _ = try await backend.dailyBriefing(interests: []); XCTFail() } catch { }
        controls.offline = false
        let briefing = try await backend.dailyBriefing(interests: [.planet])
        XCTAssertEqual(briefing.stories.count, 5)
        XCTAssertEqual(briefing.stories.first?.category, .planet)
    }
    func testProfileAndDomainRoundTrip() async throws {
        var profile = UserProfile(userID: "a", email: "a@example.com")
        profile.interests = [.science, .planet]; profile.location = "Sweden"; profile.completedOnboarding = true
        try await backend.save(profile)
        let restored = try await backend.load(userID: "a")
        XCTAssertEqual(profile, restored)
        let other = try await backend.load(userID: "b")
        XCTAssertNil(other)
        let briefing = try await backend.dailyBriefing(interests: profile.interests)
        let data = try JSONEncoder().encode(briefing)
        XCTAssertEqual(try JSONDecoder().decode(Briefing.self, from: data), briefing)
    }
    func testQuestionCancelRejectsLateAnswerAndRestoresCheckpoint() async throws {
        let briefing = try await backend.dailyBriefing(interests: [])
        let audio = PlaybackController(store: local)
        audio.start(briefing); audio.seek(8); audio.pause()
        let conversation = ConversationModel(news: backend, playback: audio, controls: controls)
        conversation.begin(); conversation.draft = "Why?"; conversation.submit(); conversation.cancel()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(conversation.phase, .idle)
        XCTAssertTrue(conversation.answers.isEmpty)
        XCTAssertFalse(audio.isAnswer)
        XCTAssertEqual(audio.position, 8, accuracy: 0.4)
        XCTAssertFalse(audio.isPlaying)
    }
    func testAnswerContinueRestoresStoryAndPosition() async throws {
        let briefing = try await backend.dailyBriefing(interests: [])
        let audio = PlaybackController(store: local)
        audio.start(briefing, at: 1); audio.seek(12); audio.pause()
        let conversation = ConversationModel(news: backend, playback: audio, controls: controls)
        conversation.begin(); conversation.draft = "Explain"; conversation.submit()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(conversation.phase, .answered)
        XCTAssertTrue(audio.isAnswer)
        conversation.cancel(resume: true)
        XCTAssertEqual(audio.story?.id, briefing.stories[1].id)
        XCTAssertEqual(audio.position, 12, accuracy: 0.4)
        XCTAssertFalse(audio.isAnswer)
        audio.pause()
    }
    func testRefreshDoesNotReplaceActiveQueueAndSignOutClears() async throws {
        let app = AppModel(auth: backend, news: backend, profiles: backend, store: local, controls: controls)
        try await app.accept(DemoSession(userID: "test", email: "test@example.com"))
        await app.refresh()
        app.start(app.briefing!)
        let active = app.playback.briefing
        controls.emptyBriefing = true
        await app.refresh()
        XCTAssertEqual(app.briefing?.stories.count, 0)
        XCTAssertEqual(app.playback.briefing, active)
        await app.signOut()
        XCTAssertNil(app.session); XCTAssertNil(app.playback.story)
        let session: DemoSession? = local.load("session")
        XCTAssertNil(session)
    }

    func testDeniedMicrophoneAndFailedQuestionCanRecover() async throws {
        let briefing = try await backend.dailyBriefing(interests: [])
        let audio = PlaybackController(store: local); audio.start(briefing); audio.seek(5); audio.pause()
        let conversation = ConversationModel(news: backend, playback: audio, controls: controls)
        controls.denyMicrophone = true; conversation.recordDemo()
        XCTAssertEqual(conversation.phase, .composing); XCTAssertNotNil(conversation.error)
        controls.failNextRequest = true; conversation.draft = "Why?"; conversation.submit()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(conversation.phase, .failed)
        XCTAssertEqual(conversation.draft, "Why?")
        conversation.submit(); try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(conversation.phase, .answered)
        conversation.cancel(); XCTAssertEqual(audio.position, 5, accuracy: 0.4)
    }
    func testPlaybackRestoreIsPausedAndSeekClamped() async throws {
        let briefing = try await backend.dailyBriefing(interests: [])
        let audio = PlaybackController(store: local); audio.start(briefing, at: 2); audio.seek(6); audio.pause()
        let restored = PlaybackController(store: local)
        XCTAssertEqual(restored.story?.id, briefing.stories[2].id)
        XCTAssertEqual(restored.position, 6, accuracy: 0.4); XCTAssertFalse(restored.isPlaying)
        restored.seek(-100); XCTAssertEqual(restored.position, 0)
        restored.seek(100000); XCTAssertEqual(restored.position, restored.duration)
    }

    func testFollowUpCutsAnswerAndAutomaticallyResumesOriginalPosition() async throws {
        let audio = PlaybackController(store: local)
        audio.start(try await backend.dailyBriefing(interests: [])); audio.seek(7); audio.pause()
        let conversation = ConversationModel(news: backend, playback: audio, controls: controls)
        conversation.begin(); conversation.draft = "Why?"; conversation.submit()
        try await Task.sleep(for: .milliseconds(80))
        audio.seek(3)
        conversation.recordDemo()
        XCTAssertFalse(audio.isPlaying)
        XCTAssertEqual(audio.deepDives.count, 1)
        XCTAssertTrue(audio.deepDives[0].interrupted)
        conversation.sendDemoRecording()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(audio.deepDives.count, 2)
        XCTAssertEqual(audio.deepDives[1].storyPosition, 7, accuracy: 0.4)
        audio.finishCurrentSegment()
        XCTAssertTrue(audio.isTransitioning)
        let endOfDive = audio.sessionPosition
        try await Task.sleep(for: .milliseconds(1500))
        XCTAssertEqual(audio.sessionPosition, endOfDive, accuracy: 0.4)
        XCTAssertFalse(audio.isAnswer)
        XCTAssertTrue(audio.isPlaying)
        XCTAssertEqual(audio.position, 7, accuracy: 0.4)
        XCTAssertFalse(audio.deepDives[1].interrupted)
        audio.pause()
    }
    func testAskCreatesIndependentPlayableSession() async throws {
        let first = try await backend.podcast(question: "Ocean science")
        let second = try await backend.podcast(question: "Ocean science")
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.stories.first?.title, "Ocean science")
        let audio = PlaybackController(store: local); audio.start(first)
        XCTAssertTrue(audio.isPlaying); XCTAssertEqual(audio.briefing?.id, first.id)
        audio.pause()
    }

    func testTimelineInsertionAndScrubbingAcrossStoryAndDive() async throws {
        let audio = PlaybackController(store: local)
        let briefing = try await backend.dailyBriefing(interests: [])
        audio.start(briefing); audio.seek(6); audio.beginQuestion()
        let answer = try await backend.research(QuestionRequest(requestID: UUID(), question: "Why?", storyID: audio.story?.id, previousTurns: []))
        audio.playAnswer(answer); audio.pause()
        let extra = audio.duration
        XCTAssertEqual(audio.sessionDuration, briefing.duration + extra, accuracy: 0.1)
        XCTAssertEqual(audio.segments[0].end, 6, accuracy: 0.1)
        XCTAssertEqual(audio.segments[1].answer?.id, answer.id)
        XCTAssertEqual(audio.segments[2].start, 6, accuracy: 0.1)
        audio.seekSession(8)
        XCTAssertTrue(audio.isAnswer); XCTAssertEqual(audio.position, 2, accuracy: 0.1)
        audio.seekSession(6 + extra + 2)
        XCTAssertFalse(audio.isAnswer); XCTAssertEqual(audio.position, 8, accuracy: 0.1)
        XCTAssertEqual(audio.sessionPosition, 8 + extra, accuracy: 0.1)
        audio.seekSession(2)
        XCTAssertFalse(audio.isAnswer); XCTAssertEqual(audio.position, 2, accuracy: 0.1)
        audio.finishCurrentSegment()
        XCTAssertTrue(audio.isAnswer)
        audio.pause()
    }
    func testCancelTransitionPreventsUnexpectedResume() async throws {
        let audio = PlaybackController(store: local)
        audio.start(try await backend.dailyBriefing(interests: [])); audio.seek(4); audio.beginQuestion()
        let answer = try await backend.research(QuestionRequest(requestID: UUID(), question: "Why?", storyID: audio.story?.id, previousTurns: []))
        audio.playAnswer(answer); audio.finishCurrentSegment()
        XCTAssertTrue(audio.isTransitioning)
        audio.pause()
        try await Task.sleep(for: .milliseconds(1500))
        XCTAssertFalse(audio.isPlaying); XCTAssertTrue(audio.isAnswer)
        audio.seekSession(1)
        XCTAssertFalse(audio.isTransitioning); XCTAssertEqual(audio.position, 1, accuracy: 0.1)
    }

}
