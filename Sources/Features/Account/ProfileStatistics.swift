import SwiftUI
import Charts
import Foundation

struct ProfileStatistics: View {
    let profile: Profile
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var showHelp = false
    private struct Slice: Identifiable {
        let id: Int; let key: String; let count: Int; let color: Color
    }
    private var slices: [Slice] {
        let values = [profile.watchingCount, profile.planCount, profile.completedCount, profile.holdOnCount, profile.droppedCount]
        let keys = ["list_watching", "list_plan", "list_completed", "list_hold_on", "list_dropped"]
        let colors: [Color] = [Color(red:115/255,green:201/255,blue:120/255), Color(red:195/255,green:115/255,blue:201/255),
            Color(red:105/255,green:121/255,blue:206/255), Color(red:255/255,green:212/255,blue:104/255), Color(red:255/255,green:96/255,blue:91/255)]
        return values.indices.map { Slice(id: $0, key: keys[$0], count: max(0, values[$0] ?? 0), color: colors[$0]) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if profile.isStatsHidden == true {
                Text(OriginalCopy.text("profile_privacy_hint")).foregroundStyle(.secondary)
            } else if profile.hasStatistics {
                if textSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 18) { legend; donut } }
                else { HStack(spacing: 24) { legend; donut } }
                preferences("profile_statistics_genres_label", profile.preferredGenres)
                preferences("profile_statistics_audience_label", profile.preferredAudiences)
                preferences("profile_statistics_themes_label", profile.preferredThemes)
                if let episodes = profile.watchedEpisodeCount, episodes > 0 {
                    stat(OriginalCopy.text("watched_episode_count"), value: episodes.formatted(.number.locale(Locale(identifier:"ru_RU"))))
                }
                if let minutes = profile.watchedTime, minutes > 0 {
                    stat(OriginalCopy.text("watched_time"), value: ProfileTimeText.format(minutes: minutes))
                }
                Button(OriginalCopy.text("statistics_help_title")) { showHelp = true }.font(.footnote)
            } else { ProgressView() }
        }.padding(.vertical, 8).accessibilityIdentifier("profileStatistics")
            .sheet(isPresented: $showHelp) {
                NavigationStack {
                    ScrollView { Text(OriginalCopy.text("statistics_help_message")).padding() }
                        .navigationTitle(OriginalCopy.text("statistics_help_title"))
                        .toolbar { Button("Закрыть") { showHelp = false } }
                }.presentationDetents([.medium, .large])
            }
    }
    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(slices) { slice in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3).fill(slice.color).frame(width: 14,height:14).accessibilityHidden(true)
                    Text(OriginalCopy.text(slice.key)).foregroundStyle(.secondary)
                    Text(slice.count.formatted()).fontWeight(.medium).accessibilityIdentifier("profile.listCount.\(slice.id)")
                }.font(.subheadline)
            }
        }.frame(maxWidth:.infinity, alignment:.leading)
    }
    @ViewBuilder private var donut: some View {
        if slices.contains(where: { $0.count > 0 }) {
            Chart(slices.filter { $0.count > 0 }) { slice in
                SectorMark(angle:.value("Релизы", slice.count),innerRadius:.ratio(0.5)).foregroundStyle(slice.color)
            }.chartLegend(.hidden).frame(width:138,height:138).accessibilityHidden(true)
        }
    }
    @ViewBuilder private func preferences(_ key: String, _ values: [ProfileGenre]?) -> some View {
        if let values, !values.isEmpty {
            (Text(OriginalCopy.text(key) + " ").bold() + Text(values.sorted { $0.percentage > $1.percentage }.map { "\($0.name) (\($0.percentage)%)" }.joined(separator:", ")).foregroundColor(.secondary)).font(.footnote)
        }
    }
    private func stat(_ label: String, value: String) -> some View {
        (Text(label + " ").foregroundColor(.secondary) + Text(value).fontWeight(.medium)).font(.subheadline)
    }
}

enum ProfileTimeText {
    static func format(minutes: Int64) -> String {
        let minutes = max(0, minutes), days = minutes / 1440, hours = (minutes / 60) % 24
        func quantity(_ key: String, _ value: Int64) -> String {
            String(format: OriginalCopy.plural(key,count:Int(clamping:value)), locale:Locale(identifier:"ru_RU"), Int(clamping:value))
        }
        if days > 0 { return "~ " + quantity("days", days) + (hours > 0 ? " " + quantity("hours", hours) : "") }
        if hours > 0 { return "~ " + quantity("hours", hours) }
        return "~ " + quantity("minutes", minutes)
    }
}

struct ProfileWatchDynamics: View {
    let days: [ProfileWatchDay]
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier:"ru_RU"); formatter.dateFormat = "dd.MM"; return formatter
    }()
    private var maximum: Int { max(1, days.map(\.count).max() ?? 1) }
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text(OriginalCopy.text("profile_watch_dynamics")).font(.headline)
            ScrollView(.horizontal) {
                HStack(alignment:.bottom,spacing:12) {
                    ForEach(days) { day in
                        VStack(spacing:8) {
                            Text(day.count.formatted()).font(.caption).foregroundStyle(.secondary)
                            RoundedRectangle(cornerRadius:4).fill(Color.accentColor)
                                .frame(width:20,height:max(10,100 * CGFloat(max(0,day.count)) / CGFloat(maximum)))
                            if let timestamp = day.timestamp {
                                Text(Self.dateFormatter.string(from:Date(timeIntervalSince1970:Double(timestamp))))
                                    .font(.caption2).foregroundStyle(.secondary).rotationEffect(.degrees(-60)).frame(height:35)
                            }
                        }.frame(minWidth:30,height:165,alignment:.bottom)
                            .accessibilityElement(children:.combine)
                    }
                }.padding(.horizontal,4)
            }.scrollIndicators(.hidden)
            Text(OriginalCopy.text("profile_watch_dynamics_hint")).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical,8).accessibilityIdentifier("profileWatchDynamics")
    }
}
