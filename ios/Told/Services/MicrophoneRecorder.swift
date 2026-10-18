import Foundation
import AVFoundation

@MainActor protocol VoiceRecorder {
    func start() async throws
    func stop() throws -> URL
    func cancel()
}
@MainActor final class MicrophoneRecorder: VoiceRecorder {
    private var recorder: AVAudioRecorder?
    private var file: URL?
    func start() async throws {
        cancel()
        let allowed = await AVAudioApplication.requestRecordPermission()
        try Task.checkCancellation()
        guard allowed else { throw APIError(message: "Microphone access is off. Enable it in Settings, or type your question.") }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let recorder = try AVAudioRecorder(url: file, settings: [AVFormatIDKey:kAudioFormatMPEG4AAC, AVSampleRateKey:44100, AVNumberOfChannelsKey:1, AVEncoderBitRateKey:64000])
        guard recorder.record(forDuration: 60) else { throw APIError(message: "Recording could not start. Please try again.") }
        self.file = file; self.recorder = recorder
    }
    func stop() throws -> URL {
        guard let file, let recorder else { throw APIError(message: "No recording is ready. Please try again.") }
        recorder.stop(); self.recorder = nil; self.file = nil
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        return file
    }
    func cancel() { recorder?.stop(); recorder = nil; if let file { try? FileManager.default.removeItem(at: file) }; file = nil; try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio) }
}
