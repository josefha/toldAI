import SwiftUI

struct SignInView: View {
    @Environment(AppModel.self) private var model
    @State private var email = ""
    @State private var code = ""
    @State private var challenge: AuthChallenge?
    @State private var verifiedSession: UserSession?
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Wordmark(width: 126).padding(.top, 24)
                    ArtCard(title: "A little closer to the story.", subtitle: nil, art: "daily", height: 260)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(challenge == nil ? "Your world.\nWorth listening to." : "Check your email").font(.largeTitle.weight(.medium))
                        Text(challenge == nil ? "Five stories. A fresh perspective. Room for questions." : "Enter the code for \(challenge?.email ?? email).").foregroundStyle(Theme.secondary)
                    }
                    VStack(spacing: 16) {
                        if challenge == nil {
                            TextField("Email address", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).accessibilityIdentifier("emailField")
                        } else {
                            TextField("6-digit code", text: $code).textContentType(.oneTimeCode).keyboardType(.numberPad).textFieldStyle(.roundedBorder).accessibilityIdentifier("codeField")
                        }
                        if let error { ErrorNotice(message: error) }
                        Button { Task { await submit() } } label: {
                            if busy { ProgressView().tint(.gray) } else { Text(challenge == nil ? "Send Code" : "Continue") }
                        }.buttonStyle(PrimaryButtonStyle()).disabled(busy || (challenge == nil ? email.isEmpty : code.count != 6)).accessibilityIdentifier("authContinue")
                        if let challenge {
                            HStack {
                                Button("Edit Email") { self.challenge = nil; verifiedSession = nil; code = ""; error = nil }.frame(minHeight: 44)
                                Spacer()
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    let remaining = max(0, Int(challenge.resendAt.timeIntervalSince(context.date)))
                                    Button(remaining > 0 ? "Resend in \(remaining)s" : "Resend Code") { Task { await resend() } }.disabled(remaining > 0 || busy).frame(minHeight: 44)
                                }
                            }.font(.subheadline)
                        }
                    }
                }.padding(24)
            }.background(Theme.canvas).scrollDismissesKeyboard(.interactively)
        }
    }
    private func resend() async {
        busy = true; error = nil; defer { busy = false }
        do { challenge = try await model.auth.sendCode(email: email.trimmingCharacters(in: .whitespacesAndNewlines)); code = "" } catch { self.error = error.localizedDescription }
    }
    private func submit() async {
        busy = true; error = nil; defer { busy = false }
        do {
            if let challenge {
                let session: UserSession
                if let verifiedSession { session = verifiedSession } else { session = try await model.auth.verifyCode(email: challenge.email, code: code); verifiedSession = session }
                try await model.accept(session)
            } else { challenge = try await model.auth.sendCode(email: email.trimmingCharacters(in: .whitespacesAndNewlines)) }
        } catch { self.error = error.localizedDescription }
    }
}
struct InterestSetupView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: Set<Interest> = [.technology, .planet]
    @State private var name = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Make it yours.").font(.largeTitle.weight(.medium))
                    Text("Choose what you’re curious about. You can change this any time.").foregroundStyle(Theme.secondary)
                    TextField("Your name (optional)", text: $name).textContentType(.givenName).textFieldStyle(.roundedBorder).accessibilityIdentifier("nameField")
                    ForEach(Interest.allCases) { interest in
                        Button {
                            if selected.contains(interest) { selected.remove(interest) } else { selected.insert(interest) }
                        } label: {
                            HStack {
                                Image(systemName: interest.symbol).frame(width: 28)
                                Text(interest.title); Spacer()
                                Image(systemName: selected.contains(interest) ? "checkmark.circle.fill" : "circle")
                            }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(.plain).accessibilityAddTraits(selected.contains(interest) ? [.isSelected] : [])
                    }
                    if let error { ErrorNotice(message: error) }
                    Button { Task { await save() } } label: { if busy { ProgressView() } else { Text("Find My Stories") } }.buttonStyle(PrimaryButtonStyle()).disabled(selected.isEmpty || busy).accessibilityIdentifier("finishOnboarding")
                    Button("Sign Out") { Task { await model.signOut() } }.frame(maxWidth: .infinity, minHeight: 44)
                }.padding(24)
            }.background(Theme.canvas).navigationTitle("Your interests").navigationBarTitleDisplayMode(.inline)
        }
    }
    private func save() async {
        guard var profile = model.profile else { return }
        busy = true; error = nil; defer { busy = false }
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines); profile.interests = Interest.allCases.filter { selected.contains($0) }; profile.completedOnboarding = true
        do { try await model.saveProfile(profile) } catch { self.error = error.localizedDescription }
    }
}
