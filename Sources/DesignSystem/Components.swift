import SwiftUI

enum Design {
    static let accent = Color(red: 240/255, green: 78/255, blue: 92/255)
    static let darkAccent = Color(red: 232/255, green: 222/255, blue: 247/255)
    static let darkSurface = Color(white: 37/255)
}

struct Poster: View {
    let url: URL?
    var width: CGFloat = 104
    var height: CGFloat = 156
    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else {
                RoundedRectangle(cornerRadius: 16).fill(.quaternary)
                    .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
            }
        }
        .frame(width: width, height: height).clipped().clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityHidden(true)
    }
}

struct ReleaseRow: View {
    let release: Release
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            Poster(url: release.poster)
            VStack(alignment: .leading, spacing: 8) {
                Text(release.title).font(.headline).foregroundStyle(.primary)
                if let original = release.titleOriginal, original != release.title { Text(original).font(.caption).foregroundStyle(.secondary) }
                HStack {
                    if let year = release.year { Text(year) }
                    if let grade = release.grade { Label(grade.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill") }
                }.font(.subheadline).foregroundStyle(.secondary)
                if let genres = release.genres { Text(genres).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
                if let count = release.episodesReleased {
                    Text("Серии: \(count) / \(release.episodesTotal.map(String.init) ?? "?")").font(.caption)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 8)
    }
}

struct FailureNotice: View {
    let message: String
    var retry: (() -> Void)?
    var body: some View {
        VStack(spacing: 12) {
            Label("Не удалось загрузить", systemImage: "wifi.exclamationmark").font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let retry { Button("Повторить", action: retry).buttonStyle(.bordered) }
        }.padding().frame(maxWidth: .infinity).accessibilityElement(children: .contain)
    }
}

struct GlassAction: ViewModifier {
    @Environment(AppSettings.self) private var settings
    func body(content: Content) -> some View {
        if settings.theme == .liquidGlass {
            content.padding(12).glassEffect(.regular.interactive(), in: Capsule())
        } else { content.padding(12).background(.quaternary, in: Capsule()) }
    }
}

extension EnvironmentValues {
    @Entry var repository = AnixartRepository()
}
