import SwiftUI

struct StatisticsDashboardView: View {
    let entries: [JournalEntry]
    @Environment(\.dismiss) private var dismiss

    private var stats: JournalStatistics {
        JournalStatistics(entries: entries)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let isWideLayout = proxy.size.width >= 820

                ScrollView {
                    if isWideLayout {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 14) {
                                hero(isWideLayout: true)
                                sevenDayTrend
                                sectionHealth
                            }
                            .frame(maxWidth: .infinity, alignment: .top)

                            VStack(alignment: .leading, spacing: 14) {
                                categoryBreakdown
                                moodBreakdown
                                writingRhythm
                            }
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                        .padding(16)
                        .frame(maxWidth: 1120, alignment: .top)
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            hero(isWideLayout: false)
                            sevenDayTrend
                            sectionHealth
                            categoryBreakdown
                            moodBreakdown
                            writingRhythm
                        }
                        .padding(16)
                        .frame(maxWidth: 760, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(dashboardBackground)
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("关闭", systemImage: "xmark")
                    }
                }
            }
        }
        .tint(.teal)
    }

    private var dashboardBackground: some View {
        LinearGradient(
            colors: [
                Color.teal.opacity(0.10),
                Color(.systemGroupedBackground),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func hero(isWideLayout: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("写作总览")
                        .font(.title2.weight(.bold))

                    Text(stats.insightText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.teal)
            }

            LazyVGrid(columns: metricColumns(isWideLayout: isWideLayout), spacing: 10) {
                MetricTile(title: "日记", value: "\(stats.totalEntries)", systemImage: "doc.text", tint: .teal)
                MetricTile(title: "总词数", value: "\(stats.totalWords)", systemImage: "text.word.spacing", tint: .indigo)
                MetricTile(title: "最近连续", value: "\(stats.recentStreak) 天", systemImage: "flame", tint: .orange)
                MetricTile(title: "最长连续", value: "\(stats.longestStreak) 天", systemImage: "trophy", tint: .pink)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(cardStroke)
    }

    private func metricColumns(isWideLayout: Bool) -> [GridItem] {
        if isWideLayout {
            return Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        }

        return Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    }

    private var sevenDayTrend: some View {
        StatsSection(title: "最近 7 天", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    CompactNumber(title: "本周日记", value: "\(stats.entriesThisWeek)")
                    CompactNumber(title: "本周词数", value: "\(stats.wordsThisWeek)")
                    CompactNumber(title: "篇均词数", value: "\(stats.averageWords)")
                }

                SevenDayBarChart(days: stats.lastSevenDays)
            }
        }
    }

    private var sectionHealth: some View {
        StatsSection(title: "小节结构", systemImage: "number") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(stats.formattedSectionCoverage)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.teal)

                    Text("日记已使用 ### 小节")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: stats.sectionCoverage)
                    .tint(.teal)

                HStack(spacing: 12) {
                    Label("\(stats.entriesWithSections) 篇有小节", systemImage: "checkmark.circle")
                    Label(String(format: "%.1f 小节/篇", stats.averageSections), systemImage: "list.bullet.rectangle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var categoryBreakdown: some View {
        StatsSection(title: "分类分布", systemImage: "square.grid.2x2") {
            VStack(spacing: 10) {
                ForEach(stats.categoryBreakdown) { item in
                    DistributionRow(
                        title: item.category.rawValue,
                        detail: "\(item.entryCount) 篇 · \(item.wordCount) 词",
                        systemImage: item.category.systemImage,
                        value: item.entryCount,
                        maxValue: maxCategoryCount,
                        tint: item.category.tint
                    )
                }
            }
        }
    }

    private var moodBreakdown: some View {
        StatsSection(title: "心情分布", systemImage: "face.smiling") {
            VStack(spacing: 10) {
                ForEach(stats.moodBreakdown) { item in
                    DistributionRow(
                        title: item.mood.rawValue,
                        detail: "\(item.entryCount) 篇",
                        systemImage: item.mood.systemImage,
                        value: item.entryCount,
                        maxValue: maxMoodCount,
                        tint: .teal
                    )
                }
            }
        }
    }

    private var writingRhythm: some View {
        StatsSection(title: "写作节奏", systemImage: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 12) {
                InsightRow(
                    title: "主要分类",
                    value: stats.dominantCategory?.category.rawValue ?? "暂无",
                    systemImage: stats.dominantCategory?.category.systemImage ?? "tray"
                )

                InsightRow(
                    title: "常见心情",
                    value: stats.dominantMood?.mood.rawValue ?? "暂无",
                    systemImage: stats.dominantMood?.mood.systemImage ?? "face.smiling"
                )

                InsightRow(
                    title: "最近记录",
                    value: stats.latestEntryDate?.journalTitleText ?? "暂无",
                    systemImage: "clock"
                )
            }
        }
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.white.opacity(0.55), lineWidth: 1)
    }

    private var maxCategoryCount: Int {
        max(stats.categoryBreakdown.map(\.entryCount).max() ?? 0, 1)
    }

    private var maxMoodCount: Int {
        max(stats.moodBreakdown.map(\.entryCount).max() ?? 0, 1)
    }
}

private struct StatsSection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.bold))

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CompactNumber: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline.weight(.bold))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SevenDayBarChart: View {
    let days: [JournalStatistics.DailyWriting]

    private var maxWords: Int {
        max(days.map(\.wordCount).max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 9) {
            ForEach(days) { day in
                VStack(spacing: 7) {
                    Text(day.wordCount == 0 ? "" : "\(day.wordCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(height: 14)

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(.systemBackground))
                            .frame(height: 92)

                        RoundedRectangle(cornerRadius: 5)
                            .fill(day.wordCount > 0 ? Color.teal : Color.secondary.opacity(0.15))
                            .frame(height: barHeight(for: day.wordCount))
                    }

                    Text(day.date.journalWeekdayText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 134)
    }

    private func barHeight(for words: Int) -> CGFloat {
        guard words > 0 else { return 8 }
        return max(12, CGFloat(words) / CGFloat(maxWords) * 92)
    }
}

private struct DistributionRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let value: Int
    let maxValue: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(value > 0 ? tint : .secondary)

                Spacer(minLength: 8)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemBackground))

                    Capsule()
                        .fill(value > 0 ? tint : Color.secondary.opacity(0.14))
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 8)
        }
    }

    private var ratio: CGFloat {
        guard maxValue > 0 else { return 0 }
        return max(value == 0 ? 0 : 0.08, CGFloat(value) / CGFloat(maxValue))
    }
}

private struct InsightRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.teal)
                .frame(width: 28, height: 28)
                .background(Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
    }
}
