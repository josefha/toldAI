import SwiftUI

struct AskView: View {
    @Environment(AppModel.self) private var model
    @State private var recorder = MicrophoneRecorder()
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = ""
    @State private var typing = false
    @State private var listening = false
    @State private var busy = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @State private var requestID = UUID()
    @FocusState private var focused: Bool
    private let suggestions = ["What happened in Swedish politics in the last 24 hours?", "What’s changing in AI this week?", "Explain the latest developments in clean energy."]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Wordmark(width: 94).padding(.top, 16)
                Text("Where should we begin?").font(.largeTitle.weight(.medium))
                Text("A question. A new direction.").font(.title3).foregroundStyle(Theme.secondary)
                if busy {
                    HStack(spacing: 12) { ProgressView(); Text("Preparing your listening session…") }
                    Button("Cancel") { cancel() }.frame(minHeight: 44)
                } else if listening {
                    ListeningIndicator()
                    Button("Start Listening") { sendRecording() }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("sendVoiceQuestion")
                    Button("Cancel") { recorder.cancel(); listening = false }.frame(minHeight: 44)
                } else {
                    if typing {
                        TextField("What would you like to know?", text: $draft, axis: .vertical).lineLimit(3...6).padding(18).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20)).focused($focused).accessibilityIdentifier("researchField")
                        Button("Start Listening") { submit() }.buttonStyle(PrimaryButtonStyle()).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("submitResearch")
                    }
                    AskControls(prefix: "topic", voice: { startRecording() }, text: { typing = true; focused = true })
                }
                if let error { ErrorNotice(message: error) { submit() } }
                if !busy && !listening {
                    Text("A few starting points").font(.headline).padding(.top, 12)
                    ForEach(suggestions, id: \.self) { question in
                        Button { draft = question; submit() } label: {
                            HStack(alignment: .top, spacing: 16) { Text(question).multilineTextAlignment(.leading); Spacer(minLength: 4); Image(systemName: "arrow.up.right") }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(24)
        }.background(Theme.canvas).scrollDismissesKeyboard(.interactively).navigationTitle("Ask").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false }.accessibilityIdentifier("dismissAskKeyboard") } }
            .onDisappear { cancel(); recorder.cancel(); listening = false }
            .onChange(of: scenePhase) { _, phase in if phase != .active { recorder.cancel(); listening = false } }
    }
    private func startRecording() {
        cancel(); focused = false; model.playback.pause(); error = nil
        let id = UUID(); requestID = id
        task = Task { do { try await recorder.start(); guard requestID == id, !Task.isCancelled else { recorder.cancel(); return }; listening = true } catch { guard requestID == id else { return }; self.error = error.localizedDescription; typing = true } }
    }
    private func sendRecording() {
        let id = UUID(); requestID = id; listening = false; busy = true; error = nil
        task = Task {
            do {
                let file = try recorder.stop(); defer { try? FileManager.default.removeItem(at: file) }
                let question = try await model.news.transcribe(file)
                guard requestID == id, !Task.isCancelled else { return }
                draft = question; busy = false; submit()
            } catch { guard requestID == id, !Task.isCancelled else { return }; busy = false; self.error = error.localizedDescription; typing = true }
        }
    }
    private func cancel() { task?.cancel(); task = nil; requestID = UUID(); busy = false }
    private func submit() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !busy else { return }
        focused = false; busy = true; error = nil
        let id = UUID(); requestID = id
        task = Task {
            do {
                let briefing = try await model.news.podcast(question: question)
                guard !Task.isCancelled, requestID == id else { return }
                busy = false; model.start(briefing)
            } catch is CancellationError { } catch { guard requestID == id else { return }; busy = false; self.error = error.localizedDescription }
        }
    }
}
