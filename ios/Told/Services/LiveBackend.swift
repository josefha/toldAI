import Foundation
import Security
import OSLog

private let timingLog = Logger(subsystem: "com.toldai.preview", category: "Timing")

struct AppConfiguration {
    let apiURL: URL?
    let supabaseURL: URL?
    let publishableKey: String
    static var current: AppConfiguration {
        func value(_ key: String) -> String { Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "" }
        func url(_ key: String) -> URL? {
            guard let url = URL(string: value(key)), let host = url.host, !host.contains("YOUR_"), !value(key).contains("$(") else { return nil }
            #if DEBUG
            if url.scheme == "http", ["localhost", "127.0.0.1"].contains(host) { return url }
            #endif
            return url.scheme == "https" ? url : nil
        }
        return AppConfiguration(apiURL: url("ToldAPIURL"), supabaseURL: url("ToldSupabaseURL"), publishableKey: value("ToldSupabaseKey"))
    }
    var ready: Bool { apiURL != nil && supabaseURL != nil && !publishableKey.isEmpty && !publishableKey.contains("$(") }
}
struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
private struct AuthTokens: Codable {
    struct User: Codable { let id: String; let email: String? }
    let access_token: String
    let refresh_token: String
    let expires_at: Double?
    let expires_in: Double?
    let user: User
    var expires: Date { Date(timeIntervalSince1970: expires_at ?? 0) }
}
enum CredentialStore {
    static let service = "com.toldai.auth"
    static func read(account: String = "session") -> Data? {
        var result: CFTypeRef?
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }; return result as? Data
    }
    static func save(_ data: Data, account: String = "session") throws {
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account]
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String:data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw APIError(message: "Your sign-in could not be saved securely. Please try again.") }
    }
    static func clear(account: String = "session") { SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account] as CFDictionary) }
}
@MainActor final class LiveBackend: AuthRepository, NewsRepository, ProfileRepository {
    let configuration: AppConfiguration
    private var tokens: AuthTokens?
    private var refreshing: Task<AuthTokens, Error>?
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }; formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }; throw APIError(message: "The server returned an invalid date.")
        }
        return decoder
    }()
    init(configuration: AppConfiguration = .current) { self.configuration = configuration; if let data = CredentialStore.read() { tokens = try? JSONDecoder().decode(AuthTokens.self, from: data) } }
    var currentSession: UserSession? { tokens.map { UserSession(userID: $0.user.id, email: $0.user.email ?? "") } }
    private func configured() throws { guard configuration.ready else { throw APIError(message: "told. needs its server connection configured before you can sign in.") } }
    private func response(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError(message: "The server could not be reached.") }
        guard (200...299).contains(response.statusCode) else {
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let message = body?["error_description"] as? String ?? body?["msg"] as? String ?? body?["error"] as? String ?? "The request could not finish. Please try again."
            throw APIError(message: response.statusCode == 401 ? "Your sign-in has expired. Please sign in again." : message)
        }
        return data
    }
    private func authRequest(_ path: String, body: [String: Any]?, token: String? = nil) async throws -> Data {
        try configured(); var request = URLRequest(url: configuration.supabaseURL!.appendingPathComponent("auth/v1/\(path)")); request.httpMethod = "POST"; request.timeoutInterval = 30
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        return try await response(request)
    }
    private func save(_ value: AuthTokens) throws {
        let normalized = AuthTokens(access_token: value.access_token, refresh_token: value.refresh_token, expires_at: value.expires_at ?? Date().timeIntervalSince1970 + (value.expires_in ?? 3600), expires_in: value.expires_in, user: value.user)
        try CredentialStore.save(JSONEncoder().encode(normalized)); tokens = normalized
    }
    private func accessToken() async throws -> String {
        guard let tokens else { throw APIError(message: "Please sign in to continue.") }
        if tokens.expires.timeIntervalSinceNow > 60 { return tokens.access_token }
        if let refreshing { return try await refreshing.value.access_token }
        let task = Task<AuthTokens, Error> {
            try configured()
            var components = URLComponents(url: configuration.supabaseURL!.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
            var request = URLRequest(url: components.url!); request.httpMethod = "POST"; request.timeoutInterval = 30
            request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": tokens.refresh_token])
            return try JSONDecoder().decode(AuthTokens.self, from: await response(request))
        }
        refreshing = task; defer { refreshing = nil }
        let value = try await task.value; try Task.checkCancellation(); guard self.tokens != nil else { throw CancellationError() }; try save(value); return value.access_token
    }
    private func api(_ path: String, method: String = "GET", body: Data? = nil, contentType: String = "application/json") async throws -> Data {
        try configured(); let token = try await accessToken()
        var request = URLRequest(url: configuration.apiURL!.appendingPathComponent("v1/\(path)")); request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 90
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        return try await response(request)
    }
    func sendCode(email: String) async throws -> AuthChallenge {
        _ = try await authRequest("otp", body: ["email": email, "create_user": true])
        return AuthChallenge(email: email, expiresAt: .now.addingTimeInterval(600), resendAt: .now.addingTimeInterval(60))
    }
    func verifyCode(email: String, code: String) async throws -> UserSession {
        let data = try await authRequest("verify", body: ["email": email, "token": code, "type": "email"])
        try save(JSONDecoder().decode(AuthTokens.self, from: data)); return currentSession!
    }
    #if DEBUG
    func signIn(email: String, password: String) async throws -> UserSession {
        try configured()
        var components = URLComponents(url: configuration.supabaseURL!.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"; request.timeoutInterval = 30
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let data = try await response(request)
        try save(JSONDecoder().decode(AuthTokens.self, from: data))
        return currentSession!
    }
    #endif
    func signOut() async {
        let token = tokens?.access_token; refreshing?.cancel(); refreshing = nil; tokens = nil; CredentialStore.clear()
        if let token { _ = try? await authRequest("logout", body: nil, token: token) }
    }
    func deleteAccount() async throws { _ = try await api("me", method: "DELETE"); await signOut() }
    func load(userID: String) async throws -> UserProfile? { try decoder.decode(UserProfile.self, from: await api("me")) }
    func save(_ profile: UserProfile) async throws { _ = try await api("me", method: "PATCH", body: JSONEncoder().encode(profile)) }
    private struct JobResponse<T: Decodable>: Decodable { let id: String; let status: String; let error: String?; let result: T? }
    private func job<T: Decodable>(_ body: [String: Any], as type: T.Type, onReady: ((T) async throws -> Void)? = nil) async throws -> T {
        let id = body["requestID"] as! String
        let started = Date(); var outcome = "failed"
        defer { timingLog.info("stage=client_job jobID=\(id, privacy: .public) status=\(outcome, privacy: .public) durationMs=\(Int(Date().timeIntervalSince(started) * 1000))") }
        var reportedPartial = false
        do {
            _ = try await api("jobs", method: "POST", body: JSONSerialization.data(withJSONObject: body))
            for _ in 0..<(onReady == nil ? 450 : 1800) {
                try Task.checkCancellation()
                let response = try decoder.decode(JobResponse<T>.self, from: await api("jobs/\(id)"))
                if response.status == "completed", let result = response.result { outcome = "completed"; return result }
                if response.status == "failed" || response.status == "cancelled" { throw APIError(message: response.error ?? "This request was cancelled.") }
                if !reportedPartial, response.status == "running", let result = response.result, let onReady {
                    try await onReady(result); reportedPartial = true
                }
                try await Task.sleep(for: .milliseconds(onReady == nil ? 2000 : 500))
            }
            throw APIError(message: "This is taking longer than expected. Please try again.")
        } catch {
            // An independent task can cancel the server job even when its caller was cancelled.
            Task { _ = try? await self.api("jobs/\(id)", method: "DELETE") }
            throw error
        }
    }
    func dailyBriefing(interests: [Interest]) async throws -> Briefing { try await download(await job(["kind":"daily", "requestID":UUID().uuidString], as: Briefing.self)) }
    func podcast(question: String) async throws -> Briefing { try await download(await job(["kind":"podcast", "requestID":UUID().uuidString, "question":question], as: Briefing.self)) }
    private func download(_ value: Briefing) async throws -> Briefing {
        var briefing = value
        for i in briefing.stories.indices { briefing.stories[i].audioResource = try await AudioCache.download(id: briefing.stories[i].id, remote: briefing.stories[i].audioResource) }
        return briefing
    }
    func research(_ request: QuestionRequest) async throws -> ResearchAnswer {
        try await research(request, onReady: { _ in })
    }
    func research(_ request: QuestionRequest, onReady: @escaping @MainActor (ResearchAnswer) -> Void) async throws -> ResearchAnswer {
        guard let storyID = request.storyID else { throw APIError(message: "Choose a story before asking a follow-up.") }
        let started = Date()
        let answer = try await job(["kind":"question", "requestID":request.requestID.uuidString,"question":request.question,"storyID":storyID,"previousAnswerIDs":request.previousTurns.suffix(12).map(\.id),"progressiveAudio":true], as: ResearchAnswer.self, onReady: { partial in
            let ready = try await self.downloadAnswer(partial)
            try Task.checkCancellation()
            timingLog.info("stage=client_first_passage_ready durationMs=\(Int(Date().timeIntervalSince(started) * 1000))")
            onReady(ready)
        })
        return try await downloadAnswer(answer)
    }
    private func downloadAnswer(_ value: ResearchAnswer) async throws -> ResearchAnswer {
        var answer = value
        if var parts = answer.audioParts, !parts.isEmpty {
            for i in parts.indices { parts[i].audioResource = try await AudioCache.download(id: parts[i].id, remote: parts[i].audioResource) }
            answer.audioParts = parts; answer.audioResource = parts[0].audioResource
        } else { answer.audioResource = try await AudioCache.download(id: answer.id, remote: answer.audioResource) }
        return answer
    }
    func transcribe(_ recording: URL) async throws -> String {
        let started = Date()
        defer { timingLog.info("stage=client_transcription durationMs=\(Int(Date().timeIntervalSince(started) * 1000))") }
        let boundary = UUID().uuidString; var data = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"question.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n".utf8)
        data.append(try Data(contentsOf: recording)); data.append(Data("\r\n--\(boundary)--\r\n".utf8))
        struct Transcript: Decodable { let text: String }
        return try decoder.decode(Transcript.self, from: await api("transcriptions", method: "POST", body: data, contentType: "multipart/form-data; boundary=\(boundary)")).text
    }
}
@MainActor enum AudioCache {
    static var directory: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Audio", isDirectory: true) }
    static func url(_ resource: String) -> URL? {
        guard resource == URL(fileURLWithPath: resource).lastPathComponent else { return nil }
        let path = directory.appendingPathComponent(resource); return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }
    static func download(id: String, remote: String) async throws -> String {
        guard UUID(uuidString: id) != nil, let url = URL(string: remote), let host = url.host, (url.scheme == "https" || (["127.0.0.1","localhost"].contains(host) && url.scheme == "http")) else { throw APIError(message: "The audio link is invalid.") }
        let started = Date(); var cacheHit = false; var outcome = "failed"
        defer { timingLog.info("stage=audio_download clipID=\(id, privacy: .public) cacheHit=\(cacheHit) status=\(outcome, privacy: .public) durationMs=\(Int(Date().timeIntervalSince(started) * 1000))") }
        let name = "\(id).mp3"; if self.url(name) != nil { cacheHit = true; outcome = "completed"; return name }
        let (temporary, response) = try await URLSession.shared.download(from: url)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let response = response as? HTTPURLResponse, response.statusCode == 200, response.mimeType?.hasPrefix("audio/") == true else { throw APIError(message: "Audio could not be downloaded. Refresh and try again.") }
        try Task.checkCancellation(); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var destination = directory.appendingPathComponent(name)
        try FileManager.default.moveItem(at: temporary, to: destination)
        var values = URLResourceValues(); values.isExcludedFromBackup = true; try destination.setResourceValues(values)
        outcome = "completed"
        return name
    }
    static func clear() { try? FileManager.default.removeItem(at: directory) }
}
