import Foundation
import Observation

@MainActor @Observable final class AppModel {
    let auth: any AuthRepository
    let news: any NewsRepository
    let profiles: any ProfileRepository
    let store: LocalStore
    let playback: PlaybackController
    let conversation: ConversationModel
    var session: UserSession?
    var profile: UserProfile?
    var briefing: Briefing?
    var loadingBriefing = false
    var feedError: String?
    var showPlayer = false
    var selectedTab = 0
    var restoringSession = false
    var sessionError: String?
    private var refreshID = UUID()
    init(auth: any AuthRepository, news: any NewsRepository, profiles: any ProfileRepository, store: LocalStore) {
        self.auth = auth; self.news = news; self.profiles = profiles; self.store = store
        session = auth.currentSession; profile = store.load("profile"); briefing = store.load("briefing")
        playback = PlaybackController(store: store)
        conversation = ConversationModel(news: news, playback: playback)
        if profile?.userID != session?.userID { profile = nil; briefing = nil }
        if session == nil { profile = nil; briefing = nil; playback.clear() }
    }
    static func live() -> AppModel {
        let store = LocalStore()
        store.refreshContentVersion()
        let backend = LiveBackend()
        return AppModel(auth: backend, news: backend, profiles: backend, store: store)
    }
    func restoreSession() async {
        guard let session, !restoringSession else { return }
        restoringSession = true; sessionError = nil
        defer { restoringSession = false }
        do { try await accept(session) } catch { sessionError = error.localizedDescription }
    }
    func accept(_ session: UserSession) async throws {
        // Publish session only once the dependent profile lookup succeeds.
        let profile = try await profiles.load(userID: session.userID) ?? UserProfile(userID: session.userID, email: session.email)
        self.profile = profile; self.session = session
        store.save(profile, key: "profile")
    }
    func saveProfile(_ profile: UserProfile) async throws {
        try await profiles.save(profile)
        self.profile = profile; store.save(profile, key: "profile"); playback.speed = profile.playbackSpeed
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
        AudioCache.clear()
        await auth.signOut()
    }
}

@MainActor @Observable final class ConversationModel {
    enum Phase: Equatable { case idle, composing, recording, transcribing, researching, answered, failed }
    var phase: Phase = .idle
    var draft = ""
    var error: String?
    var answers: [ResearchAnswer] = []
    var elapsed = 0
    private var task: Task<Void, Never>?
    private var requestID = UUID()
    private var contextStoryID: String?
    private let news: any NewsRepository
    private let playback: PlaybackController
    private let recorder: any VoiceRecorder
    init(news: any NewsRepository, playback: PlaybackController, recorder: (any VoiceRecorder)? = nil) { self.news = news; self.playback = playback; self.recorder = recorder ?? MicrophoneRecorder() }
    func begin() {
        if contextStoryID != playback.story?.id { answers = playback.deepDives.filter { $0.storyID == playback.story?.id }.map(\.answer); contextStoryID = playback.story?.id }
        task?.cancel(); recorder.cancel(); requestID = UUID(); playback.beginQuestion(); phase = .composing; error = nil
    }
    func startRecording() {
        begin()
        let id = requestID
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await recorder.start()
                guard requestID == id, !Task.isCancelled else { recorder.cancel(); return }
                phase = .recording; elapsed = 0
                while !Task.isCancelled && elapsed < 60 { try await Task.sleep(for: .seconds(1)); elapsed += 1 }
                if !Task.isCancelled { sendRecording() }
            } catch is CancellationError { if requestID == id { recorder.cancel() } } catch { guard requestID == id else { return }; phase = .composing; self.error = error.localizedDescription }
        }
    }
    func sendRecording() {
        task?.cancel(); let id = UUID(); requestID = id; phase = .transcribing; error = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let url = try recorder.stop()
                defer { try? FileManager.default.removeItem(at: url) }
                let text = try await news.transcribe(url)
                guard requestID == id, !Task.isCancelled else { return }
                draft = text; phase = .composing; submit()
            } catch { guard requestID == id, !Task.isCancelled else { return }; phase = .composing; self.error = error.localizedDescription }
        }
    }
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
        task?.cancel(); recorder.cancel(); task = nil; requestID = UUID(); playback.pause(); playback.restoreStory(resume: resume)
        phase = .idle; draft = ""; error = nil; answers = []
    }
}
