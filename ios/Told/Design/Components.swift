import SwiftUI

enum Theme {
    static let canvas = Color("Canvas")
    static let surface = Color("Surface")
    static let ink = Color("Ink")
    static let secondary = Color("Secondary")
}
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17).padding(.horizontal, 20)
            .foregroundStyle(scheme == .dark ? Color.black : Color.white)
            .background(Theme.ink, in: Capsule()).opacity(enabled ? (configuration.isPressed ? 0.72 : 1) : 0.4)
    }
}
struct Wordmark: View {
    var width: CGFloat = 100
    var body: some View {
        Image("Wordmark").resizable().renderingMode(.template).scaledToFit().frame(width: width).foregroundStyle(Theme.ink).accessibilityLabel("told")
    }
}
struct Artwork: View {
    let name: String
    var body: some View { Image(name).resizable().scaledToFill().accessibilityHidden(true) }
}
struct ArtCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let subtitle: String?
    let art: String
    var height: CGFloat = 230
    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 16) {
                GeometryReader { geo in Artwork(name: art).frame(width: geo.size.width, height: geo.size.height).clipped() }.frame(height: 140)
                VStack(alignment: .leading, spacing: 12) {
                    Text(title).font(.title3.weight(.medium)).foregroundStyle(Theme.ink)
                    if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Theme.secondary) }
                }.padding(20)
            }.background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 24))
        } else {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in Artwork(name: art).frame(width: geo.size.width, height: geo.size.height).clipped() }
            LinearGradient(colors: [.clear, .black.opacity(0.15), .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.9)) }
            }.padding(20).foregroundStyle(.white)
        }.frame(height: height).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
struct ErrorNotice: View {
    let message: String
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.circle").font(.subheadline).fixedSize(horizontal: false, vertical: true)
            if let retry { Button("Try Again", action: retry).font(.headline).frame(minHeight: 44) }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16)).accessibilityElement(children: .contain)
    }
}
struct SourceList: View {
    let sources: [NewsSource]
    var body: some View {
        List {
            ForEach(sources) { source in
                VStack(alignment: .leading, spacing: 10) {
                    Text(source.name).font(.headline)
                    Text(source.note).font(.subheadline).foregroundStyle(.secondary)
                    Link(destination: source.url) { Label("Open \(source.name)", systemImage: "arrow.up.right") }.frame(minHeight: 44)
                }.padding(.vertical, 8)
            }
        }.navigationTitle("Sources").navigationBarTitleDisplayMode(.inline)
    }
}
extension Double {
    var playbackTime: String { let total = max(0, Int(self)); return String(format: "%d:%02d", total / 60, total % 60) }
}
