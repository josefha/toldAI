import Foundation
import Observation

@MainActor protocol AuthRepository {
    func sendCode(email: String) async throws -> AuthChallenge
    func verifyCode(email: String, code: String) async throws -> DemoSession
    func signOut() async
}
@MainActor protocol NewsRepository {
    func dailyBriefing(interests: [Interest]) async throws -> Briefing
    func podcast(question: String) async throws -> Briefing
    func research(_ request: QuestionRequest) async throws -> ResearchAnswer
}
@MainActor protocol ProfileRepository {
    func save(_ profile: UserProfile) async throws
    func load(userID: String) async throws -> UserProfile?
}
@MainActor @Observable final class DemoControls {
    var offline = false
    var failNextRequest = false
    var denyMicrophone = false
    var expireCode = false
    var emptyBriefing = false
}
@MainActor final class MockBackend: AuthRepository, NewsRepository, ProfileRepository {
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
    func verifyCode(email: String, code: String) async throws -> DemoSession {
        try await request()
        guard let challenge, challenge.email == email.lowercased(), challenge.expiresAt > Date(), !controls.expireCode else { throw ServiceFailure.expiredCode }
        guard code == "123456" else { throw ServiceFailure.invalidCode }
        self.challenge = nil
        return DemoSession(userID: email.lowercased(), email: email.lowercased())
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
        return Briefing(id: "demo-\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)", title: "Your daily five", generatedAt: Date(), artworkID: "daily", stories: controls.emptyBriefing ? [] : ordered, isDemo: true)
    }
    func podcast(question: String) async throws -> Briefing {
        try await request()
        let topic = Fixtures.stories.first { question.localizedCaseInsensitiveContains($0.category.title) } ?? Fixtures.stories[0]
        let opening = Story(id: UUID().uuidString, title: question, category: topic.category, summary: topic.summary, transcript: topic.transcript, sources: topic.sources, artworkID: topic.artworkID, audioResource: topic.audioResource, duration: topic.duration)
        podcastStories[opening.id] = opening
        return Briefing(id: UUID().uuidString, title: question, generatedAt: .now, artworkID: topic.artworkID, stories: [opening], isDemo: true)
    }
    func research(_ request: QuestionRequest) async throws -> ResearchAnswer {
        try await self.request()
        let story = request.storyID.flatMap { podcastStories[$0] } ?? Fixtures.stories.first { $0.id == request.storyID } ?? Fixtures.stories.first { request.question.localizedCaseInsensitiveContains($0.category.title) }
        let text = story.map { "Here’s the context behind “\($0.title)”. \($0.summary) The important distinction is between what has been demonstrated and what might become possible." } ?? "Let’s narrow this down. Try a question about technology, energy, the ocean, cities, or repair to explore one of today’s stories."
        return ResearchAnswer(id: request.requestID.uuidString, question: request.question, text: text, sources: story?.sources ?? [Fixtures.source], audioResource: "answer", isDemo: true)
    }
}
@MainActor final class LocalStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: "told.demo.\(key)") else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "told.demo.\(key)") }
    }
    func refreshContentVersion() {
        guard defaults.integer(forKey: "told.contentVersion") < 2 else { return }
        for key in ["briefing", "playback"] { defaults.removeObject(forKey: "told.demo.\(key)") }
        defaults.set(2, forKey: "told.contentVersion")
    }
    func clear() { for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("told.demo.") { defaults.removeObject(forKey: key) } }
}
