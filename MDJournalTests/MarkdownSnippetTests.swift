import XCTest
import SwiftUI
@testable import MDJournal

final class MarkdownSnippetTests: XCTestCase {
    func testAllSnippetsHaveVisibleMetadataAndMarkdown() {
        XCTAssertEqual(MarkdownSnippet.allCases.count, 8)

        for snippet in MarkdownSnippet.allCases {
            XCTAssertFalse(snippet.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(snippet.systemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(snippet.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testSnippetKeyboardShortcutsAreUniqueAndUseSharedModifiers() {
        let shortcuts = MarkdownSnippet.allCases.map(MarkdownSnippetCommandShortcut.init(snippet:))
        let identifiers = Set(shortcuts.map(\.identifier))

        XCTAssertEqual(identifiers.count, MarkdownSnippet.allCases.count)
        XCTAssertFalse(shortcuts.map(\.key).contains("n"), "Command-N is reserved for creating a new journal entry.")

        for shortcut in shortcuts {
            XCTAssertEqual(shortcut.modifiers, [.command, .option])
        }
    }

    func testEditorWritingCommandsHaveVisibleMetadata() {
        XCTAssertEqual(EditorWritingCommand.allCases, [.focusBody, .togglePreview])

        for command in EditorWritingCommand.allCases {
            XCTAssertFalse(command.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(command.systemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testEditorWritingCommandShortcutsDoNotCollideWithSnippetShortcuts() {
        let writingShortcuts = EditorWritingCommand.allCases.map(EditorWritingCommandShortcut.init(command:))
        let writingIdentifiers = Set(writingShortcuts.map(\.identifier))
        let snippetIdentifiers = Set(
            MarkdownSnippet.allCases
                .map(MarkdownSnippetCommandShortcut.init(snippet:))
                .map(\.identifier)
        )

        XCTAssertEqual(writingIdentifiers.count, EditorWritingCommand.allCases.count)
        XCTAssertTrue(writingIdentifiers.isDisjoint(with: snippetIdentifiers))
        XCTAssertFalse(writingShortcuts.map(\.key).contains("n"), "Command-N is reserved for creating a new journal entry.")

        for shortcut in writingShortcuts {
            XCTAssertEqual(shortcut.modifiers, [.command, .option])
        }
    }

    func testSnippetOrderMatchesToolbarAndMenuOrder() {
        XCTAssertEqual(
            MarkdownSnippet.allCases,
            [.heading, .bold, .italic, .quote, .bullet, .checklist, .code, .divider]
        )
    }

    func testKeySnippetMarkdownMatchesCurrentToolbarContract() {
        XCTAssertEqual(MarkdownSnippet.heading.markdown, "### 小节标题\n")
        XCTAssertEqual(MarkdownSnippet.bold.markdown, "**重点**")
        XCTAssertEqual(MarkdownSnippet.italic.markdown, "*想法*")
        XCTAssertEqual(MarkdownSnippet.quote.markdown, "> 记下一句话\n")
        XCTAssertEqual(MarkdownSnippet.bullet.markdown, "- ")
        XCTAssertEqual(MarkdownSnippet.checklist.markdown, "- [ ] ")
        XCTAssertEqual(MarkdownSnippet.code.markdown, "```\n\n```\n")
        XCTAssertEqual(MarkdownSnippet.divider.markdown, "---\n")
    }
}
