import Foundation

struct JournalStatistics {
    struct CategoryBreakdown: Identifiable {
        let category: JournalEntry.Category
        let entryCount: Int
        let wordCount: Int

        var id: JournalEntry.Category { category }
    }

    struct MoodBreakdown: Identifiable {
        let mood: JournalEntry.Mood
        let entryCount: Int

        var id: JournalEntry.Mood { mood }
    }

    struct DailyWriting: Identifiable {
        let date: Date
        let entryCount: Int
        let wordCount: Int

        var id: Date { date }
    }

    let entries: [JournalEntry]
    let totalEntries: Int
    let totalWords: Int
    let totalSections: Int
    let averageWords: Int
    let averageSections: Double
    let entriesWithSections: Int
    let sectionCoverage: Double
    let recentStreak: Int
    let longestStreak: Int
    let entriesThisWeek: Int
    let wordsThisWeek: Int
    let categoryBreakdown: [CategoryBreakdown]
    let moodBreakdown: [MoodBreakdown]
    let lastSevenDays: [DailyWriting]
    let latestEntryDate: Date?

    init(entries: [JournalEntry], calendar: Calendar = .current, now: Date = Date()) {
        let sortedEntries = entries.sorted { $0.createdAt > $1.createdAt }
        self.entries = sortedEntries

        totalEntries = sortedEntries.count
        totalWords = sortedEntries.reduce(0) { $0 + $1.wordCount }
        totalSections = sortedEntries.reduce(0) { $0 + $1.sectionCount }
        averageWords = totalEntries == 0 ? 0 : totalWords / totalEntries
        averageSections = totalEntries == 0 ? 0 : Double(totalSections) / Double(totalEntries)
        entriesWithSections = sortedEntries.filter { !$0.sections.isEmpty }.count
        sectionCoverage = totalEntries == 0 ? 0 : Double(entriesWithSections) / Double(totalEntries)
        latestEntryDate = sortedEntries.first?.createdAt

        let dayStarts = Set(sortedEntries.map { calendar.startOfDay(for: $0.createdAt) })
        recentStreak = Self.streak(endingAtLatestDayIn: dayStarts, calendar: calendar)
        longestStreak = Self.longestStreak(in: dayStarts, calendar: calendar)

        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let weekEntries = sortedEntries.filter { $0.createdAt >= weekStart }
        entriesThisWeek = weekEntries.count
        wordsThisWeek = weekEntries.reduce(0) { $0 + $1.wordCount }

        categoryBreakdown = JournalEntry.Category.allCases.map { category in
            let matches = sortedEntries.filter { $0.category == category }
            return CategoryBreakdown(
                category: category,
                entryCount: matches.count,
                wordCount: matches.reduce(0) { $0 + $1.wordCount }
            )
        }

        moodBreakdown = JournalEntry.Mood.allCases.map { mood in
            MoodBreakdown(
                mood: mood,
                entryCount: sortedEntries.filter { $0.mood == mood }.count
            )
        }

        let today = calendar.startOfDay(for: now)
        lastSevenDays = (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }

            let matches = sortedEntries.filter {
                calendar.isDate($0.createdAt, inSameDayAs: date)
            }

            return DailyWriting(
                date: date,
                entryCount: matches.count,
                wordCount: matches.reduce(0) { $0 + $1.wordCount }
            )
        }
    }

    var dominantCategory: CategoryBreakdown? {
        categoryBreakdown
            .filter { $0.entryCount > 0 }
            .max { lhs, rhs in
                if lhs.entryCount == rhs.entryCount {
                    return lhs.wordCount < rhs.wordCount
                }

                return lhs.entryCount < rhs.entryCount
            }
    }

    var dominantMood: MoodBreakdown? {
        moodBreakdown
            .filter { $0.entryCount > 0 }
            .max { $0.entryCount < $1.entryCount }
    }

    var insightText: String {
        guard totalEntries > 0 else {
            return "还没有统计数据。写下第一篇日记后，这里会显示趋势和结构。"
        }

        if recentStreak >= 3 {
            return "最近连续记录 \(recentStreak) 天，节奏已经形成。"
        }

        if sectionCoverage < 0.6 {
            return "多数日记还没有用 ### 分小节，可以从“发生了什么 / 感受 / 明天小事”开始。"
        }

        if let dominantCategory {
            return "最近记录最多的是\(dominantCategory.category.rawValue)，可以继续沿这个方向沉淀。"
        }

        return "本周写了 \(entriesThisWeek) 篇，共 \(wordsThisWeek) 词。"
    }

    var formattedSectionCoverage: String {
        "\(Int(sectionCoverage * 100))%"
    }

    private static func streak(endingAtLatestDayIn days: Set<Date>, calendar: Calendar) -> Int {
        guard var cursor = days.max() else { return 0 }
        var count = 0

        while days.contains(cursor) {
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return count
    }

    private static func longestStreak(in days: Set<Date>, calendar: Calendar) -> Int {
        let sortedDays = days.sorted()
        var longest = 0
        var current = 0
        var previousDay: Date?

        for day in sortedDays {
            if let previousDay,
               let expectedDay = calendar.date(byAdding: .day, value: 1, to: previousDay),
               calendar.isDate(day, inSameDayAs: expectedDay) {
                current += 1
            } else {
                current = 1
            }

            longest = max(longest, current)
            previousDay = day
        }

        return longest
    }
}
