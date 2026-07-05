import XCTest
@testable import MDJournal

final class JournalListOverviewSnapshotTests: XCTestCase {
    func testEmptyOverviewMatchesStatistics() throws {
        let calendar = fixedCalendar()
        let now = try date(year: 2026, month: 7, day: 3, hour: 12, calendar: calendar)
        let overview = JournalListOverviewSnapshot(entries: [], calendar: calendar, now: now)
        let stats = JournalStatistics(entries: [], calendar: calendar, now: now)

        XCTAssertEqual(overview.totalEntries, stats.totalEntries)
        XCTAssertEqual(overview.totalWords, stats.totalWords)
        XCTAssertEqual(overview.entriesWithSections, stats.entriesWithSections)
        XCTAssertEqual(overview.sectionCoverage, stats.sectionCoverage)
        XCTAssertEqual(overview.recentStreak, stats.recentStreak)
        XCTAssertEqual(overview.entriesThisWeek, stats.entriesThisWeek)
        XCTAssertEqual(overview.wordsThisWeek, stats.wordsThisWeek)
        XCTAssertNil(overview.dominantCategory)
        XCTAssertEqual(overview.insightText, stats.insightText)
    }

    func testOverviewMatchesStatisticsForListCardFields() throws {
        let calendar = fixedCalendar()
        let now = try date(year: 2026, month: 7, day: 3, hour: 12, calendar: calendar)
        let entries = try makeOverviewEntries(calendar: calendar, now: now)

        let overview = JournalListOverviewSnapshot(entries: entries, calendar: calendar, now: now)
        let stats = JournalStatistics(entries: entries, calendar: calendar, now: now)

        XCTAssertEqual(overview.totalEntries, stats.totalEntries)
        XCTAssertEqual(overview.totalWords, stats.totalWords)
        XCTAssertEqual(overview.entriesWithSections, stats.entriesWithSections)
        XCTAssertEqual(overview.sectionCoverage, stats.sectionCoverage)
        XCTAssertEqual(overview.recentStreak, stats.recentStreak)
        XCTAssertEqual(overview.entriesThisWeek, stats.entriesThisWeek)
        XCTAssertEqual(overview.wordsThisWeek, stats.wordsThisWeek)
        XCTAssertEqual(overview.dominantCategory?.category, stats.dominantCategory?.category)
        XCTAssertEqual(overview.dominantCategory?.entryCount, stats.dominantCategory?.entryCount)
        XCTAssertEqual(overview.dominantCategory?.wordCount, stats.dominantCategory?.wordCount)
        XCTAssertEqual(overview.insightText, stats.insightText)
    }

    func testRecentStreakInsightHasPriority() throws {
        let calendar = fixedCalendar()
        let now = try date(year: 2026, month: 7, day: 3, hour: 12, calendar: calendar)
        let entries = [
            makeEntry(body: "### A\none two", createdAt: try date(year: 2026, month: 7, day: 3, hour: 9, calendar: calendar), category: .daily, now: now),
            makeEntry(body: "### B\nthree four", createdAt: try date(year: 2026, month: 7, day: 2, hour: 9, calendar: calendar), category: .daily, now: now),
            makeEntry(body: "### C\nfive six", createdAt: try date(year: 2026, month: 7, day: 1, hour: 9, calendar: calendar), category: .daily, now: now)
        ]

        let overview = JournalListOverviewSnapshot(entries: entries, calendar: calendar, now: now)

        XCTAssertEqual(overview.recentStreak, 3)
        XCTAssertEqual(overview.insightText, "最近连续记录 3 天，节奏已经形成。")
    }

    func testLowSectionCoverageInsightMatchesStatistics() throws {
        let calendar = fixedCalendar()
        let now = try date(year: 2026, month: 7, day: 3, hour: 12, calendar: calendar)
        let entries = [
            makeEntry(body: "plain words", createdAt: try date(year: 2026, month: 7, day: 3, hour: 9, calendar: calendar), category: .daily, now: now),
            makeEntry(body: "### Section\nmore words", createdAt: try date(year: 2026, month: 7, day: 2, hour: 9, calendar: calendar), category: .daily, now: now)
        ]
        let overview = JournalListOverviewSnapshot(entries: entries, calendar: calendar, now: now)
        let stats = JournalStatistics(entries: entries, calendar: calendar, now: now)

        XCTAssertEqual(overview.sectionCoverage, 0.5)
        XCTAssertEqual(overview.insightText, stats.insightText)
        XCTAssertTrue(overview.insightText.contains("###"))
    }

    func testDominantCategoryUsesWordCountWhenEntryCountsTie() throws {
        let calendar = fixedCalendar()
        let now = try date(year: 2026, month: 7, day: 3, hour: 12, calendar: calendar)
        let entries = [
            makeEntry(body: "### A\none two", createdAt: try date(year: 2026, month: 7, day: 3, hour: 9, calendar: calendar), category: .daily, now: now),
            makeEntry(body: "### B\none two three four", createdAt: try date(year: 2026, month: 7, day: 3, hour: 8, calendar: calendar), category: .workStudy, now: now)
        ]
        let overview = JournalListOverviewSnapshot(entries: entries, calendar: calendar, now: now)
        let stats = JournalStatistics(entries: entries, calendar: calendar, now: now)

        XCTAssertEqual(overview.sectionCoverage, 1)
        XCTAssertEqual(overview.dominantCategory?.category, .workStudy)
        XCTAssertEqual(overview.dominantCategory?.category, stats.dominantCategory?.category)
        XCTAssertEqual(overview.insightText, stats.insightText)
    }

    private func makeOverviewEntries(calendar: Calendar, now: Date) throws -> [JournalEntry] {
        [
            makeEntry(body: "one two three\n### Plan\nfour five", createdAt: try date(year: 2026, month: 7, day: 3, hour: 10, calendar: calendar), category: .daily, mood: .happy, now: now),
            makeEntry(body: "same day", createdAt: try date(year: 2026, month: 7, day: 3, hour: 8, calendar: calendar), category: .daily, mood: .happy, now: now),
            makeEntry(body: "alpha beta\n### Note\nitem", createdAt: try date(year: 2026, month: 7, day: 2, hour: 9, calendar: calendar), category: .workStudy, mood: .happy, now: now),
            makeEntry(body: "solo words", createdAt: try date(year: 2026, month: 6, day: 30, hour: 8, calendar: calendar), category: .daily, mood: .calm, now: now),
            makeEntry(body: "old day words", createdAt: try date(year: 2026, month: 6, day: 28, hour: 8, calendar: calendar), category: .health, mood: .calm, now: now)
        ]
    }

    private func makeEntry(
        body: String,
        createdAt: Date,
        category: JournalEntry.Category,
        mood: JournalEntry.Mood = .calm,
        now: Date
    ) -> JournalEntry {
        JournalEntry(
            id: UUID(),
            title: "测试",
            body: body,
            createdAt: createdAt,
            updatedAt: now,
            category: category,
            mood: mood
        )
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
}
