import Foundation
import AVFoundation
import Observation

@MainActor @Observable final class PlaybackController: NSObject, AVAudioPlayerDelegate {
    private(set) var briefing: Briefing?
    private(set) var index = 0
    private(set) var position: Double = 0
    private(set) var duration: Double = 1
    private(set) var isPlaying = false
    private(set) var isAnswer = false
    private(set) var deepDives: [DeepDive] = []
    private(set) var activeAnswer: ResearchAnswer?
    private(set) var isTransitioning = false
    private var transitionTask: Task<Void, Never>?
    private var transitionID = UUID()
    private var selectedSegmentID: String?
    var error: String?
    var speed: Float = 1 { didSet { player?.rate = speed; persist() } }
    private var player: AVAudioPlayer?
    private var ticker: Timer?
    private let store: LocalStore
    private var checkpointPosition: Double?
    var story: Story? { guard let briefing, briefing.stories.indices.contains(index) else { return nil }; return briefing.stories[index] }
    var segments: [ListeningSegment] {
        guard let briefing else { return [] }
        var result: [ListeningSegment] = []
        for (i, story) in briefing.stories.enumerated() {
            var cursor = 0.0
            let dives = deepDives.enumerated().filter { $0.element.storyID == story.id }.sorted {
                $0.element.storyPosition == $1.element.storyPosition ? $0.offset < $1.offset : $0.element.storyPosition < $1.element.storyPosition
            }
            for (_, dive) in dives {
                let insertion = min(story.duration, max(cursor, dive.storyPosition))
                if insertion > cursor { result.append(ListeningSegment(id: "\(story.id)-\(cursor)", storyIndex: i, start: cursor, end: insertion, answer: nil)) }
                let length = dive.interrupted ? dive.heard : dive.audioDuration
                if length > 0 { result.append(ListeningSegment(id: dive.id, storyIndex: i, start: 0, end: length, answer: dive.answer)) }
                cursor = insertion
            }
            if cursor < story.duration { result.append(ListeningSegment(id: "\(story.id)-\(cursor)", storyIndex: i, start: cursor, end: story.duration, answer: nil)) }
        }
        return result
    }
    var currentSegmentID: String? {
        if let activeAnswer { return activeAnswer.id }
        if let selectedSegmentID, segments.contains(where: { $0.id == selectedSegmentID }) { return selectedSegmentID }
        return segments.last { $0.storyIndex == index && $0.answer == nil && position >= $0.start - 0.01 }?.id
    }
    var sessionDuration: Double { segments.reduce(0) { $0 + $1.duration } }
    var sessionPosition: Double {
        var elapsed = 0.0
        for segment in segments {
            if segment.id == currentSegmentID { return elapsed + min(segment.duration, max(0, position - segment.start)) }
            elapsed += segment.duration
        }
        return elapsed
    }
    func seekSession(_ value: Double) {
        let wasPlaying = isPlaying || isTransitioning
        cancelTransition()
        var remaining = min(max(0, value), sessionDuration)
        for (i, segment) in segments.enumerated() {
            if remaining < segment.duration || i == segments.count - 1 {
                activate(segment, offset: remaining, resume: wasPlaying)
                return
            }
            remaining -= segment.duration
        }
    }
    private func activate(_ segment: ListeningSegment, offset: Double = 0, resume: Bool) {
        guard let briefing else { return }
        cancelTransition()
        index = segment.storyIndex; selectedSegmentID = segment.id
        activeAnswer = segment.answer; isAnswer = segment.answer != nil
        checkpointPosition = segment.answer.flatMap { answer in deepDives.first { $0.id == answer.id }?.storyPosition }
        loadAudio(segment.answer?.audioResource ?? briefing.stories[index].audioResource)
        seek(segment.start + min(offset, segment.duration))
        if resume && offset < segment.duration - 0.01 { play() }
    }
    private func cancelTransition() {
        transitionTask?.cancel(); transitionTask = nil; transitionID = UUID(); isTransitioning = false
    }
    init(store: LocalStore) {
        self.store = store
        super.init()
        if let saved: PlaybackCheckpoint = store.load("playback"), saved.briefing.stories.indices.contains(saved.index) {
            briefing = saved.briefing; index = saved.index; speed = saved.speed
            loadAudio(saved.briefing.stories[index].audioResource)
            seek(saved.position)
        }
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            Task { @MainActor in
                guard let player = self.player else { return }
                self.position = player.currentTime
                self.isPlaying = player.isPlaying
                if !self.isAnswer { self.persist() }
                if self.isPlaying, let segment = self.segments.first(where: { $0.id == self.currentSegmentID }), self.position >= segment.end - 0.04 {
                    self.finishCurrentSegment()
                }
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    @objc private func interrupted() { pause() }
    @objc private func routeChanged(_ note: Notification) {
        if note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { pause() }
    }
    private func loadAudio(_ resource: String) {
        player?.stop(); isPlaying = false; error = nil
        guard let url = Bundle.main.url(forResource: resource, withExtension: "aiff") else { error = "This audio isn’t downloaded. Try another story."; player = nil; return }
        do {
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.enableRate = true; audio.rate = speed; audio.delegate = self; audio.prepareToPlay()
            player = audio; duration = audio.duration; position = 0
        } catch { self.error = "Audio couldn’t open. Try playing the story again." }
    }
    func start(_ briefing: Briefing, at index: Int = 0) {
        guard briefing.stories.indices.contains(index) else { return }
        if self.briefing?.id == briefing.id, self.story?.id == briefing.stories[index].id, !isAnswer { play(); return }
        cancelTransition(); selectedSegmentID = nil
        deepDives = []; activeAnswer = nil
        self.briefing = briefing; self.index = index; checkpointPosition = nil; isAnswer = false
        loadAudio(briefing.stories[index].audioResource); play(); persist()
    }
    func play() {
        guard let player else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            if player.currentTime >= player.duration - 0.1 {
                if isAnswer { finishCurrentSegment(); return }
                player.currentTime = 0
            }
            player.play(); isPlaying = player.isPlaying
        } catch { self.error = "Audio is unavailable. Try again." }
    }
    func pause() { cancelTransition(); player?.pause(); isPlaying = false; persist() }
    func toggle() { (isPlaying || isTransitioning) ? pause() : play() }
    func seek(_ value: Double) { let clamped = min(max(0, value), duration); player?.currentTime = clamped; position = clamped; persist() }
    func skip(_ delta: Int) {
        guard let briefing else { return }
        let target = index + delta
        guard briefing.stories.indices.contains(target) else { return }
        cancelTransition(); selectedSegmentID = nil
        finishDive(interrupted: true)
        checkpointPosition = nil; isAnswer = false; activeAnswer = nil; index = target
        loadAudio(briefing.stories[index].audioResource); play(); persist()
    }
    func beginQuestion() {
        cancelTransition(); selectedSegmentID = nil
        if checkpointPosition == nil { checkpointPosition = position }
        pause()
        finishDive(interrupted: true)
    }
    func playAnswer(_ answer: ResearchAnswer) {
        deepDives.append(DeepDive(id: answer.id, storyID: story?.id ?? "", storyPosition: checkpointPosition ?? position, answer: answer, parentDiveID: activeAnswer?.id, parentPosition: isAnswer ? position : nil))
        cancelTransition(); selectedSegmentID = nil
        activeAnswer = answer; isAnswer = true; loadAudio(answer.audioResource)
        deepDives[deepDives.count - 1].audioDuration = duration
        play()
    }
    func restoreStory(resume: Bool) {
        guard let story, let checkpointPosition else { return }
        cancelTransition(); selectedSegmentID = nil
        finishDive(interrupted: true)
        activeAnswer = nil; isAnswer = false; loadAudio(story.audioResource); seek(checkpointPosition)
        self.checkpointPosition = nil
        if resume {
            if checkpointPosition >= duration - 0.1 { finishCurrentSegment() }
            else { play() }
        }
    }
    private func finishDive(interrupted: Bool) {
        guard isAnswer, let id = activeAnswer?.id, let i = deepDives.firstIndex(where: { $0.id == id }) else { return }
        deepDives[i].heard = position
        deepDives[i].interrupted = interrupted && position < deepDives[i].audioDuration - 0.1
    }
    func finishCurrentSegment() {
        guard !isTransitioning else { return }
        let timeline = segments
        guard let current = timeline.firstIndex(where: { $0.id == currentSegmentID }) else { return }
        player?.pause(); isPlaying = false
        position = timeline[current].end
        player?.currentTime = position
        if isAnswer { finishDive(interrupted: deepDives.first { $0.id == activeAnswer?.id }?.interrupted ?? false) }
        guard timeline.indices.contains(current + 1) else { persist(); return }
        let next = timeline[current + 1]
        if isAnswer && next.answer == nil {
            isTransitioning = true
            let token = UUID(); transitionID = token
            transitionTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(1400)) } catch { return }
                guard let self, self.transitionID == token else { return }
                self.activate(next, resume: true)
            }
        } else { activate(next, resume: true) }
    }
    func clear() { cancelTransition(); selectedSegmentID = nil; deepDives = []; activeAnswer = nil; player?.stop(); player = nil; briefing = nil; index = 0; position = 0; isPlaying = false; isAnswer = false; checkpointPosition = nil }
    private func persist() {
        guard let briefing else { return }
        store.save(PlaybackCheckpoint(briefing: briefing, index: index, position: checkpointPosition ?? position, speed: speed), key: "playback")
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard player === self.player else { return }
            self.isPlaying = false
            if flag { self.finishCurrentSegment() } else { self.error = "Playback stopped. Try again." }
        }
    }
}
