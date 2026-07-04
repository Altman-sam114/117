import XCTest
@testable import MDJournal

final class JournalEntryListSnapshotTests: XCTestCase {
    func testBlankSearchReturnsAllEntriesAndCountsCategories() {
        let entries = makeEntries()

        let snapshot = JournalEntryListSnapshot(entries: entries, searchText: " \n ", selectedCategory: nil)

        XCTAssertEqual(snapshot.filteredEntries.map(\.title), ["Alpha", "Beta", "Gamma", "Delta"])
        XCTAssertEqual(snapshot.totalCount, 4)
        XCTAssertEqual(snapshot.count(for: .daily), 1)
        XCTAssertEqual(snapshot.count(for: .workStudy), 1)
        XCTAssertEqual(snapshot.count(for: .inspiration), 1)
        XCTAssertEqual(snapshot.count(for: .travel), 1)
        XCTAssertEqual(snapshot.count(for: .health), 0)
        XCTAssertEqual(snapshot.sectionTitle, "最近记录 · 4 篇")
    }

    func testSearchMatchesTitleBodyCategoryAndMood() {
        let entries = makeEntries()

        XCTAssertEqual(snapshot(entries, searchText: "alpha").filteredEntries.map(\.title), ["Alpha"])
        XCTAssertEqual(snapshot(entries, searchText: "ALPHA").filteredEntries.map(\.title), ["Alpha"])
        XCTAssertEqual(snapshot(entries, searchText: "road").filteredEntries.map(\.title), ["Gamma"])
        XCTAssertEqual(snapshot(entries, searchText: "灵感").filteredEntries.map(\.title), ["Beta"])
        XCTAssertEqual(snapshot(entries, searchText: "疲惫").filteredEntries.map(\.title), ["Delta"])
    }

    func testSearchTrimsWhitespaceAndUsesDisplayTitleFallback() {
        let fallbackEntry = makeEntry(
            title: " \n ",
            body: "plain note",
            createdAt: Date(timeIntervalSince1970: 0),
            category: .daily,
            mood: .calm
        )

        let snapshot = JournalEntryListSnapshot(
            entries: [fallbackEntry],
            searchText: " 1970 ",
            selectedCategory: nil
        )

        XCTAssertEqual(snapshot.searchQuery, "1970")
        XCTAssertEqual(snapshot.filteredEntries.map(\.id), [fallbackEntry.id])
        XCTAssertEqual(snapshot.sectionTitle, "最近记录 · 1 篇")
    }

    func testSelectedCategoryFiltersBeforeSearch() {
        let entries = makeEntries()

        let snapshot = JournalEntryListSnapshot(
            entries: entries,
            searchText: "road",
            selectedCategory: .workStudy
        )

        XCTAssertTrue(snapshot.filteredEntries.isEmpty)
        XCTAssertEqual(snapshot.sectionTitle, "工作学习 · 0 篇")
    }

    func testCategoryCountsIgnoreSearchText() {
        let entries = makeEntries()

        let snapshot = JournalEntryListSnapshot(entries: entries, searchText: "alpha", selectedCategory: nil)

        XCTAssertEqual(snapshot.filteredEntries.map(\.title), ["Alpha"])
        XCTAssertEqual(snapshot.count(for: .daily), 1)
        XCTAssertEqual(snapshot.count(for: .workStudy), 1)
        XCTAssertEqual(snapshot.count(for: .inspiration), 1)
        XCTAssertEqual(snapshot.count(for: .travel), 1)
    }

    func testCategoryCountsIgnoreSelectedCategory() {
        let entries = makeEntries()

        let snapshot = JournalEntryListSnapshot(
            entries: entries,
            searchText: "",
            selectedCategory: .daily
        )

        XCTAssertEqual(snapshot.filteredEntries.map(\.title), ["Alpha"])
        XCTAssertEqual(snapshot.count(for: .daily), 1)
        XCTAssertEqual(snapshot.count(for: .workStudy), 1)
        XCTAssertEqual(snapshot.count(for: .inspiration), 1)
        XCTAssertEqual(snapshot.count(for: .travel), 1)
        XCTAssertEqual(snapshot.sectionTitle, "日常 · 1 篇")
    }

    private func snapshot(_ entries: [JournalEntry], searchText: String) -> JournalEntryListSnapshot {
        JournalEntryListSnapshot(entries: entries, searchText: searchText, selectedCategory: nil)
    }

    private func makeEntries() -> [JournalEntry] {
        [
            makeEntry(title: "Alpha", body: "plain note", category: .daily, mood: .calm),
            makeEntry(title: "Beta", body: "draft idea", category: .inspiration, mood: .happy),
            makeEntry(title: "Gamma", body: "road map", category: .travel, mood: .focused),
            makeEntry(title: "Delta", body: "late work", category: .workStudy, mood: .tired)
        ]
    }

    private func makeEntry(
        title: String,
        body: String,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        category: JournalEntry.Category,
        mood: JournalEntry.Mood
    ) -> JournalEntry {
        JournalEntry(
            id: UUID(),
            title: title,
            body: body,
            createdAt: createdAt,
            updatedAt: createdAt,
            category: category,
            mood: mood
        )
    }
}
