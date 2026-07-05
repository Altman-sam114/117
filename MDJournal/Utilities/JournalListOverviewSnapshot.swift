import Foundation

struct JournalListOverviewSnapshot {
    struct CategorySummary: Equatable {
        let category: JournalEntry.Category
        let entryCount: Int
        let wordCount: Int
    }

    let totalEntries: Int
    let totalWords: Int
    let entriesWithSections: Int
    let sectionCoverage: Double
    let recentStreak: Int
    let entriesThisWeek: Int
    let wordsThisWeek: Int
    let dominantCategory: CategorySummary?

    private struct EntryAggregate {
        var entryCount = 0
        var wordCount = 0
    }

    init(entries: [JournalEntry], calendar: Calendar = .current, now: Date = Date()) {
        totalEntries = entries.count

        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today

        var totalWordsValue = 0
        var entriesWithSectionsValue = 0
        var entriesThisWeekValue = 0
        var wordsThisWeekValue = 0
        var dayStarts = Set<Date>()
        var categoryTotals: [JournalEntry.Category: EntryAggregate] = [:]

        for entry in entries {
            let bodySummary = entry.bodySummary
            let wordCount = bodySummary.wordCount
            let day = calendar.startOfDay(for: entry.createdAt)

            totalWordsValue += wordCount
            if !bodySummary.sections.isEmpty {
                entriesWithSectionsValue += 1
            }

            dayStarts.insert(day)

            if entry.createdAt >= weekStart {
                entriesThisWeekValue += 1
                wordsThisWeekValue += wordCount
            }

            var categoryTotal = categoryTotals[entry.category] ?? EntryAggregate()
            categoryTotal.entryCount += 1
            categoryTotal.wordCount += wordCount
            categoryTotals[entry.category] = categoryTotal
        }

        totalWords = totalWordsValue
        entriesWithSections = entriesWithSectionsValue
        sectionCoverage = totalEntries == 0 ? 0 : Double(entriesWithSectionsValue) / Double(totalEntries)
        recentStreak = Self.streak(endingAtLatestDayIn: dayStarts, calendar: calendar)
        entriesThisWeek = entriesThisWeekValue
        wordsThisWeek = wordsThisWeekValue

        let categorySummaries = JournalEntry.Category.allCases.map { category in
            let total = categoryTotals[category] ?? EntryAggregate()
            return CategorySummary(
                category: category,
                entryCount: total.entryCount,
                wordCount: total.wordCount
            )
        }

        dominantCategory = categorySummaries
            .filter { $0.entryCount > 0 }
            .max { lhs, rhs in
                if lhs.entryCount == rhs.entryCount {
                    return lhs.wordCount < rhs.wordCount
                }

                return lhs.entryCount < rhs.entryCount
            }
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
}
