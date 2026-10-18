import Foundation
import Observation
@testable import Told

@MainActor @Observable final class DemoControls {
    var offline = false
    var failNextRequest = false
    var denyMicrophone = false
    var expireCode = false
    var emptyBriefing = false
}
@MainActor final class MockBackend: AuthRepository, NewsRepository, ProfileRepository {
    var currentSession: UserSession? { nil }
    func transcribe(_ recording: URL) async throws -> String { "Why does this matter?" }
    func deleteAccount() async throws {}
    let controls: DemoControls
    private var challenge: AuthChallenge?
    private var podcastStories: [String: Story] = [:]
    private let latency: Duration
    private let store: LocalStore
    init(controls: DemoControls, store: LocalStore, latency: Duration = .milliseconds(650)) {
        self.controls = controls; self.store = store; self.latency = latency
    }
    private func request() async throws {
        try await Task.sleep(for: latency)
        try Task.checkCancellation()
        if controls.offline { throw ServiceFailure.offline }
        if controls.failNextRequest { controls.failNextRequest = false; throw ServiceFailure.simulated }
    }
    func sendCode(email: String) async throws -> AuthChallenge {
        try await request()
        guard email.contains("@"), let domain = email.split(separator: "@").last, domain.contains("."), !email.contains(" ") else { throw ServiceFailure.invalidEmail }
        let value = AuthChallenge(email: email.lowercased(), expiresAt: Date().addingTimeInterval(600), resendAt: Date().addingTimeInterval(30))
        if let old = challenge, old.email == value.email, old.resendAt > Date() { return old }
        challenge = value
        return value
    }
    func verifyCode(email: String, code: String) async throws -> UserSession {
        try await request()
        guard let challenge, challenge.email == email.lowercased(), challenge.expiresAt > Date(), !controls.expireCode else { throw ServiceFailure.expiredCode }
        guard code == "123456" else { throw ServiceFailure.invalidCode }
        self.challenge = nil
        return UserSession(userID: email.lowercased(), email: email.lowercased())
    }
    func signOut() async { challenge = nil }
    func save(_ profile: UserProfile) async throws { try await request(); store.save(profile, key: "profile") }
    func load(userID: String) async throws -> UserProfile? {
        try await request()
        let profile: UserProfile? = store.load("profile")
        return profile?.userID == userID ? profile : nil
    }
    func dailyBriefing(interests: [Interest]) async throws -> Briefing {
        try await request()
        let ordered = Fixtures.stories.sorted { interests.contains($0.category) && !interests.contains($1.category) }
        return Briefing(id: "demo-\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)", title: "Your daily five", generatedAt: Date(), artworkID: "daily", stories: controls.emptyBriefing ? [] : ordered)
    }
    func podcast(question: String) async throws -> Briefing {
        try await request()
        let topic = Fixtures.stories.first { question.localizedCaseInsensitiveContains($0.category.title) } ?? Fixtures.stories[0]
        let opening = Story(id: UUID().uuidString, title: question, category: topic.category, summary: topic.summary, transcript: topic.transcript, sources: topic.sources, artworkID: topic.artworkID, audioResource: topic.audioResource, duration: topic.duration)
        podcastStories[opening.id] = opening
        return Briefing(id: UUID().uuidString, title: question, generatedAt: .now, artworkID: topic.artworkID, stories: [opening])
    }
    func research(_ request: QuestionRequest) async throws -> ResearchAnswer {
        try await self.request()
        let story = request.storyID.flatMap { podcastStories[$0] } ?? Fixtures.stories.first { $0.id == request.storyID } ?? Fixtures.stories.first { request.question.localizedCaseInsensitiveContains($0.category.title) }
        let text = story.map { "Here’s the context behind “\($0.title)”. \($0.summary) The important distinction is between what has been demonstrated and what might become possible." } ?? "Let’s narrow this down. Try a question about technology, energy, the ocean, cities, or repair to explore one of today’s stories."
        return ResearchAnswer(id: request.requestID.uuidString, question: request.question, text: text, sources: story?.sources ?? [Fixtures.source], audioResource: "answer")
    }
}

@MainActor final class TestRecorder: VoiceRecorder {
    let controls: DemoControls
    init(controls: DemoControls) { self.controls = controls }
    func start() async throws { if controls.denyMicrophone { throw APIError(message: "Microphone denied") } }
    func stop() throws -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    func cancel() {}
}

enum ServiceFailure: LocalizedError {
    case offline, simulated, invalidCode, expiredCode, invalidEmail, noResults
    var errorDescription: String? {
        switch self {
        case .offline: "You’re offline. Downloaded stories still work. Try again when you’re connected."
        case .simulated: "This request couldn’t finish. Please try again."
        case .invalidCode: "That code doesn’t match. Please try again."
        case .expiredCode: "This code has expired. Request a new one."
        case .invalidEmail: "Enter a valid email address."
        case .noResults: "There isn’t enough evidence for an answer. Try a more specific question."
        }
    }
}
