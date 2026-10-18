import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    private var interests: [Interest] { model.profile?.interests ?? [] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack { Wordmark(width: 94); Spacer(); Text(Date.now, format: .dateTime.month(.abbreviated).day()).font(.subheadline).foregroundStyle(Theme.secondary) }.padding(.top, 12)
                Text(greeting).font(.title3).foregroundStyle(Theme.secondary)
                if let error = model.feedError { ErrorNotice(message: error) { Task { await model.refresh() } } }
                if let briefing = model.briefing, !briefing.stories.isEmpty {
                    dailyCard(briefing)
                    if model.loadingBriefing { ProgressView() }
                    Text("Your interests").font(.title2.weight(.semibold))
                    LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(interests) { interest in
                            NavigationLink { CollectionView(interest: interest, briefing: briefing) } label: {
                                ArtCard(title: interest.title, subtitle: nil, art: interest.artwork, height: typeSize.isAccessibilitySize ? 240 : 205)
                            }.buttonStyle(.plain)
                        }
                    }
                    NavigationLink { BriefingDetailView(briefing: briefing) } label: {
                        HStack { Text("Explore all five stories").font(.headline); Spacer(); Image(systemName: "arrow.right") }.padding(22).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain)
                    Text("Updated \(briefing.generatedAt.formatted(date: .omitted, time: .shortened)) · Pull to refresh").font(.caption).foregroundStyle(Theme.secondary)
                } else if model.loadingBriefing {
                    ProgressView("Finding your stories…").frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    ContentUnavailableView { Label("Room for a fresh perspective", systemImage: "headphones") } description: { Text("No stories are ready yet. Try refreshing your briefing.") } actions: { Button("Refresh") { Task { await model.refresh() } } }
                }
            }.padding(.horizontal, 24).padding(.bottom, 24)
        }.background(Theme.canvas).toolbar(.hidden, for: .navigationBar).refreshable { await model.refresh() }
    }
    private var greeting: String { let hour = Calendar.current.component(.hour, from: .now); let prefix = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"; let name = model.profile?.name ?? ""; return name.isEmpty ? "\(prefix)." : "\(prefix), \(name)." }
    @ViewBuilder private func dailyCard(_ briefing: Briefing) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 20) {
                NavigationLink { BriefingDetailView(briefing: briefing) } label: {
                    VStack(alignment: .leading, spacing: 16) {
                        GeometryReader { geo in Artwork(name: briefing.artworkID).frame(width: geo.size.width, height: geo.size.height).clipped() }.frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 20))
                        Text(briefing.title).font(.title.weight(.medium)).foregroundStyle(Theme.ink)
                        Text("\(briefing.stories.count) stories · \(Int(ceil(briefing.duration / 60))) min").font(.subheadline).foregroundStyle(Theme.secondary)
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("dailyBriefing")
                Button { model.start(briefing) } label: { Label("Play", systemImage: "play.fill") }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("playBriefing")
            }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 28))
        } else {
        ZStack(alignment: .bottom) {
            NavigationLink { BriefingDetailView(briefing: briefing) } label: {
                ArtCard(title: "", subtitle: nil, art: briefing.artworkID, height: typeSize.isAccessibilitySize ? 430 : 350)
            }.buttonStyle(.plain).accessibilityLabel("Open daily briefing").accessibilityIdentifier("dailyBriefing")
            HStack(alignment: .center, spacing: 16) {
                NavigationLink { BriefingDetailView(briefing: briefing) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(briefing.title).font(.title.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                        Text("\(briefing.stories.count) stories · \(Int(ceil(briefing.duration / 60))) min").font(.subheadline)
                    }.foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                Button { model.start(briefing) } label: { Image(systemName: "play.fill").font(.title3).foregroundStyle(.black).frame(width: 60, height: 60).background(.white, in: Circle()) }.accessibilityLabel("Play daily briefing").accessibilityIdentifier("playBriefing")
            }.padding(22)
        }.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }
}
struct BriefingDetailView: View {
    @Environment(AppModel.self) private var model
    let briefing: Briefing
    var body: some View {
        List {
            Section {
                Artwork(name: briefing.artworkID).frame(height: 200).clipped().clipShape(RoundedRectangle(cornerRadius: 22)).listRowInsets(EdgeInsets())
                Button { model.start(briefing) } label: { Label("Play All Stories", systemImage: "play.fill") }.frame(minHeight: 44).accessibilityIdentifier("playAll")
            }
            Section("Your five") {
                ForEach(briefing.stories) { story in
                    NavigationLink { StoryDetailView(story: story, briefing: briefing) } label: { StoryRow(story: story) }
                }
            }
        }.navigationTitle(briefing.title).navigationBarTitleDisplayMode(.inline)
    }
}
struct StoryRow: View {
    let story: Story
    var body: some View {
        HStack(spacing: 14) {
            Artwork(name: story.artworkID).frame(width: 56, height: 64).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(story.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text("\(story.category.title) · \(story.sources.count) reference").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 8)
    }
}
struct CollectionView: View {
    let interest: Interest
    let briefing: Briefing
    var body: some View {
        List {
            Section { Artwork(name: interest.artwork).frame(height: 240).clipped().clipShape(RoundedRectangle(cornerRadius: 24)).listRowInsets(EdgeInsets()) }
            Section("In your edition") {
                ForEach(briefing.stories.filter { $0.category == interest }) { story in
                    NavigationLink { StoryDetailView(story: story, briefing: briefing) } label: { StoryRow(story: story) }
                }
                if !briefing.stories.contains(where: { $0.category == interest }) { Text("No stories in this edition. Ask to explore this interest.").foregroundStyle(.secondary) }
            }
        }.navigationTitle(interest.title).navigationBarTitleDisplayMode(.inline)
    }
}
struct StoryDetailView: View {
    @Environment(AppModel.self) private var model
    let story: Story
    let briefing: Briefing
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Artwork(name: story.artworkID).frame(height: 280).clipped().clipShape(RoundedRectangle(cornerRadius: 28))
                Text(story.category.title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                Text(story.title).font(.largeTitle.weight(.medium))
                Button { model.start(briefing, at: briefing.stories.firstIndex(where: { $0.id == story.id }) ?? 0) } label: { Label("Listen to Story", systemImage: "play.fill") }.buttonStyle(PrimaryButtonStyle())
                Text(story.summary).font(.body).lineSpacing(5).textSelection(.enabled)
                NavigationLink { SourceList(sources: story.sources) } label: { Label("View Sources", systemImage: "arrow.up.right.square").frame(minHeight: 44) }
                NavigationLink { TranscriptView(story: story) } label: { Label("Read Transcript", systemImage: "text.alignleft").frame(minHeight: 44) }
                ShareLink(item: story.title) { Label("Share Story Title", systemImage: "square.and.arrow.up").frame(minHeight: 44) }
            }.padding(24)
        }.background(Theme.canvas).navigationBarTitleDisplayMode(.inline)
    }
}
struct TranscriptView: View {
    let story: Story
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) { Text(story.title).font(.title); Text(story.transcript).lineSpacing(7).textSelection(.enabled) }.padding(24) }.navigationTitle("Transcript").navigationBarTitleDisplayMode(.inline)
    }
}
