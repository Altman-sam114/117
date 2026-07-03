import XCTest
@testable import MDJournal

final class JournalStatisticsTests: XCTestCase {
    func testStatisticsAreDeterministicWithFixedCalendarAndNow() throws {
        let calendar = fixedCalendar()
        let now = try date(year: 2026, month: 7, day: 3, hour: 12, calendar: calendar)
        let todayID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let yesterdayID = try XCTUnwrap(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let tuesdayID = try XCTUnwrap(UUID(uuidString: "55555555-5555-5555-5555-555555555555"))
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
            )
        ]

        let stats = JournalStatistics(entries: entries, calendar: calendar, now: now)

        XCTAssertEqual(stats.entries.map(\.title), ["今天", "昨天", "周二"])
        XCTAssertEqual(stats.totalEntries, 3)
        XCTAssertEqual(stats.totalWords, 14)
        XCTAssertEqual(stats.totalSections, 2)
        XCTAssertEqual(stats.averageWords, 4)
        XCTAssertEqual(stats.averageSections, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(stats.entriesWithSections, 2)
        XCTAssertEqual(stats.sectionCoverage, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(stats.formattedSectionCoverage, "66%")
        XCTAssertEqual(stats.recentStreak, 2)
        XCTAssertEqual(stats.longestStreak, 2)
        XCTAssertEqual(stats.entriesThisWeek, 3)
        XCTAssertEqual(stats.wordsThisWeek, 14)
        XCTAssertEqual(stats.lastSevenDays.map(\.entryCount), [0, 0, 0, 1, 0, 1, 1])
        XCTAssertEqual(stats.lastSevenDays.map(\.wordCount), [0, 0, 0, 2, 0, 5, 7])

        let daily = try XCTUnwrap(stats.categoryBreakdown.first { $0.category == .daily })
        XCTAssertEqual(daily.entryCount, 2)
        XCTAssertEqual(daily.wordCount, 9)

        let workStudy = try XCTUnwrap(stats.categoryBreakdown.first { $0.category == .workStudy })
        XCTAssertEqual(workStudy.entryCount, 1)
        XCTAssertEqual(workStudy.wordCount, 5)

        let happy = try XCTUnwrap(stats.moodBreakdown.first { $0.mood == .happy })
        XCTAssertEqual(happy.entryCount, 2)

        XCTAssertEqual(stats.dominantCategory?.category, .daily)
        XCTAssertEqual(stats.dominantMood?.mood, .happy)
        XCTAssertTrue(stats.insightText.contains("日常"))
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
