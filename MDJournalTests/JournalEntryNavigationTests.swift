import XCTest
import SwiftUI
@testable import MDJournal

final class JournalEntryNavigationTests: XCTestCase {
    private let newestID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let middleID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let oldestID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    func testNavigationMovesToNewerAndOlderEntriesUsingCurrentOrder() {
        let entries = orderedEntries

        XCTAssertEqual(
            JournalEntryNavigation.destinationID(in: entries, selection: middleID, direction: .newer),
            newestID
        )
        XCTAssertEqual(
            JournalEntryNavigation.destinationID(in: entries, selection: middleID, direction: .older),
            oldestID
        )
        XCTAssertEqual(
            JournalEntryNavigation.destinationID(in: entries, selection: newestID, direction: .older),
            middleID
        )
        XCTAssertEqual(
            JournalEntryNavigation.destinationID(in: entries, selection: oldestID, direction: .newer),
            middleID
        )
    }

    func testNavigationStopsAtNewestAndOldestEntriesWithoutWrapping() {
        let entries = orderedEntries

        XCTAssertNil(JournalEntryNavigation.destinationID(in: entries, selection: newestID, direction: .newer))
        XCTAssertNil(JournalEntryNavigation.destinationID(in: entries, selection: oldestID, direction: .older))
    }

    func testNavigationReturnsNilForEmptySingleAndInvalidSelections() {
        let invalidID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        let singleEntry = [entry(id: newestID, timestamp: 3)]

        for direction in JournalEntryNavigationDirection.allCases {
            XCTAssertNil(JournalEntryNavigation.destinationID(in: [], selection: nil, direction: direction))
            XCTAssertNil(JournalEntryNavigation.destinationID(in: [], selection: invalidID, direction: direction))
            XCTAssertNil(JournalEntryNavigation.destinationID(in: orderedEntries, selection: nil, direction: direction))
            XCTAssertNil(JournalEntryNavigation.destinationID(in: orderedEntries, selection: invalidID, direction: direction))
            XCTAssertNil(JournalEntryNavigation.destinationID(in: singleEntry, selection: newestID, direction: direction))
        }
    }

    func testNavigationUsesSuppliedOrderWithoutSorting() {
        let reorderedEntries = [
            entry(id: oldestID, timestamp: 1),
            entry(id: newestID, timestamp: 3),
            entry(id: middleID, timestamp: 2)
        ]

        XCTAssertEqual(
            JournalEntryNavigation.destinationID(in: reorderedEntries, selection: newestID, direction: .newer),
            oldestID
        )
        XCTAssertEqual(
            JournalEntryNavigation.destinationID(in: reorderedEntries, selection: newestID, direction: .older),
            middleID
        )
    }

    func testFilteredNavigationUsesVisibleSnapshotOrderWithoutHiddenTargets() {
        let hiddenID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let entries = [
            entry(id: newestID, timestamp: 4, title: "Visible newest"),
            entry(id: hiddenID, timestamp: 3, title: "Hidden"),
            entry(id: middleID, timestamp: 2, title: "Visible middle"),
            entry(id: oldestID, timestamp: 1, title: "Visible oldest")
        ]
        let snapshot = JournalEntryListSnapshot(
            entries: entries,
            searchText: "visible",
            selectedCategory: nil
        )

        XCTAssertEqual(snapshot.filteredEntries.map(\.id), [newestID, middleID, oldestID])
        XCTAssertEqual(
            JournalEntryNavigation.destinationID(
                in: snapshot.filteredEntries,
                selection: middleID,
                direction: .newer
            ),
            newestID
        )
        XCTAssertEqual(
            JournalEntryNavigation.destinationID(
                in: snapshot.filteredEntries,
                selection: middleID,
                direction: .older
            ),
            oldestID
        )
        XCTAssertNil(
            JournalEntryNavigation.destinationID(
                in: snapshot.filteredEntries,
                selection: newestID,
                direction: .newer
            )
        )
        XCTAssertNil(
            JournalEntryNavigation.destinationID(
                in: snapshot.filteredEntries,
                selection: oldestID,
                direction: .older
            )
        )
        XCTAssertNotEqual(
            JournalEntryNavigation.destinationID(
                in: snapshot.filteredEntries,
                selection: newestID,
                direction: .older
            ),
            hiddenID
        )
    }

    func testFilteredSnapshotDrivesSelectionRepairAndNavigationFromOneVisibleOrder() {
        let hiddenID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let entries = [
            entry(id: newestID, timestamp: 4, title: "工作最新", body: "工作记录", category: .daily),
            entry(id: hiddenID, timestamp: 3, title: "旅行记录", body: "工作记录", category: .travel),
            entry(id: middleID, timestamp: 2, title: "工作中间", body: "工作记录", category: .daily),
            entry(id: oldestID, timestamp: 1, title: "工作最早", body: "工作记录", category: .daily)
        ]
        let snapshot = JournalEntryListSnapshot(
            entries: entries,
            searchText: "工作",
            selectedCategory: .daily
        )

        XCTAssertEqual(snapshot.filteredEntries.map(\.id), [newestID, middleID, oldestID])
        XCTAssertEqual(
            JournalEntrySelectionPolicy.repairedSelection(
                currentSelection: middleID,
                visibleEntries: snapshot.filteredEntries
            ),
            middleID
        )
        XCTAssertEqual(
            JournalEntrySelectionPolicy.repairedSelection(
                currentSelection: UUID(uuidString: "00000000-0000-0000-0000-000000000099"),
                visibleEntries: snapshot.filteredEntries
            ),
            newestID
        )
        XCTAssertEqual(
            JournalEntryNavigation.destinationID(
                in: snapshot.filteredEntries,
                selection: middleID,
                direction: .newer
            ),
            newestID
        )
        XCTAssertEqual(
            JournalEntryNavigation.destinationID(
                in: snapshot.filteredEntries,
                selection: middleID,
                direction: .older
            ),
            oldestID
        )
    }

    func testNavigationCommandMetadataAndShortcuts() {
        XCTAssertEqual(JournalEntryNavigationDirection.allCases, [.newer, .older])
        XCTAssertEqual(JournalEntryNavigationDirection.newer.title, "较新日记")
        XCTAssertEqual(JournalEntryNavigationDirection.older.title, "较早日记")

        let newerShortcut = JournalEntryNavigationShortcut(direction: .newer)
        let olderShortcut = JournalEntryNavigationShortcut(direction: .older)

        XCTAssertEqual(newerShortcut.keyEquivalent.character, KeyEquivalent.upArrow.character)
        XCTAssertEqual(olderShortcut.keyEquivalent.character, KeyEquivalent.downArrow.character)
        XCTAssertEqual(newerShortcut.modifiers, [.command, .option])
        XCTAssertEqual(olderShortcut.modifiers, [.command, .option])
        XCTAssertEqual(newerShortcut.displayText, "⌘⌥↑")
        XCTAssertEqual(olderShortcut.displayText, "⌘⌥↓")
        XCTAssertNotEqual(newerShortcut.identifier, olderShortcut.identifier)
        XCTAssertTrue(newerShortcut.identifier.hasSuffix("-upArrow"))
        XCTAssertTrue(olderShortcut.identifier.hasSuffix("-downArrow"))
    }

    func testNavigationShortcutsAreUniqueAcrossJournalWritingAndMarkdownCommands() {
        let navigationIdentifiers = JournalEntryNavigationDirection.allCases
            .map(JournalEntryNavigationShortcut.init(direction:))
            .map(\.identifier)
        let writingIdentifiers = EditorWritingCommand.allCases
            .map(EditorWritingCommandShortcut.init(command:))
            .map(\.identifier)
        let markdownIdentifiers = MarkdownSnippet.allCases
            .map(MarkdownSnippetCommandShortcut.init(snippet:))
            .map(\.identifier)
        let allIdentifiers = navigationIdentifiers + writingIdentifiers + markdownIdentifiers
        let commandNIdentifier = "\(EventModifiers.command.rawValue)-n"

        XCTAssertEqual(Set(navigationIdentifiers).count, navigationIdentifiers.count)
        XCTAssertEqual(Set(writingIdentifiers).count, writingIdentifiers.count)
        XCTAssertEqual(Set(markdownIdentifiers).count, markdownIdentifiers.count)
        XCTAssertEqual(Set(allIdentifiers).count, allIdentifiers.count)
        XCTAssertFalse(allIdentifiers.contains(commandNIdentifier))
    }

    @MainActor
    func testSceneCommandsUseLiveBindingsAndBecomeInactiveAfterTheirViewLeaves() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("entries.json")
        try JournalBackupCodec.encode(orderedEntries).write(to: file)
        let store = JournalStore(storageURL: file)
        let state = NavigationCommandState(selection: middleID, path: [middleID])
        var actions: JournalContentSceneActions? = JournalContentSceneActions()
        weak var weakActions = actions
        let target = JournalContentSceneActions.Target(
            store: store,
            selection: Binding(get: { state.selection }, set: { state.selection = $0 }),
            searchText: Binding(get: { state.search }, set: { state.search = $0 }),
            category: Binding(get: { state.category }, set: { state.category = $0 }),
            compactPath: Binding(get: { state.path }, set: { state.path = $0 }),
            showStatistics: { state.statisticsCount += 1 }
        )
        actions!.updateTarget(target)
        XCTAssertTrue(actions!.canSelect(.newer))
        XCTAssertTrue(actions!.canSelect(.older))
        actions!.select(.newer)
        XCTAssertEqual(state.selection, newestID)
        XCTAssertEqual(state.path, [newestID])
        XCTAssertFalse(actions!.canSelect(.newer))
        XCTAssertTrue(actions!.canSelect(.older))

        state.search = "no-matching-journal"
        actions!.refreshAvailability()
        XCTAssertFalse(actions!.canSelect(.older))
        actions!.select(.older)
        XCTAssertEqual(state.selection, newestID, "Commands must not use a stale visible snapshot")
        state.search = ""
        state.path = []
        actions!.select(.older)
        XCTAssertEqual(state.selection, middleID)
        XCTAssertTrue(state.path.isEmpty, "Adjacent commands must not push a hidden compact detail")

        state.search = "no-matching-journal"
        state.category = .travel
        actions!.createEntry()
        let createdID = try XCTUnwrap(state.selection)
        XCTAssertNotNil(store.entry(with: createdID))
        XCTAssertEqual(store.entries.count, 4)
        XCTAssertEqual(state.path, [createdID])
        XCTAssertEqual(state.search, "")
        XCTAssertNil(state.category)
        actions!.showStatistics()
        XCTAssertEqual(state.statisticsCount, 1)

        actions!.clearTarget()
        XCTAssertEqual(actions!.availability, .init())
        actions!.createEntry()
        actions!.select(.older)
        actions!.showStatistics()
        XCTAssertEqual(store.entries.count, 4)
        XCTAssertEqual(state.selection, createdID)
        XCTAssertEqual(state.statisticsCount, 1)
        actions = nil
        XCTAssertNil(weakActions, "Live bindings must not retain their scene command owner")
        await store.flushPendingSave()
    }

    private var orderedEntries: [JournalEntry] {
        [
            entry(id: newestID, timestamp: 3),
            entry(id: middleID, timestamp: 2),
            entry(id: oldestID, timestamp: 1)
        ]
    }

    private func entry(
        id: UUID,
        timestamp: TimeInterval,
        title: String? = nil,
        body: String = "",
        category: JournalEntry.Category = .daily
    ) -> JournalEntry {
        let date = Date(timeIntervalSince1970: timestamp)
        return JournalEntry(
            id: id,
            title: title ?? id.uuidString,
            body: body,
            createdAt: date,
            updatedAt: date,
            category: category
        )
    }
}

@MainActor
private final class NavigationCommandState {
    var selection: JournalEntry.ID?
    var path: [JournalEntry.ID]
    var search = ""
    var category: JournalEntry.Category?
    var statisticsCount = 0

    init(selection: JournalEntry.ID?, path: [JournalEntry.ID]) {
        self.selection = selection
        self.path = path
    }
}
