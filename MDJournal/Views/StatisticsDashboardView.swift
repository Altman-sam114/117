import SwiftUI

struct StatisticsDashboardView: View {
    let entries: [JournalEntry]
    let showsCloseButton: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(entries: [JournalEntry], showsCloseButton: Bool = true) {
        self.entries = entries
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        let stats = JournalStatistics(entries: entries)

        NavigationStack {
            GeometryReader { proxy in
                let columns = JournalDashboardLayout.columnCount(
                    width: proxy.size.width, dynamicTypeSize: dynamicTypeSize
                )
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        hero(isWideLayout: columns == 2, stats: stats)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columns),
                            alignment: .leading,
                            spacing: 20
                        ) {
                            sevenDayTrend(stats)
                            sectionHealth(stats)
                            categoryBreakdown(stats)
                            moodBreakdown(stats)
                            writingRhythm(stats)
                        }
                    }
                    .padding(JournalTheme.pageInset)
                    .frame(maxWidth: 1120, alignment: .top)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(dashboardBackground)
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Label("关闭", systemImage: "xmark")
                        }
                    }
                }
            }
        }
        .tint(JournalTheme.accent)
    }

    private var dashboardBackground: some View {
        JournalTheme.canvas.ignoresSafeArea()
    }

    private func hero(isWideLayout: Bool, stats: JournalStatistics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("回看，也是一种记录。")
                        .font(.system(.title2, design: .serif).weight(.medium))

                    Text(stats.insightText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chart.xyaxis.line")
                    .font(.title)
                    .foregroundStyle(JournalTheme.accent)
                    .accessibilityHidden(true)
            }

            LazyVGrid(columns: metricColumns(isWideLayout: isWideLayout), spacing: 10) {
                MetricTile(title: "日记", value: "\(stats.totalEntries)", systemImage: "doc.text", tint: JournalTheme.accent)
                MetricTile(title: "总词数", value: "\(stats.totalWords)", systemImage: "text.word.spacing", tint: JournalTheme.accent)
                MetricTile(title: "最近连续", value: "\(stats.recentStreak) 天", systemImage: "flame", tint: JournalTheme.accent)
                MetricTile(title: "最长连续", value: "\(stats.longestStreak) 天", systemImage: "trophy", tint: JournalTheme.accent)
            }
        }
        .padding(16)
        .journalSurface()
    }

    private func metricColumns(isWideLayout: Bool) -> [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : (isWideLayout ? 4 : 2)
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private func sevenDayTrend(_ stats: JournalStatistics) -> some View {
        StatsSection(title: "最近 7 天", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: 14) {
                metricRowLayout {
                    CompactNumber(title: "本周日记", value: "\(stats.entriesThisWeek)")
                    CompactNumber(title: "本周词数", value: "\(stats.wordsThisWeek)")
                    CompactNumber(title: "篇均词数", value: "\(stats.averageWords)")
                }

                SevenDayBarChart(days: stats.lastSevenDays, maxWords: stats.maxDailyWordCount)
            }
        }
    }

    private func sectionHealth(_ stats: JournalStatistics) -> some View {
        StatsSection(title: "小节结构", systemImage: "number") {
            VStack(alignment: .leading, spacing: 12) {
                metricRowLayout {
                    Text(stats.formattedSectionCoverage)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(JournalTheme.accent)

                    Text("日记已使用 ### 小节")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: stats.sectionCoverage)
                    .tint(JournalTheme.accent)

                metricRowLayout {
                    Label("\(stats.entriesWithSections) 篇有小节", systemImage: "checkmark.circle")
                    Label(String(format: "%.1f 小节/篇", stats.averageSections), systemImage: "list.bullet.rectangle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func categoryBreakdown(_ stats: JournalStatistics) -> some View {
        StatsSection(title: "分类分布", systemImage: "square.grid.2x2") {
            VStack(spacing: 10) {
                ForEach(stats.categoryBreakdown) { item in
                    DistributionRow(
                        title: item.category.rawValue,
                        detail: "\(item.entryCount) 篇 · \(item.wordCount) 词",
                        systemImage: item.category.systemImage,
                        value: item.entryCount,
                        maxValue: stats.maxCategoryEntryCount,
                        tint: item.category.tint
                    )
                }
            }
        }
    }

    private func moodBreakdown(_ stats: JournalStatistics) -> some View {
        StatsSection(title: "心情分布", systemImage: "face.smiling") {
            VStack(spacing: 10) {
                ForEach(stats.moodBreakdown) { item in
                    DistributionRow(
                        title: item.mood.rawValue,
                        detail: "\(item.entryCount) 篇",
                        systemImage: item.mood.systemImage,
                        value: item.entryCount,
                        maxValue: stats.maxMoodEntryCount,
                        tint: JournalTheme.accent
                    )
                }
            }
        }
    }

    private func writingRhythm(_ stats: JournalStatistics) -> some View {
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

    private var metricRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
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
        .journalSurface()
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
                .fixedSize(horizontal: false, vertical: true)
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(JournalTheme.inset, in: RoundedRectangle(cornerRadius: 10))
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

enum SevenDayBarChartLayoutContract {
    static let plotHeight: CGFloat = 92
    static let minimumValueLabelHeight: CGFloat = 14
    static let minimumChartHeight: CGFloat = 134
    static let accessibilityDayMinimumWidth: CGFloat = 56

    static func usesHorizontalScrolling(for dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize
    }
}

private struct SevenDayBarChart: View {
    let days: [JournalStatistics.DailyWriting]
    let maxWords: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if SevenDayBarChartLayoutContract.usesHorizontalScrolling(for: dynamicTypeSize) {
                ScrollView(.horizontal, showsIndicators: false) {
                    dayColumns(dayWidth: SevenDayBarChartLayoutContract.accessibilityDayMinimumWidth)
                }
            } else {
                dayColumns(dayWidth: nil)
            }
        }
        .frame(minHeight: SevenDayBarChartLayoutContract.minimumChartHeight)
    }

    private func dayColumns(dayWidth: CGFloat?) -> some View {
        HStack(alignment: .bottom, spacing: 9) {
            ForEach(days) { day in
                dayColumn(day)
                    .frame(
                        minWidth: dayWidth,
                        maxWidth: dayWidth ?? .infinity
                    )
            }
        }
    }

    private func dayColumn(_ day: JournalStatistics.DailyWriting) -> some View {
        VStack(spacing: 7) {
            Text(day.wordCount == 0 ? "" : "\(day.wordCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minHeight: SevenDayBarChartLayoutContract.minimumValueLabelHeight)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(JournalTheme.inset)
                    .frame(height: SevenDayBarChartLayoutContract.plotHeight)

                RoundedRectangle(cornerRadius: 5)
                    .fill(day.wordCount > 0 ? JournalTheme.accent : Color.secondary.opacity(0.15))
                    .frame(height: barHeight(for: day.wordCount))
            }

            Text(day.date.journalWeekdayText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func barHeight(for words: Int) -> CGFloat {
        guard words > 0 else { return 8 }
        return max(
            12,
            CGFloat(words) / CGFloat(maxWords) * SevenDayBarChartLayoutContract.plotHeight
        )
    }
}

private struct DistributionRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let detail: String
    let systemImage: String
    let value: Int
    let maxValue: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            rowLayout {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(value > 0 ? tint : .secondary)

                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(JournalTheme.inset)

                    Capsule()
                        .fill(value > 0 ? tint : Color.secondary.opacity(0.14))
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 8)
        }
    }

    private var rowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    private var ratio: CGFloat {
        guard maxValue > 0 else { return 0 }
        return max(value == 0 ? 0 : 0.08, CGFloat(value) / CGFloat(maxValue))
    }
}

private struct InsightRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))

        layout {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JournalTheme.accent)
                .frame(width: 28, height: 28)
                .background(JournalTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }

            Text(value)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
