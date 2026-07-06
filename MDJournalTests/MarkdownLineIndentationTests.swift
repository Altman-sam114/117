import XCTest
@testable import MDJournal

final class MarkdownLineIndentationTests: XCTestCase {
    func testTabIndentsCurrentCursorLine() throws {
        let body = "今天\n- 第一项"

        let result = try XCTUnwrap(
            MarkdownLineIndentation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                direction: .indent
            )
        )

        XCTAssertEqual(result.body, "今天\n  - 第一项")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testTabIndentsMultipleSelectedLines() throws {
        let body = "第一行\n第二行\n第三行"
        let selectedLength = "第一行\n第二行".utf16.count

        let result = try XCTUnwrap(
            MarkdownLineIndentation.apply(
                to: body,
                selectedRange: NSRange(location: 0, length: selectedLength),
                direction: .indent
            )
        )

        XCTAssertEqual(result.body, "  第一行\n  第二行\n第三行")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: selectedLength + 4))
    }

    func testSelectionEndingAtNextLineStartDoesNotIndentFollowingLine() throws {
        let body = "第一行\n第二行"

        let result = try XCTUnwrap(
            MarkdownLineIndentation.apply(
                to: body,
                selectedRange: NSRange(location: 0, length: "第一行\n".utf16.count),
                direction: .indent
            )
        )

        XCTAssertEqual(result.body, "  第一行\n第二行")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: "  第一行\n".utf16.count))
    }

    func testTabIndentsLineContainingUTF16Emoji() throws {
        let body = "记录😀\n下一行"
        let cursorLocation = "记录😀".utf16.count

        let result = try XCTUnwrap(
            MarkdownLineIndentation.apply(
                to: body,
                selectedRange: cursor(at: cursorLocation),
                direction: .indent
            )
        )

        XCTAssertEqual(result.body, "  记录😀\n下一行")
        XCTAssertEqual(result.selectedRange, cursor(at: cursorLocation + 2))
    }

    func testShiftTabOutdentsTwoLeadingSpaces() throws {
        let body = "  - 子项"

        let result = try XCTUnwrap(
            MarkdownLineIndentation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                direction: .outdent
            )
        )

        XCTAssertEqual(result.body, "- 子项")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testShiftTabOutdentsOneLeadingSpace() throws {
        let body = " - 子项"

        let result = try XCTUnwrap(
            MarkdownLineIndentation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                direction: .outdent
            )
        )

        XCTAssertEqual(result.body, "- 子项")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testShiftTabOutdentsOneLeadingTab() throws {
        let body = "\t- 子项"

        let result = try XCTUnwrap(
            MarkdownLineIndentation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                direction: .outdent
            )
        )

        XCTAssertEqual(result.body, "- 子项")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testShiftTabOutdentsSelectedMixedLines() throws {
        let body = "  第一行\n\t第二行\n第三行"

        let result = try XCTUnwrap(
            MarkdownLineIndentation.apply(
                to: body,
                selectedRange: NSRange(location: 0, length: body.utf16.count),
                direction: .outdent
            )
        )

        XCTAssertEqual(result.body, "第一行\n第二行\n第三行")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: result.body.utf16.count))
    }

    func testShiftTabOutdentsSelectedMixedWhitespaceLines() throws {
        let body = " 第一行\n  第二行\n\t第三行\n第四行"

        let result = try XCTUnwrap(
            MarkdownLineIndentation.apply(
                to: body,
                selectedRange: NSRange(location: 0, length: body.utf16.count),
                direction: .outdent
            )
        )

        XCTAssertEqual(result.body, "第一行\n第二行\n第三行\n第四行")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: result.body.utf16.count))
    }

    func testShiftTabReturnsNilWhenNoSelectedLineCanOutdent() {
        let body = "第一行\n第二行"

        let result = MarkdownLineIndentation.apply(
            to: body,
            selectedRange: NSRange(location: 0, length: body.utf16.count),
            direction: .outdent
        )

        XCTAssertNil(result)
    }

    private func cursor(at location: Int) -> NSRange {
        NSRange(location: location, length: 0)
    }
}
