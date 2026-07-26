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

    func testNavigationCommandMetadataAndShortcuts() {
        XCTAssertEqual(JournalEntryNavigationDirection.allCases, [.newer, .older])
        XCTAssertEqual(JournalEntryNavigationDirection.newer.title, "较新日记")
        XCTAssertEqual(JournalEntryNavigationDirection.older.title, "较早日记")

        let newerShortcut = JournalEntryNavigationShortcut(direction: .newer)
        let olderShortcut = JournalEntryNavigationShortcut(direction: .older)

        XCTAssertEqual(newerShortcut.keyEquivalent, .upArrow)
        XCTAssertEqual(olderShortcut.keyEquivalent, .downArrow)
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

    private var orderedEntries: [JournalEntry] {
        [
            entry(id: newestID, timestamp: 3),
            entry(id: middleID, timestamp: 2),
            entry(id: oldestID, timestamp: 1)
        ]
    }

    private func entry(id: UUID, timestamp: TimeInterval) -> JournalEntry {
        let date = Date(timeIntervalSince1970: timestamp)
        return JournalEntry(
            id: id,
            title: id.uuidString,
            body: "",
            createdAt: date,
            updatedAt: date
        )
    }
}
