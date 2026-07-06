import XCTest
@testable import MDJournal

final class JournalStatisticsTests: XCTestCase {
    func testEmptyStatisticsUseZeroValues() throws {
        let calendar = fixedCalendar()
        let now = try date(year: 2026, month: 7, day: 3, hour: 12, calendar: calendar)

        let stats = JournalStatistics(entries: [], calendar: calendar, now: now)

        XCTAssertTrue(stats.entries.isEmpty)
        XCTAssertEqual(stats.totalEntries, 0)
        XCTAssertEqual(stats.totalWords, 0)
        XCTAssertEqual(stats.totalSections, 0)
        XCTAssertEqual(stats.entriesWithSections, 0)
        XCTAssertEqual(stats.sectionCoverage, 0)
        XCTAssertEqual(stats.recentStreak, 0)
        XCTAssertEqual(stats.longestStreak, 0)
        XCTAssertEqual(stats.entriesThisWeek, 0)
        XCTAssertEqual(stats.wordsThisWeek, 0)
        XCTAssertEqual(stats.maxCategoryEntryCount, 1)
        XCTAssertEqual(stats.maxMoodEntryCount, 1)
        XCTAssertEqual(stats.maxDailyWordCount, 1)
        XCTAssertEqual(stats.lastSevenDays.map(\.entryCount), Array(repeating: 0, count: 7))
        XCTAssertNil(stats.latestEntryDate)
        XCTAssertNil(stats.dominantCategory)
        XCTAssertNil(stats.dominantMood)
    }

    func testStatisticsAreDeterministicWithFixedCalendarAndNow() throws {
        let calendar = fixedCalendar()
        let now = try date(year: 2026, month: 7, day: 3, hour: 12, calendar: calendar)
        let todayID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let sameDayID = try XCTUnwrap(UUID(uuidString: "66666666-6666-6666-6666-666666666666"))
        let yesterdayID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let tuesdayID = try XCTUnwrap(UUID(uuidString: "55555555-5555-5555-5555-555555555555"))
        let previousWeekID = try XCTUnwrap(UUID(uuidString: "77777777-7777-7777-7777-777777777777"))
        let entries = [
            JournalEntry(
                id: todayID,
                title: "今天",
                body: "one two three\n### Plan\nfour five",
                createdAt: try date(year: 2026, month: 7, day: 3, hour: 10, calendar: calendar),
                updatedAt: now,
                category: .daily,
                mood: .happy
            ),
            JournalEntry(
                id: sameDayID,
                title: "同一天",
                body: "same day",
                createdAt: try date(year: 2026, month: 7, day: 3, hour: 8, calendar: calendar),
                updatedAt: now,
                category: .daily,
                mood: .happy
            ),
            JournalEntry(
                id: yesterdayID,
                title: "昨天",
                body: "alpha beta\n### Note\nitem",
                createdAt: try date(year: 2026, month: 7, day: 2, hour: 9, calendar: calendar),
                updatedAt: now,
                category: .workStudy,
                mood: .happy
            ),
            JournalEntry(
                id: tuesdayID,
                title: "周二",
                body: "solo words",
                createdAt: try date(year: 2026, month: 6, day: 30, hour: 8, calendar: calendar),
                updatedAt: now,
                category: .daily,
                mood: .calm
            ),
            JournalEntry(
                id: previousWeekID,
                title: "上周日",
                body: "old day words",
                createdAt: try date(year: 2026, month: 6, day: 28, hour: 8, calendar: calendar),
                updatedAt: now,
                category: .health,
                mood: .calm
            )
        ]

        let stats = JournalStatistics(entries: entries, calendar: calendar, now: now)

        XCTAssertEqual(stats.entries.map(\.title), ["今天", "同一天", "昨天", "周二", "上周日"])
        XCTAssertEqual(stats.totalEntries, 5)
        XCTAssertEqual(stats.totalWords, 19)
        XCTAssertEqual(stats.totalSections, 2)
        XCTAssertEqual(stats.averageWords, 3)
        XCTAssertEqual(stats.averageSections, 2.0 / 5.0, accuracy: 0.0001)
        XCTAssertEqual(stats.entriesWithSections, 2)
        XCTAssertEqual(stats.sectionCoverage, 2.0 / 5.0, accuracy: 0.0001)
        XCTAssertEqual(stats.formattedSectionCoverage, "40%")
        XCTAssertEqual(stats.recentStreak, 2)
        XCTAssertEqual(stats.longestStreak, 2)
        XCTAssertEqual(stats.entriesThisWeek, 4)
        XCTAssertEqual(stats.wordsThisWeek, 16)
        XCTAssertEqual(stats.lastSevenDays.map(\.entryCount), [0, 1, 0, 1, 0, 1, 2])
        XCTAssertEqual(stats.lastSevenDays.map(\.wordCount), [0, 3, 0, 2, 0, 5, 9])
        XCTAssertEqual(stats.maxDailyWordCount, 9)

        let daily = try XCTUnwrap(stats.categoryBreakdown.first { $0.category == .daily })
        XCTAssertEqual(daily.entryCount, 3)
        XCTAssertEqual(daily.wordCount, 11)

        let workStudy = try XCTUnwrap(stats.categoryBreakdown.first { $0.category == .workStudy })
        XCTAssertEqual(workStudy.entryCount, 1)
        XCTAssertEqual(workStudy.wordCount, 5)

        let health = try XCTUnwrap(stats.categoryBreakdown.first { $0.category == .health })
        XCTAssertEqual(health.entryCount, 1)
        XCTAssertEqual(health.wordCount, 3)

        let happy = try XCTUnwrap(stats.moodBreakdown.first { $0.mood == .happy })
        XCTAssertEqual(happy.entryCount, 3)

        XCTAssertEqual(stats.maxCategoryEntryCount, 3)
        XCTAssertEqual(stats.maxMoodEntryCount, 3)
        XCTAssertEqual(stats.dominantCategory?.category, .daily)
        XCTAssertEqual(stats.dominantMood?.mood, .happy)
        XCTAssertTrue(stats.insightText.contains("###"))
    }

    func testDominantCategoryUsesWordCountTieBreak() throws {
        let calendar = fixedCalendar()
        let now = try date(year: 2026, month: 7, day: 3, hour: 12, calendar: calendar)
        let entries = [
            makeEntry(
                title: "日常",
                body: "one two",
                category: .daily,
                mood: .calm,
                day: 3,
                calendar: calendar,
                now: now
            ),
            makeEntry(
                title: "工作学习",
                body: "one two three four",
                category: .workStudy,
                mood: .happy,
                day: 2,
                calendar: calendar,
                now: now
            )
        ]

        let stats = JournalStatistics(entries: entries, calendar: calendar, now: now)

        XCTAssertEqual(stats.dominantCategory?.category, .workStudy)
        XCTAssertEqual(stats.dominantCategory?.wordCount, 4)
    }

    func testDominantCategoryKeepsAllCasesOrderWhenCountsAndWordsTie() throws {
        let calendar = fixedCalendar()
        let now = try date(year: 2026, month: 7, day: 3, hour: 12, calendar: calendar)
        let entries = [
            makeEntry(
                title: "健康",
                body: "one two",
                category: .health,
                mood: .calm,
                day: 3,
                calendar: calendar,
                now: now
            ),
            makeEntry(
                title: "日常",
                body: "one two",
                category: .daily,
                mood: .happy,
                day: 2,
                calendar: calendar,
                now: now
            )
        ]

        let stats = JournalStatistics(entries: entries, calendar: calendar, now: now)

        XCTAssertEqual(stats.dominantCategory?.category, .daily)
    }

    func testDominantMoodKeepsAllCasesOrderWhenCountsTie() throws {
        let calendar = fixedCalendar()
        let now = try date(year: 2026, month: 7, day: 3, hour: 12, calendar: calendar)
        let entries = [
            makeEntry(
                title: "开心",
                body: "one two three",
                category: .daily,
                mood: .happy,
                day: 3,
                calendar: calendar,
                now: now
            ),
            makeEntry(
                title: "平静",
                body: "one two",
                category: .workStudy,
                mood: .calm,
                day: 2,
                calendar: calendar,
                now: now
            )
        ]

        let stats = JournalStatistics(entries: entries, calendar: calendar, now: now)

        XCTAssertEqual(stats.dominantMood?.mood, .calm)
    }

    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, calendar: Calendar) throws -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return try XCTUnwrap(calendar.date(from: components))
    }

    private func makeEntry(
        title: String,
        body: String,
        category: JournalEntry.Category,
        mood: JournalEntry.Mood,
        day: Int,
        calendar: Calendar,
        now: Date
    ) throws -> JournalEntry {
        JournalEntry(
            title: title,
            body: body,
            createdAt: try date(year: 2026, month: 7, day: day, hour: 8, calendar: calendar),
            updatedAt: now,
            category: category,
            mood: mood
        )
    }
}
