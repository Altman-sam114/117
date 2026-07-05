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
    let maxCategoryEntryCount: Int
    let maxMoodEntryCount: Int
    let lastSevenDays: [DailyWriting]
    let maxDailyWordCount: Int
    let latestEntryDate: Date?

    private struct EntryAggregate {
        var entryCount = 0
        var wordCount = 0
    }

    init(entries: [JournalEntry], calendar: Calendar = .current, now: Date = Date()) {
        let sortedEntries = entries.sorted { $0.createdAt > $1.createdAt }
        self.entries = sortedEntries

        totalEntries = sortedEntries.count
        latestEntryDate = sortedEntries.first?.createdAt

        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? today

        var totalWordsValue = 0
        var totalSectionsValue = 0
        var entriesWithSectionsValue = 0
        var entriesThisWeekValue = 0
        var wordsThisWeekValue = 0
        var dayStarts = Set<Date>()
        var dayTotals: [Date: EntryAggregate] = [:]
        var categoryTotals: [JournalEntry.Category: EntryAggregate] = [:]
        var moodTotals: [JournalEntry.Mood: Int] = [:]

        for entry in sortedEntries {
            let bodySummary = entry.bodySummary
            let day = calendar.startOfDay(for: entry.createdAt)

            totalWordsValue += bodySummary.wordCount
            totalSectionsValue += bodySummary.sectionCount

            if !bodySummary.sections.isEmpty {
                entriesWithSectionsValue += 1
            }

            dayStarts.insert(day)

            var dayTotal = dayTotals[day] ?? EntryAggregate()
            dayTotal.entryCount += 1
            dayTotal.wordCount += bodySummary.wordCount
            dayTotals[day] = dayTotal

            if entry.createdAt >= weekStart {
                entriesThisWeekValue += 1
                wordsThisWeekValue += bodySummary.wordCount
            }

            var categoryTotal = categoryTotals[entry.category] ?? EntryAggregate()
            categoryTotal.entryCount += 1
            categoryTotal.wordCount += bodySummary.wordCount
            categoryTotals[entry.category] = categoryTotal

            moodTotals[entry.mood, default: 0] += 1
        }

        totalWords = totalWordsValue
        totalSections = totalSectionsValue
        averageWords = totalEntries == 0 ? 0 : totalWords / totalEntries
        averageSections = totalEntries == 0 ? 0 : Double(totalSections) / Double(totalEntries)
        entriesWithSections = entriesWithSectionsValue
        sectionCoverage = totalEntries == 0 ? 0 : Double(entriesWithSections) / Double(totalEntries)

        recentStreak = Self.streak(endingAtLatestDayIn: dayStarts, calendar: calendar)
        longestStreak = Self.longestStreak(in: dayStarts, calendar: calendar)

        entriesThisWeek = entriesThisWeekValue
        wordsThisWeek = wordsThisWeekValue

        let categoryBreakdownValue = JournalEntry.Category.allCases.map { category in
            let total = categoryTotals[category] ?? EntryAggregate()
            return CategoryBreakdown(
                category: category,
                entryCount: total.entryCount,
                wordCount: total.wordCount
            )
        }
        categoryBreakdown = categoryBreakdownValue
        maxCategoryEntryCount = max(categoryBreakdownValue.map(\.entryCount).max() ?? 0, 1)

        let moodBreakdownValue = JournalEntry.Mood.allCases.map { mood in
            MoodBreakdown(
                mood: mood,
                entryCount: moodTotals[mood] ?? 0
            )
        }
        moodBreakdown = moodBreakdownValue
        maxMoodEntryCount = max(moodBreakdownValue.map(\.entryCount).max() ?? 0, 1)

        let lastSevenDaysValue = (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }

            let total = dayTotals[date] ?? EntryAggregate()

            return DailyWriting(
                date: date,
                entryCount: total.entryCount,
                wordCount: total.wordCount
            )
        }
        lastSevenDays = lastSevenDaysValue
        maxDailyWordCount = max(lastSevenDaysValue.map(\.wordCount).max() ?? 0, 1)
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
