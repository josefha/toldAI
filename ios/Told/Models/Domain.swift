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
    let audioResource: String
    let duration: Double
}
struct Briefing: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let generatedAt: Date
    let artworkID: String
    let stories: [Story]
    let isDemo: Bool
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
struct DemoSession: Codable { let userID: String; let email: String }
struct ResearchAnswer: Codable, Identifiable, Hashable {
    let id: String
    let question: String
    let text: String
    let sources: [NewsSource]
    let audioResource: String
    let isDemo: Bool
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

struct DeepDive: Identifiable {
    let id: String
    let storyID: String
    let storyPosition: Double
    let answer: ResearchAnswer
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
