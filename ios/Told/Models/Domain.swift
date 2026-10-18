import Foundation

enum Interest: String, Codable, CaseIterable, Identifiable {
    case technology, planet, science, culture, business
    var id: String { rawValue }
    var title: String { switch self { case .technology: "Technology"; case .planet: "Our planet"; case .science: "Science"; case .culture: "Culture"; case .business: "Business" } }
    var artwork: String { switch self { case .technology, .science: "technology"; case .planet: "planet"; default: "daily" } }
    var symbol: String { switch self { case .technology: "cpu"; case .planet: "leaf"; case .science: "sparkle.magnifyingglass"; case .culture: "paintpalette"; case .business: "chart.line.uptrend.xyaxis" } }
}
struct NewsSource: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let title: String
    let url: URL
    let note: String
}
struct Story: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: Interest
    let summary: String
    let transcript: String
    let sources: [NewsSource]
    let artworkID: String
    var audioResource: String
    let duration: Double
}
struct Briefing: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let generatedAt: Date
    let artworkID: String
    var stories: [Story]
    var duration: Double { stories.reduce(0) { $0 + $1.duration } }
}
struct UserProfile: Codable, Equatable {
    var userID: String
    var email: String
    var name: String = ""
    var interests: [Interest] = []
    var location: String = ""
    var language: String = "en"
    var playbackSpeed: Float = 1
    var briefingVoiceModel: VoiceModel = .v4
    var answerVoiceModel: VoiceModel = .turbo
    var completedOnboarding: Bool = false
}
enum VoiceModel: String, Codable, CaseIterable, Identifiable {
    case v4 = "eleven_v4", turbo = "eleven_v4_turbo"
    var id: String { rawValue }
    var title: String { self == .v4 ? "Eleven v4" : "Eleven v4 Turbo" }
}
struct AuthChallenge: Codable { let email: String; let expiresAt: Date; let resendAt: Date }
struct UserSession: Codable { let userID: String; let email: String }
struct AnswerAudioPart: Codable, Identifiable, Hashable {
    let id: String
    var audioResource: String
    let duration: Double
}
struct ResearchAnswer: Codable, Identifiable, Hashable {
    let id: String
    let question: String
    let text: String
    let sources: [NewsSource]
    var audioResource: String
    var audioParts: [AnswerAudioPart]? = nil
    var audioComplete: Bool? = nil
}
struct QuestionRequest: Codable {
    let requestID: UUID
    let question: String
    let storyID: String?
    let previousTurns: [ResearchAnswer]
}
struct PlaybackCheckpoint: Codable {
    let briefing: Briefing
    let index: Int
    let position: Double
    let speed: Float
    var deepDives: [DeepDive]? = nil
    var activeAnswerID: String? = nil
    var answerPosition: Double? = nil
}

struct DeepDive: Codable, Identifiable {
    let id: String
    let storyID: String
    let storyPosition: Double
    var answer: ResearchAnswer
    var parentDiveID: String? = nil
    var parentPosition: Double? = nil
    var audioDuration: Double = 0
    var heard: Double = 0
    var interrupted = false
}

struct ListeningSegment: Identifiable {
    let id: String
    let storyIndex: Int
    let start: Double
    let end: Double
    let answer: ResearchAnswer?
    var duration: Double { max(0, end - start) }
}
