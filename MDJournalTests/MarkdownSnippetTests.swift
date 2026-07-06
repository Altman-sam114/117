import XCTest
import SwiftUI
@testable import MDJournal

final class MarkdownSnippetTests: XCTestCase {
    func testAllSnippetsHaveVisibleMetadataAndMarkdown() {
        XCTAssertEqual(MarkdownSnippet.allCases.count, 9)

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
        XCTAssertEqual(EditorWritingCommand.allCases, [.focusBody, .indentLines, .outdentLines, .togglePreview])

        for command in EditorWritingCommand.allCases {
            XCTAssertFalse(command.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(command.systemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testEditorWritingIndentationCommandsExposeDirections() {
        XCTAssertNil(EditorWritingCommand.focusBody.indentationDirection)
        XCTAssertEqual(EditorWritingCommand.indentLines.indentationDirection, .indent)
        XCTAssertEqual(EditorWritingCommand.outdentLines.indentationDirection, .outdent)
        XCTAssertNil(EditorWritingCommand.togglePreview.indentationDirection)
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
        XCTAssertEqual(EditorWritingCommandShortcut(command: .indentLines).key, "]")
        XCTAssertEqual(EditorWritingCommandShortcut(command: .outdentLines).key, "[")

        for shortcut in writingShortcuts {
            XCTAssertEqual(shortcut.modifiers, [.command, .option])
        }
    }

    func testSnippetOrderMatchesToolbarAndMenuOrder() {
        XCTAssertEqual(
            MarkdownSnippet.allCases,
            [.heading, .bold, .italic, .quote, .bullet, .orderedList, .checklist, .code, .divider]
        )
    }

    func testKeySnippetMarkdownMatchesCurrentToolbarContract() {
        XCTAssertEqual(MarkdownSnippet.heading.markdown, "### 小节标题\n")
        XCTAssertEqual(MarkdownSnippet.bold.markdown, "**重点**")
        XCTAssertEqual(MarkdownSnippet.italic.markdown, "*想法*")
        XCTAssertEqual(MarkdownSnippet.quote.markdown, "> 记下一句话\n")
        XCTAssertEqual(MarkdownSnippet.bullet.markdown, "- ")
        XCTAssertEqual(MarkdownSnippet.orderedList.markdown, "1. ")
        XCTAssertEqual(MarkdownSnippet.checklist.markdown, "- [ ] ")
        XCTAssertEqual(MarkdownSnippet.code.markdown, "```\n\n```\n")
        XCTAssertEqual(MarkdownSnippet.divider.markdown, "---\n")
    }

    func testSnippetInsertionUsesCursorRangeInsteadOfAppending() {
        let body = "早上\n晚上"
        let cursor = NSRange(location: "早上\n".utf16.count, length: 0)

        let result = MarkdownSnippetInsertion.apply(
            snippet: .bullet,
            to: body,
            selectedRange: cursor
        )

        XCTAssertEqual(result.body, "早上\n- 晚上")
        XCTAssertEqual(result.selectedRange, NSRange(location: "早上\n- ".utf16.count, length: 0))
    }

    func testSnippetInsertionWrapsSelectedText() {
        let body = "今天很好"
        let selectedRange = (body as NSString).range(of: "很好")

        let result = MarkdownSnippetInsertion.apply(
            snippet: .bold,
            to: body,
            selectedRange: selectedRange
        )

        XCTAssertEqual(result.body, "今天**很好**")
        XCTAssertEqual(result.selectedRange, NSRange(location: "今天**".utf16.count, length: "很好".utf16.count))
    }

    func testSnippetInsertionPrefixesEverySelectedLine() {
        let body = "第一行\n第二行"
        let result = MarkdownSnippetInsertion.apply(
            snippet: .quote,
            to: body,
            selectedRange: NSRange(location: 0, length: body.utf16.count)
        )

        XCTAssertEqual(result.body, "> 第一行\n> 第二行")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: result.body.utf16.count))
    }

    func testSnippetInsertionSkipsBlankLinesWhenPrefixingSelectedLines() {
        let body = "第一行\n\n  \n第二行"

        let quoteResult = MarkdownSnippetInsertion.apply(
            snippet: .quote,
            to: body,
            selectedRange: NSRange(location: 0, length: body.utf16.count)
        )
        XCTAssertEqual(quoteResult.body, "> 第一行\n\n  \n> 第二行")
        XCTAssertEqual(quoteResult.selectedRange, NSRange(location: 0, length: quoteResult.body.utf16.count))

        let bulletResult = MarkdownSnippetInsertion.apply(
            snippet: .bullet,
            to: body,
            selectedRange: NSRange(location: 0, length: body.utf16.count)
        )
        XCTAssertEqual(bulletResult.body, "- 第一行\n\n  \n- 第二行")
        XCTAssertEqual(bulletResult.selectedRange, NSRange(location: 0, length: bulletResult.body.utf16.count))

        let checklistResult = MarkdownSnippetInsertion.apply(
            snippet: .checklist,
            to: body,
            selectedRange: NSRange(location: 0, length: body.utf16.count)
        )
        XCTAssertEqual(checklistResult.body, "- [ ] 第一行\n\n  \n- [ ] 第二行")
        XCTAssertEqual(checklistResult.selectedRange, NSRange(location: 0, length: checklistResult.body.utf16.count))
    }

    func testSnippetInsertionPreservesTrailingNewlineWithoutExtraEmptyBullet() {
        let selectedText = "第一行\n第二行\n"
        let body = "\(selectedText)未选"
        let result = MarkdownSnippetInsertion.apply(
            snippet: .checklist,
            to: body,
            selectedRange: NSRange(location: 0, length: selectedText.utf16.count)
        )

        let expectedReplacement = "- [ ] 第一行\n- [ ] 第二行\n"
        XCTAssertEqual(result.body, "\(expectedReplacement)未选")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: expectedReplacement.utf16.count))
    }

    func testSnippetInsertionPrefixesSelectedLinesWithOrderedNumbers() {
        let body = "第一行\n第二行"
        let result = MarkdownSnippetInsertion.apply(
            snippet: .orderedList,
            to: body,
            selectedRange: NSRange(location: 0, length: body.utf16.count)
        )

        XCTAssertEqual(result.body, "1. 第一行\n2. 第二行")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: result.body.utf16.count))
    }

    func testSnippetInsertionSkipsBlankLinesWhenNumberingSelectedLines() {
        let body = "第一行\n\n  \n第二行"
        let result = MarkdownSnippetInsertion.apply(
            snippet: .orderedList,
            to: body,
            selectedRange: NSRange(location: 0, length: body.utf16.count)
        )

        XCTAssertEqual(result.body, "1. 第一行\n\n  \n2. 第二行")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: result.body.utf16.count))
    }

    func testSnippetInsertionPreservesTrailingNewlineWithoutExtraOrderedItem() {
        let selectedText = "第一行\n第二行\n"
        let body = "\(selectedText)未选"
        let result = MarkdownSnippetInsertion.apply(
            snippet: .orderedList,
            to: body,
            selectedRange: NSRange(location: 0, length: selectedText.utf16.count)
        )

        let expectedReplacement = "1. 第一行\n2. 第二行\n"
        XCTAssertEqual(result.body, "\(expectedReplacement)未选")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: expectedReplacement.utf16.count))
    }

    func testSnippetInsertionLeavesBlankOnlySelectionsUnmarked() {
        let body = "\n  \n"

        for snippet in [
            MarkdownSnippet.quote,
            MarkdownSnippet.bullet,
            MarkdownSnippet.orderedList,
            MarkdownSnippet.checklist
        ] {
            let result = MarkdownSnippetInsertion.apply(
                snippet: snippet,
                to: body,
                selectedRange: NSRange(location: 0, length: body.utf16.count)
            )

            XCTAssertEqual(result.body, body)
            XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: body.utf16.count))
        }
    }

    func testSnippetInsertionWrapsSelectedTextInCodeBlock() {
        let body = "片段"
        let result = MarkdownSnippetInsertion.apply(
            snippet: .code,
            to: body,
            selectedRange: NSRange(location: 0, length: body.utf16.count)
        )

        XCTAssertEqual(result.body, "```\n片段\n```\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: "```\n".utf16.count, length: body.utf16.count))
    }

    func testSnippetInsertionPlacesCursorInsideEmptyCodeBlock() {
        let result = MarkdownSnippetInsertion.apply(
            snippet: .code,
            to: "",
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(result.body, MarkdownSnippet.code.markdown)
        XCTAssertEqual(result.selectedRange, NSRange(location: "```\n".utf16.count, length: 0))
    }

    func testSnippetInsertionHandlesEmojiUTF16Selection() {
        let body = "早安😀今天"
        let selectedRange = (body as NSString).range(of: "😀")

        let result = MarkdownSnippetInsertion.apply(
            snippet: .italic,
            to: body,
            selectedRange: selectedRange
        )

        XCTAssertEqual(result.body, "早安*😀*今天")
        XCTAssertEqual(result.selectedRange, NSRange(location: "早安*".utf16.count, length: "😀".utf16.count))
    }

    func testSnippetInsertionExpandsInvalidUTF16RangeInsideEmoji() {
        let body = "早安😀今天"
        let invalidRange = NSRange(location: "早安".utf16.count + 1, length: 1)

        let result = MarkdownSnippetInsertion.apply(
            snippet: .italic,
            to: body,
            selectedRange: invalidRange
        )

        XCTAssertEqual(result.body, "早安*😀*今天")
        XCTAssertEqual(result.selectedRange, NSRange(location: "早安*".utf16.count, length: "😀".utf16.count))
    }

    func testSnippetInsertionClampsInvalidRangeToEnd() {
        let body = "今天"
        let result = MarkdownSnippetInsertion.apply(
            snippet: .heading,
            to: body,
            selectedRange: NSRange(location: NSNotFound, length: 0)
        )

        XCTAssertEqual(result.body, "今天### 小节标题\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: "今天### ".utf16.count, length: "小节标题".utf16.count))
    }
}
