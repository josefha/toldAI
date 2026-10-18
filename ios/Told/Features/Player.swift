import SwiftUI
import AVFoundation

struct PlayerView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var chapters = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        @Bindable var playback = model.playback
        @Bindable var conversation = model.conversation
        NavigationStack {
            ScrollView {
                if let story = playback.story {
                    VStack(spacing: 20) {
                        Artwork(name: story.artworkID).frame(height: typeSize.isAccessibilitySize ? 120 : 190).clipped().clipShape(RoundedRectangle(cornerRadius: 28))
                        Text(playback.activeAnswer?.question ?? story.title).font(.title2.weight(.medium)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).frame(minHeight: typeSize.isAccessibilitySize ? 0 : 60)
                        SessionTimeline(playback: playback)
                            .disabled(conversation.phase != .idle && conversation.phase != .answered)
                        Button { chapters.toggle() } label: { Label(playback.isAnswer ? "Deep dive · In your session" : "Story \(playback.index + 1) · Your session", systemImage: "point.topleft.down.to.point.bottomright.curvepath").font(.subheadline).frame(minHeight: 44) }.accessibilityIdentifier("sessionChapters")
                        if chapters { chapterList }
                        contextPanel
                        HStack {
                            Button { playback.skip(-1) } label: { Image(systemName: "backward.end.fill").frame(width: 44, height: 44) }.disabled(playback.index == 0).accessibilityLabel("Previous story")
                            Button { playback.toggle() } label: { Image(systemName: playback.isPlaying || playback.isTransitioning ? "pause.fill" : "play.fill").font(.title2).frame(width: 56, height: 56) }.accessibilityLabel(playback.isPlaying || playback.isTransitioning ? "Pause" : "Play").accessibilityIdentifier("playerTransport")
                            Button { playback.skip(1) } label: { Image(systemName: "forward.end.fill").frame(width: 44, height: 44) }.disabled(playback.index + 1 >= (playback.briefing?.stories.count ?? 0)).accessibilityLabel("Next story")
                        }.disabled(conversation.phase == .recording || conversation.phase == .researching || conversation.phase == .transcribing || conversation.phase == .composing || conversation.phase == .failed)
                        if conversation.phase != .recording {
                            AskControls(voice: { conversation.startRecording() }, text: { conversation.begin() })
                        }
                        if playback.isAnswer {
                            Button("Back to Story") { conversation.cancel(resume: true) }.frame(minHeight: 44).accessibilityIdentifier("continueListening")
                        }
                        HStack(spacing: 24) {
                            NavigationLink("Sources") { SourceList(sources: playback.activeAnswer?.sources ?? story.sources) }.accessibilityIdentifier("playerSources")
                            NavigationLink("Transcript") {
                                if let answer = playback.activeAnswer { ScrollView { Text(answer.text).lineSpacing(7).padding(24).textSelection(.enabled) }.navigationTitle("Deep Dive") }
                                else { TranscriptView(story: story) }
                            }
                            Menu { Picker("Playback speed", selection: $playback.speed) { ForEach([Float(0.75), 1, 1.25, 1.5, 2], id: \.self) { Text("\($0.formatted())×").tag($0) } } } label: { Text("\(playback.speed.formatted())×") }
                        }.font(.subheadline).frame(minHeight: 44)
                        if let error = playback.error { ErrorNotice(message: error) }
                    }.padding(24)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: playback.currentSegmentID)
                }
            }.background(Theme.canvas).scrollDismissesKeyboard(.interactively)
                .navigationTitle("Listening").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.accessibilityLabel("Collapse player").accessibilityIdentifier("collapsePlayer") } }
        }.tint(Theme.ink)
        .onChange(of: playback.isAnswer) { _, answer in if conversation.phase == .idle || conversation.phase == .answered { conversation.phase = answer ? .answered : .idle } }
        .onAppear { if conversation.phase == .idle || conversation.phase == .answered { conversation.phase = playback.isAnswer ? .answered : .idle } }
        .onDisappear { cancelInput() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { cancelInput() } }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in cancelInput() }
    }
    private func cancelInput() {
        if model.conversation.phase != .idle && model.conversation.phase != .answered { model.conversation.cancel() }
    }
    @ViewBuilder private var contextPanel: some View {
        @Bindable var conversation = model.conversation
        VStack(alignment: .leading, spacing: 14) {
            if let error = conversation.error { ErrorNotice(message: error) }
            switch conversation.phase {
            case .recording:
                ListeningIndicator()
                Button("Finish & Ask") { conversation.sendRecording() }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("sendVoiceQuestion")
                Button("Cancel") { conversation.cancel(resume: true) }.frame(minHeight: 44)
            case .composing, .failed:
                TextField("What are you curious about?", text: $conversation.draft, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder).accessibilityIdentifier("questionField")
                Button("Send Question") { conversation.submit() }.buttonStyle(PrimaryButtonStyle()).disabled(conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("sendQuestion")
                Button("Cancel") { conversation.cancel(resume: true) }.frame(minHeight: 44)
            case .researching, .transcribing:
                HStack { ProgressView(); Text(conversation.phase == .transcribing ? "Transcribing your question…" : "Following your question…") }.frame(minHeight: 60)
                Button("Cancel") { conversation.cancel(resume: true) }.frame(minHeight: 44)
            case .answered:
                if let answer = model.playback.activeAnswer {
                    Text(answer.text).font(.subheadline).foregroundStyle(Theme.secondary).lineLimit(3).accessibilityIdentifier("answerText")
                    Text(model.playback.isTransitioning ? "Up next · Continuing your story…" : "Then, continuing your story").font(.caption).foregroundStyle(Theme.secondary)
                }
            case .idle:
                Text(model.playback.story?.summary ?? "").font(.subheadline).foregroundStyle(Theme.secondary).lineLimit(3)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var chapterList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(model.playback.briefing?.stories ?? []) { story in
                Text(story.title).font(.subheadline.weight(.medium))
                ForEach(model.playback.deepDives.filter { $0.storyID == story.id }) { dive in
                    Label { VStack(alignment: .leading) { Text(dive.answer.question); Text("\(dive.parentDiveID == nil ? "At" : "Follow-up at") \((dive.parentPosition ?? dive.storyPosition).playbackTime) · \(dive.interrupted ? "Interrupted" : "Deep dive")").font(.caption).foregroundStyle(Theme.secondary) } } icon: { Image(systemName: "arrow.turn.down.right") }.padding(.leading, 12)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}
struct AskControls: View {
    var prefix = ""
    let voice: () -> Void
    let text: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: voice) { Label("Ask", systemImage: "mic.fill") }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier(prefix + "askButton")
            Button(action: text) { Image(systemName: "text.bubble").font(.title3).frame(width: 56, height: 56).background(Theme.surface, in: Circle()) }.accessibilityLabel("Type a question").accessibilityIdentifier(prefix + "typeQuestion")
        }
    }
}
struct ListeningIndicator: View {
    var body: some View { HStack(spacing: 14) { Image(systemName: "waveform").font(.largeTitle); Text("Listening…").font(.title2) }.frame(maxWidth: .infinity, minHeight: 60).accessibilityIdentifier("listeningState") }
}
struct SummaryView: View {
    let story: Story
    var body: some View { ScrollView { Text(story.summary).padding(24) }.navigationTitle("Summary") }
}

struct SessionTimeline: View {
    let playback: PlaybackController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    @State private var scrubPosition: Double?
    private var total: Double { max(1, playback.sessionDuration) }
    private var position: Double { scrubPosition ?? playback.sessionPosition }
    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let width = max(1, geometry.size.width - 16)
                ZStack(alignment: .leading) {
                    ForEach(Array(playback.segments.enumerated()), id: \.element.id) { index, segment in
                        let start = playback.segments.prefix(index).reduce(0) { $0 + $1.duration }
                        let x = 8 + width * start / total
                        Capsule().fill(segment.answer == nil ? Theme.ink.opacity(0.45) : Color.purple)
                            .frame(width: max(1, width * segment.duration / total), height: 5).offset(x: x)
                        if segment.answer != nil {
                            Circle().fill(Theme.canvas).overlay(Circle().stroke(Color.purple, lineWidth: 2)).frame(width: 9, height: 9).offset(x: x - 4.5)
                            Circle().fill(Theme.canvas).overlay(Circle().stroke(Color.purple, lineWidth: 2)).frame(width: 9, height: 9).offset(x: x + width * segment.duration / total - 4.5)
                        }
                    }
                    Circle().fill(Theme.ink).frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Theme.canvas, lineWidth: 2))
                        .offset(x: width * min(1, max(0, position / total)))
                }.frame(height: 44).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in guard enabled else { return }; scrubPosition = min(total, max(0, (value.location.x - 8) / width * total)) }
                        .onEnded { _ in guard enabled else { scrubPosition = nil; return }; if let scrubPosition { playback.seekSession(scrubPosition) }; scrubPosition = nil })
            }.frame(height: 44)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Session timeline")
                .accessibilityValue("\(position.playbackTime) of \(total.playbackTime), \(playback.isAnswer ? "deep dive" : "story")")
                .accessibilityAdjustableAction { direction in guard enabled else { return }; playback.seekSession(playback.sessionPosition + (direction == .increment ? 15 : -15)) }
                .accessibilityIdentifier("sessionTimeline")
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: playback.segments.map(\.id))
            HStack { Text(position.playbackTime); Spacer(); Text(total.playbackTime) }.font(.caption.monospacedDigit()).foregroundStyle(Theme.secondary)
            HStack(spacing: 16) {
                Label("Story", systemImage: "minus")
                if !playback.deepDives.isEmpty { Label("Deep dive", systemImage: "circle").foregroundStyle(.purple) }
                Spacer()
            }.font(.caption).foregroundStyle(Theme.secondary).padding(.top, 4)
        }
    }
}
