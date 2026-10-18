import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingSignOut = false
    @State private var confirmingDelete = false
    @State private var deleting = false
    @State private var accountError: String?
    var body: some View {
        List {
            Section {
                HStack(spacing: 18) {
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 44)).foregroundStyle(Theme.secondary)
                    VStack(alignment: .leading, spacing: 5) { Text(model.profile?.name.isEmpty == false ? model.profile!.name : "Your account").font(.title3.weight(.medium)); Text(model.profile?.email ?? "").font(.subheadline).foregroundStyle(.secondary) }
                }.padding(.vertical, 12)
            }
            Section("Make it yours") {
                NavigationLink { if let profile = model.profile { EditProfileView(profile: profile) } } label: { Label("Interests & Profile", systemImage: "slider.horizontal.3") }
                NavigationLink { if let profile = model.profile { PlaybackSettingsView(profile: profile) } } label: { Label("Voice & Playback", systemImage: "waveform") }
            }
            Section("About") {
                NavigationLink { AboutView() } label: { Label("About told.", systemImage: "info.circle") }
                Text("English").foregroundStyle(.secondary)
            }
            Section { Button("Sign Out", role: .destructive) { confirmingSignOut = true }.frame(minHeight: 44).accessibilityIdentifier("signOut") }
            Section {
                if let accountError { ErrorNotice(message: accountError) }
                Button(deleting ? "Deleting…" : "Delete Account", role: .destructive) { confirmingDelete = true }.disabled(deleting)
            }
        }.navigationTitle("You")
            .confirmationDialog("Permanently delete your account and listening history?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) { Task { deleting = true; defer { deleting = false }; do { try await model.news.deleteAccount(); await model.signOut() } catch { accountError = error.localizedDescription } } }
            }
            .confirmationDialog("Sign out of told.?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { Task { await model.signOut() } }.accessibilityIdentifier("confirmSignOut")
            }
    }
}
struct EditProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var profile: UserProfile
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        Form {
            Section("Profile") { TextField("Name", text: $profile.name).textContentType(.givenName); TextField("Country or city (optional)", text: $profile.location); Text("Your location is optional.").font(.caption).foregroundStyle(.secondary) }
            Section("Interests") {
                ForEach(Interest.allCases) { interest in
                    Toggle(interest.title, isOn: Binding(get: { profile.interests.contains(interest) }, set: { selected in if selected { profile.interests.append(interest) } else { profile.interests.removeAll { $0 == interest } } }))
                }
            }
            Section { LabeledContent("Language", value: "English"); Text("More languages will follow.").font(.caption).foregroundStyle(.secondary) }
            if let error { Section { ErrorNotice(message: error) } }
        }.navigationTitle("Interests & Profile").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(busy || profile.interests.isEmpty).accessibilityIdentifier("saveProfile") } }
            .interactiveDismissDisabled(busy)
    }
    private func save() async { busy = true; error = nil; defer { busy = false }; do { try await model.saveProfile(profile); await model.refresh(); dismiss() } catch { self.error = error.localizedDescription } }
}
struct PlaybackSettingsView: View {
    @Environment(AppModel.self) private var model
    @State var profile: UserProfile
    @State private var error: String?
    @State private var busy = false
    @State private var saved = false
    var body: some View {
        Form {
            Section("Listening") { Picker("Playback speed", selection: $profile.playbackSpeed) { ForEach([Float(0.75), 1, 1.25, 1.5, 2], id: \.self) { Text("\($0.formatted())×").tag($0) } } }
            Section("Voice") {
                Picker("Prepared briefings", selection: $profile.briefingVoiceModel) { ForEach(VoiceModel.allCases) { Text($0.title).tag($0) } }
                Picker("Interactive answers", selection: $profile.answerVoiceModel) { ForEach(VoiceModel.allCases) { Text($0.title).tag($0) } }
            }
            if let error { ErrorNotice(message: error) }
            Button(saved ? "Saved" : "Save Preferences") { Task { busy = true; error = nil; do { try await model.saveProfile(profile); saved = true } catch { self.error = error.localizedDescription }; busy = false } }.disabled(busy).frame(minHeight: 44)
        }.navigationTitle("Voice & Playback").navigationBarTitleDisplayMode(.inline).onChange(of: profile) { _, _ in saved = false }
    }
}
struct AboutView: View {
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            Wordmark(width: 140)
            Text("A little closer to the story.").font(.largeTitle.weight(.medium))
            Text("Five stories. A fresh perspective. Space to follow your curiosity.")
            Text("Listen at your own pace. Pause for a question, explore the background, then pick up where you left off.")
            Text("Your profile is saved to your account. Downloaded audio and listening position stay on this device until you sign out.").foregroundStyle(Theme.secondary)
        }.padding(24) }.navigationTitle("About").navigationBarTitleDisplayMode(.inline)
    }
}
