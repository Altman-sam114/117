import XCTest
@testable import MDJournal

final class JournalEntryListSnapshotTests: XCTestCase {
    func testDeletionRequestRetainsCompleteTargetAndBuildsAccurateTitle() {
        let entry = JournalEntry(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            title: "  周末计划  ",
            body: "### 行程\n\n去看展览。",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
            category: .travel,
            mood: .happy
        )
        var state = JournalDeletionConfirmationState()

        state.request(entry)

        XCTAssertTrue(state.isPresented)
        XCTAssertEqual(state.target?.id, entry.id)
        XCTAssertEqual(state.target?.title, entry.title)
        XCTAssertEqual(state.target?.body, entry.body)
        XCTAssertEqual(state.target?.category, .travel)
        XCTAssertEqual(
            state.target.map(JournalDeletionConfirmationState.dialogTitle(for:)),
            "删除“周末计划”？"
        )
    }

    func testDeletionDismissClearsTargetAndProducesNoConfirmedEntry() {
        var state = JournalDeletionConfirmationState()
        state.request(makeEntry(title: "待取消", body: "内容", category: .daily, mood: .calm))

        state.dismiss()

        XCTAssertNil(state.target)
        XCTAssertFalse(state.isPresented)
        XCTAssertNil(state.consumeConfirmedTarget())
        state.dismiss()
        XCTAssertNil(state.target)
        XCTAssertFalse(state.isPresented)
    }

    func testDeletionConfirmationConsumesAccurateTargetOnlyOnce() {
        let entry = makeEntry(title: "只删除一次", body: "原始正文", category: .workStudy, mood: .focused)
        var state = JournalDeletionConfirmationState()
        state.request(entry)

        let firstConfirmedTarget = state.consumeConfirmedTarget()

        XCTAssertEqual(firstConfirmedTarget, entry)
        XCTAssertNil(state.target)
        XCTAssertFalse(state.isPresented)
        XCTAssertNil(state.consumeConfirmedTarget())
    }

    func testNewDeletionRequestReplacesOldTargetWithoutFilteredEntryLookup() {
        let firstEntry = makeEntry(title: "第一篇", body: "旧目标", category: .daily, mood: .calm)
        let secondEntry = makeEntry(title: "第二篇", body: "最终目标", category: .inspiration, mood: .happy)
        var filteredEntries = [firstEntry, secondEntry]
        var state = JournalDeletionConfirmationState()

        state.request(filteredEntries[0])
        state.request(filteredEntries[1])
        filteredEntries.removeAll()

        XCTAssertTrue(filteredEntries.isEmpty)
        XCTAssertEqual(
            state.target.map(JournalDeletionConfirmationState.dialogTitle(for:)),
            "删除“第二篇”？"
        )
        XCTAssertEqual(state.consumeConfirmedTarget(), secondEntry)
    }

    func testCategoryFilterChipContractUsesMinimumInteractiveHeight() {
        XCTAssertEqual(CategoryFilterChipContract.minimumInteractiveHeight, 44)
    }

    func testCategoryFilterChipAccessibilityLabelsIncludeTitleAndEntryCount() {
        XCTAssertEqual(
            CategoryFilterChipContract.accessibilityLabel(title: "全部", count: 0),
            "全部，0 篇"
        )
        XCTAssertEqual(
            CategoryFilterChipContract.accessibilityLabel(title: "工作学习", count: 3),
            "工作学习，3 篇"
        )
    }

    func testSelectionPolicyRetainsVisibleSelection() {
        let snapshot = JournalEntryListSnapshot(
            entries: makeEntries(),
            searchText: "draft",
            selectedCategory: nil
        )
        let visibleID = snapshot.filteredEntries[0].id

        XCTAssertEqual(
            JournalEntrySelectionPolicy.repairedSelection(
                currentSelection: visibleID,
                visibleEntries: snapshot.filteredEntries
            ),
            visibleID
        )
    }

    func testSelectionPolicyMovesHiddenSelectionToFirstVisibleEntry() {
        let entries = makeEntries()
        let snapshot = JournalEntryListSnapshot(
            entries: entries,
            searchText: "road",
            selectedCategory: nil
        )

        XCTAssertEqual(snapshot.filteredEntries.map(\.title), ["Gamma"])
        XCTAssertEqual(
            JournalEntrySelectionPolicy.repairedSelection(
                currentSelection: entries[0].id,
                visibleEntries: snapshot.filteredEntries
            ),
            snapshot.filteredEntries.first?.id
        )
        XCTAssertNotEqual(
            JournalEntrySelectionPolicy.repairedSelection(
                currentSelection: entries[0].id,
                visibleEntries: snapshot.filteredEntries
            ),
            entries[0].id
        )
    }

    func testSelectionPolicyReturnsNilForEmptyVisibleEntries() {
        let entries = makeEntries()
        let snapshot = JournalEntryListSnapshot(
            entries: entries,
            searchText: "does not exist",
            selectedCategory: nil
        )
        let selections: [JournalEntry.ID?] = [nil, entries[0].id, UUID()]

        XCTAssertTrue(snapshot.filteredEntries.isEmpty)
        for selection in selections {
            XCTAssertNil(
                JournalEntrySelectionPolicy.repairedSelection(
                    currentSelection: selection,
                    visibleEntries: snapshot.filteredEntries
                )
            )
        }
    }

    func testFilteredDeleteRepairsSelectionToRemainingVisibleEntry() {
        let currentEntry = makeEntry(
            title: "当前日记",
            body: "当前内容",
            category: .daily,
            mood: .calm
        )
        let hiddenEntry = makeEntry(
            title: "隐藏日记",
            body: "隐藏内容",
            category: .inspiration,
            mood: .happy
        )
        let remainingEntry = makeEntry(
            title: "剩余日记",
            body: "剩余内容",
            category: .daily,
            mood: .focused
        )
        let entries = [currentEntry, hiddenEntry, remainingEntry]
        let filteredSnapshot = JournalEntryListSnapshot(
            entries: entries,
            searchText: "",
            selectedCategory: .daily
        )
        let entriesAfterDelete = entries.filter { $0.id != currentEntry.id }
        let snapshotAfterDelete = JournalEntryListSnapshot(
            entries: entriesAfterDelete,
            searchText: "",
            selectedCategory: .daily
        )

        XCTAssertEqual(filteredSnapshot.filteredEntries.map(\.id), [currentEntry.id, remainingEntry.id])
        XCTAssertEqual(snapshotAfterDelete.filteredEntries.map(\.id), [remainingEntry.id])
        XCTAssertEqual(
            JournalEntrySelectionPolicy.repairedSelection(
                currentSelection: currentEntry.id,
                visibleEntries: snapshotAfterDelete.filteredEntries
            ),
            remainingEntry.id
        )
        XCTAssertNotEqual(snapshotAfterDelete.filteredEntries.first?.id, hiddenEntry.id)

        let emptyAfterDeleteSnapshot = JournalEntryListSnapshot(
            entries: [hiddenEntry],
            searchText: "",
            selectedCategory: .daily
        )
        XCTAssertNil(
            JournalEntrySelectionPolicy.repairedSelection(
                currentSelection: currentEntry.id,
                visibleEntries: emptyAfterDeleteSnapshot.filteredEntries
            )
        )
    }

    func testFilteredCreateSelectsMatchingNewEntryOrVisibleFirstWhenHidden() {
        let existingEntry = makeEntry(
            title: "已有日记",
            body: "已有内容",
            category: .daily,
            mood: .calm
        )
        let initialSnapshot = JournalEntryListSnapshot(
            entries: [existingEntry],
            searchText: "",
            selectedCategory: .daily
        )
        let matchingNewEntry = makeEntry(
            title: "新日记",
            body: "新内容",
            category: .daily,
            mood: .focused
        )
        let snapshotAfterMatchingCreate = JournalEntryListSnapshot(
            entries: [matchingNewEntry, existingEntry],
            searchText: "",
            selectedCategory: .daily
        )
        let hiddenNewEntry = makeEntry(
            title: "隐藏的新日记",
            body: "新内容",
            category: .travel,
            mood: .happy
        )
        let snapshotAfterHiddenCreate = JournalEntryListSnapshot(
            entries: [hiddenNewEntry, existingEntry],
            searchText: "",
            selectedCategory: .daily
        )

        XCTAssertEqual(
            JournalEntrySelectionPolicy.repairedSelection(
                currentSelection: existingEntry.id,
                visibleEntries: initialSnapshot.filteredEntries
            ),
            existingEntry.id
        )
        XCTAssertEqual(
            JournalEntrySelectionPolicy.repairedSelection(
                currentSelection: matchingNewEntry.id,
                visibleEntries: snapshotAfterMatchingCreate.filteredEntries
            ),
            matchingNewEntry.id
        )
        XCTAssertEqual(
            JournalEntrySelectionPolicy.repairedSelection(
                currentSelection: hiddenNewEntry.id,
                visibleEntries: snapshotAfterHiddenCreate.filteredEntries
            ),
            existingEntry.id
        )

        let emptyAfterHiddenCreateSnapshot = JournalEntryListSnapshot(
            entries: [hiddenNewEntry],
            searchText: "",
            selectedCategory: .daily
        )
        XCTAssertNil(
            JournalEntrySelectionPolicy.repairedSelection(
                currentSelection: hiddenNewEntry.id,
                visibleEntries: emptyAfterHiddenCreateSnapshot.filteredEntries
            )
        )
    }

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
        XCTAssertFalse(snapshot.isCollectionEmpty)
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
        XCTAssertFalse(snapshot.isCollectionEmpty)
    }

    func testEmptyCategoryFilterDoesNotReportCollectionEmpty() {
        let snapshot = JournalEntryListSnapshot(
            entries: makeEntries(),
            searchText: "",
            selectedCategory: .health
        )

        XCTAssertTrue(snapshot.filteredEntries.isEmpty)
        XCTAssertEqual(snapshot.count(for: .health), 0)
        XCTAssertFalse(snapshot.isCollectionEmpty)
    }

    func testEmptyEntriesReportCollectionEmpty() {
        let snapshot = JournalEntryListSnapshot(entries: [], searchText: "query", selectedCategory: .health)

        XCTAssertTrue(snapshot.filteredEntries.isEmpty)
        XCTAssertEqual(snapshot.totalCount, 0)
        XCTAssertTrue(snapshot.isCollectionEmpty)
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
