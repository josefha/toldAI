import SwiftUI

@main struct ToldApp: App {
    @State private var model = AppModel.demo()
    var body: some Scene {
        WindowGroup {
            RootView().environment(model).tint(Theme.ink)
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--dark") ? .dark : nil)
                .transformEnvironment(\.dynamicTypeSize) { value in if ProcessInfo.processInfo.arguments.contains("--large-type") { value = .accessibility5 } }

        }
    }
}
struct RootView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Group {
            if model.session == nil { SignInView() }
            else if model.profile?.completedOnboarding != true { InterestSetupView() }
            else { MainTabs() }
        }.background(Theme.canvas).foregroundStyle(Theme.ink)
    }
}
struct MainTabs: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            NavigationStack { HomeView() }.modifier(MiniPlayerInset()).tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            NavigationStack { AskView() }.modifier(MiniPlayerInset()).tabItem { Label("Ask", systemImage: "waveform") }.tag(1)
            NavigationStack { ProfileView() }.modifier(MiniPlayerInset()).tabItem { Label("You", systemImage: "person.crop.circle") }.tag(2)
        }
        .sheet(isPresented: $model.showPlayer) { PlayerView(model: model).environment(\.dynamicTypeSize, typeSize).presentationDragIndicator(.visible).presentationCornerRadius(32) }
        .task { if model.briefing == nil { await model.refresh() } }
    }
}
// Inset each tab's navigation content so pushed lists and scroll views reserve
// the player's actual height. TabView owns the tab-bar clearance.
private struct MiniPlayerInset: ViewModifier {
    @Environment(AppModel.self) private var model
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: model.playback.story == nil ? 0 : 24) {
            if model.playback.story != nil {
                MiniPlayer().padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
    }
}
struct MiniPlayer: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        if let story = model.playback.story {
            HStack(spacing: 12) {
                Button { model.showPlayer = true } label: {
                    HStack(spacing: 12) {
                        Artwork(name: story.artworkID).frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.playback.activeAnswer?.question ?? story.title).font(.subheadline.weight(.medium)).lineLimit(1)
                            Text(model.playback.isTransitioning ? "Continuing your story…" : model.playback.isPlaying ? "Now playing" : "Continue listening").font(.caption).foregroundStyle(Theme.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("miniPlayer")
                Button { model.playback.toggle() } label: { Image(systemName: model.playback.isPlaying || model.playback.isTransitioning ? "pause.fill" : "play.fill").frame(width: 44, height: 44) }.accessibilityLabel(model.playback.isPlaying || model.playback.isTransitioning ? "Pause" : "Play")
            }.padding(10).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.secondary.opacity(0.2)))
        }
    }
}
