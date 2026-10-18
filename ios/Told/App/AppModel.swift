import Foundation
import Observation

@MainActor @Observable final class AppModel {
    let auth: any AuthRepository
    let news: any NewsRepository
    let profiles: any ProfileRepository
    let store: LocalStore
    let controls: DemoControls
    let playback: PlaybackController
    let conversation: ConversationModel
    var session: DemoSession?
    var profile: UserProfile?
    var briefing: Briefing?
    var loadingBriefing = false
    var feedError: String?
    var showPlayer = false
    var selectedTab = 0
    private var refreshID = UUID()
    init(auth: any AuthRepository, news: any NewsRepository, profiles: any ProfileRepository, store: LocalStore, controls: DemoControls) {
        self.auth = auth; self.news = news; self.profiles = profiles; self.store = store; self.controls = controls
        session = store.load("session"); profile = store.load("profile"); briefing = store.load("briefing")
        playback = PlaybackController(store: store)
        conversation = ConversationModel(news: news, playback: playback, controls: controls)
        if session == nil { profile = nil; briefing = nil; playback.clear() }
    }
    static func demo() -> AppModel {
        let store = LocalStore()
        store.refreshContentVersion()
        if ProcessInfo.processInfo.arguments.contains("--reset-demo") { store.clear() }
        let controls = DemoControls()
        let backend = MockBackend(controls: controls, store: store, latency: ProcessInfo.processInfo.arguments.contains("--ui-testing") ? .milliseconds(60) : .milliseconds(650))
        return AppModel(auth: backend, news: backend, profiles: backend, store: store, controls: controls)
    }
    func accept(_ session: DemoSession) async throws {
        // Publish session only once the dependent profile lookup succeeds.
        let profile = try await profiles.load(userID: session.userID) ?? UserProfile(userID: session.userID, email: session.email)
        self.profile = profile; self.session = session
        store.save(session, key: "session"); store.save(profile, key: "profile")
    }
    func saveProfile(_ profile: UserProfile) async throws {
        try await profiles.save(profile)
        self.profile = profile; playback.speed = profile.playbackSpeed
    }
    func refresh() async {
        guard let profile else { return }
        let id = UUID(); refreshID = id; loadingBriefing = true; feedError = nil
        do {
            let result = try await news.dailyBriefing(interests: profile.interests)
            guard refreshID == id, session != nil else { return }
            briefing = result; store.save(result, key: "briefing")
        } catch is CancellationError { } catch { if refreshID == id { feedError = error.localizedDescription } }
        if refreshID == id { loadingBriefing = false }
    }
    func start(_ briefing: Briefing, at index: Int = 0) { conversation.cancel(); playback.start(briefing, at: index); showPlayer = true }
    func signOut() async {
        conversation.cancel()
        refreshID = UUID(); playback.clear(); showPlayer = false; selectedTab = 0
        session = nil; profile = nil; briefing = nil; store.clear(); feedError = nil
        controls.offline = false; controls.failNextRequest = false; controls.denyMicrophone = false; controls.expireCode = false; controls.emptyBriefing = false
        await auth.signOut()
    }
}

@MainActor @Observable final class ConversationModel {
    enum Phase: Equatable { case idle, composing, recording, researching, answered, failed }
    var phase: Phase = .idle
    var draft = ""
    var error: String?
    var answers: [ResearchAnswer] = []
    var elapsed = 0
    private var task: Task<Void, Never>?
    private var requestID = UUID()
    private let news: any NewsRepository
    private let playback: PlaybackController
    private let controls: DemoControls
    init(news: any NewsRepository, playback: PlaybackController, controls: DemoControls) { self.news = news; self.playback = playback; self.controls = controls }
    func begin() {
        task?.cancel(); requestID = UUID(); playback.beginQuestion(); phase = .composing; error = nil
    }
    func recordDemo() {
        begin()
        guard !controls.denyMicrophone else { error = "Microphone access is denied. Type your question below."; return }
        phase = .recording; elapsed = 0
        task = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                self?.elapsed += 1
            }
        }
    }
    func sendDemoRecording() { draft = "Why does this matter?"; submit() }
    func submit() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, phase != .researching else { return }
        task?.cancel(); let id = UUID(); requestID = id; phase = .researching; error = nil
        let request = QuestionRequest(requestID: id, question: question, storyID: playback.story?.id, previousTurns: answers)
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let answer = try await news.research(request)
                guard !Task.isCancelled, requestID == id else { return }
                answers.append(answer); phase = .answered; draft = ""; playback.playAnswer(answer)
            } catch is CancellationError { } catch { guard requestID == id else { return }; phase = .failed; self.error = error.localizedDescription }
        }
    }
    func cancel(resume: Bool = false) {
        task?.cancel(); task = nil; requestID = UUID(); playback.pause(); playback.restoreStory(resume: resume)
        phase = .idle; draft = ""; error = nil; answers = []
    }
}
