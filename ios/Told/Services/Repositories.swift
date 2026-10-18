import Foundation

@MainActor protocol AuthRepository {
    func sendCode(email: String) async throws -> AuthChallenge
    func verifyCode(email: String, code: String) async throws -> UserSession
    var currentSession: UserSession? { get }
    func signOut() async
    #if DEBUG
    func signIn(email: String, password: String) async throws -> UserSession
    #endif
}
#if DEBUG
extension AuthRepository {
    func signIn(email: String, password: String) async throws -> UserSession {
        throw APIError(message: "Password sign-in is unavailable for this connection.")
    }
}
#endif
@MainActor protocol NewsRepository {
    func dailyBriefing(interests: [Interest]) async throws -> Briefing
    func podcast(question: String) async throws -> Briefing
    func research(_ request: QuestionRequest) async throws -> ResearchAnswer
    func research(_ request: QuestionRequest, onReady: @escaping @MainActor (ResearchAnswer) -> Void) async throws -> ResearchAnswer
    func transcribe(_ recording: URL) async throws -> String
    func deleteAccount() async throws
}
extension NewsRepository {
    func research(_ request: QuestionRequest, onReady: @escaping @MainActor (ResearchAnswer) -> Void) async throws -> ResearchAnswer { try await research(request) }
}
@MainActor protocol ProfileRepository {
    func save(_ profile: UserProfile) async throws
    func load(userID: String) async throws -> UserProfile?
}
@MainActor final class LocalStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: "told.live.\(key)") else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "told.live.\(key)") }
    }
    func refreshContentVersion() {
        guard defaults.integer(forKey: "told.liveContentVersion") < 2 else { return }
        for key in ["briefing", "playback"] { defaults.removeObject(forKey: "told.live.\(key)") }
        defaults.set(2, forKey: "told.liveContentVersion")
    }
    func clear() { for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("told.live.") { defaults.removeObject(forKey: key) } }
}
