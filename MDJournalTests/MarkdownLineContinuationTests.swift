import XCTest
@testable import MDJournal

final class MarkdownLineContinuationTests: XCTestCase {
    func testReturnContinuesBulletLine() throws {
        let body = "- 第一项"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "- 第一项\n- ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnContinuesChecklistLine() throws {
        let body = "- [ ] 写完记录"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "- [ ] 写完记录\n- [ ] ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnContinuesCompletedChecklistAsOpenChecklist() throws {
        let body = "- [x] 已完成"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "- [x] 已完成\n- [ ] ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnKeepsIndentedBulletPrefix() throws {
        let body = "  - 子项"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "  - 子项\n  - ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnKeepsIndentedChecklistPrefix() throws {
        let body = "  - [ ] 子任务"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "  - [ ] 子任务\n  - [ ] ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnKeepsIndentedOrderedListPrefix() throws {
        let body = "  12. 子项"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "  12. 子项\n  13. ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnContinuesAsteriskAndPlusBullets() throws {
        let asteriskBody = "* 星号"
        let plusBody = "+ 加号"

        let asteriskResult = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: asteriskBody,
                selectedRange: cursor(at: asteriskBody.utf16.count),
                replacementText: "\n"
            )
        )
        let plusResult = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: plusBody,
                selectedRange: cursor(at: plusBody.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(asteriskResult.body, "* 星号\n* ")
        XCTAssertEqual(plusResult.body, "+ 加号\n+ ")
    }

    func testReturnContinuesOrderedListLine() throws {
        let body = "1. 第一项"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "1. 第一项\n2. ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnContinuesMultiDigitOrderedListLine() throws {
        let body = "9. 第九项"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "9. 第九项\n10. ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnContinuesQuoteLine() throws {
        let body = "> 一句话"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "> 一句话\n> ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnKeepsIndentedQuotePrefix() throws {
        let body = "  > 子句"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "  > 子句\n  > ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnExitsEmptyBulletLine() throws {
        let body = "- 第一项\n- "

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "- 第一项\n")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnExitsBulletLineWithOnlySpacesAndTabsBeforeCursor() throws {
        let body = "- 第一项\n-  \t "

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "- 第一项\n \t ")
        XCTAssertEqual(result.selectedRange, cursor(at: "- 第一项\n".utf16.count))
    }

    func testReturnExitsBulletLineWithOnlySpacesAndTabsAfterCursor() throws {
        let body = "- 第一项\n- \t  "
        let cursorLocation = "- 第一项\n- ".utf16.count

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: cursorLocation),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "- 第一项\n\t  ")
        XCTAssertEqual(result.selectedRange, cursor(at: "- 第一项\n".utf16.count))
    }

    func testReturnExitsEmptyChecklistLine() throws {
        let body = "- [ ] 第一项\n- [ ] "

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "- [ ] 第一项\n")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnExitsEmptyChecklistLineWithOnlyTabContent() throws {
        let body = "- [ ] 第一项\n- [ ] \t"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "- [ ] 第一项\n\t")
        XCTAssertEqual(result.selectedRange, cursor(at: "- [ ] 第一项\n".utf16.count))
    }

    func testReturnExitsEmptyOrderedListLine() throws {
        let body = "1. 第一项\n2. "

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "1. 第一项\n")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnExitsEmptyOrderedListLineWithOnlySpacesAndTabs() throws {
        let body = "1. 第一项\n2. \t "

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "1. 第一项\n\t ")
        XCTAssertEqual(result.selectedRange, cursor(at: "1. 第一项\n".utf16.count))
    }

    func testReturnExitsEmptyQuoteLine() throws {
        let body = "> 第一段\n> "

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "> 第一段\n")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnExitsEmptyQuoteLineWithOnlyTabContent() throws {
        let body = "> 第一段\n> \t"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "> 第一段\n\t")
        XCTAssertEqual(result.selectedRange, cursor(at: "> 第一段\n".utf16.count))
    }

    func testReturnExitsIndentedEmptyQuoteLine() throws {
        let body = "> 第一段\n  > "

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "> 第一段\n")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnSplitsCurrentListLineAtCursor() throws {
        let body = "- 早安世界"
        let cursorLocation = "- 早安".utf16.count

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: cursorLocation),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "- 早安\n- 世界")
        XCTAssertEqual(result.selectedRange, cursor(at: "- 早安\n- ".utf16.count))
    }

    func testReturnSplitsBulletLineWhenTextExistsBeforeWhitespaceSuffix() throws {
        let body = "- 早安 \t"
        let cursorLocation = "- 早安".utf16.count

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: cursorLocation),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "- 早安\n-  \t")
        XCTAssertEqual(result.selectedRange, cursor(at: "- 早安\n- ".utf16.count))
    }

    func testReturnSplitsBulletLineWhenTextExistsAfterWhitespacePrefix() throws {
        let body = "- \t 世界"
        let cursorLocation = "- \t ".utf16.count

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: cursorLocation),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "- \t \n- 世界")
        XCTAssertEqual(result.selectedRange, cursor(at: "- \t \n- ".utf16.count))
    }

    func testReturnSplitsCurrentOrderedListLineAtCursor() throws {
        let body = "3. 早安世界"
        let cursorLocation = "3. 早安".utf16.count

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: cursorLocation),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "3. 早安\n4. 世界")
        XCTAssertEqual(result.selectedRange, cursor(at: "3. 早安\n4. ".utf16.count))
    }

    func testReturnSplitsCurrentQuoteLineAtCursor() throws {
        let body = "> 早安世界"
        let cursorLocation = "> 早安".utf16.count

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: cursorLocation),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "> 早安\n> 世界")
        XCTAssertEqual(result.selectedRange, cursor(at: "> 早安\n> ".utf16.count))
    }

    func testReturnDoesNotContinueInsideFencedCodeBlock() {
        let body = """
        ```
        - code
        """

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: cursor(at: body.utf16.count),
            replacementText: "\n"
        )

        XCTAssertNil(result)
    }

    func testReturnDoesNotContinueQuoteInsideFencedCodeBlock() {
        let body = """
        ```
        > code
        """

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: cursor(at: body.utf16.count),
            replacementText: "\n"
        )

        XCTAssertNil(result)
    }

    func testReturnDoesNotContinueOrderedListInsideFencedCodeBlock() {
        let body = """
        ```
        1. code
        """

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: cursor(at: body.utf16.count),
            replacementText: "\n"
        )

        XCTAssertNil(result)
    }

    func testReturnContinuesAfterClosedFencedCodeBlock() throws {
        let body = """
        ```
        - code
        ```
        - 第一项
        """

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(
            result.body,
            [
                "```",
                "- code",
                "```",
                "- 第一项"
            ].joined(separator: "\n") + "\n- "
        )
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnDoesNotContinueInsideIndentedFencedCodeBlock() {
        let body = """
          ```swift
        - code
        """

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: cursor(at: body.utf16.count),
            replacementText: "\n"
        )

        XCTAssertNil(result)
    }

    func testReturnContinuesAfterNonLeadingFenceText() throws {
        let body = """
        note ```
        - 第一项
        """

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(
            result.body,
            [
                "note ```",
                "- 第一项"
            ].joined(separator: "\n") + "\n- "
        )
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnUsesOddFenceCountToDisableContinuation() {
        let body = """
        ```
        code
        ```
        ```
        - code
        """

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: cursor(at: body.utf16.count),
            replacementText: "\n"
        )

        XCTAssertNil(result)
    }

    func testReturnDoesNotReplaceNonCollapsedSelection() {
        let body = "- 第一项"

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: NSRange(location: 2, length: "第一".utf16.count),
            replacementText: "\n"
        )

        XCTAssertNil(result)
    }

    func testReturnDoesNotReplaceNonCollapsedOrderedListSelection() {
        let body = "1. 第一项"

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: NSRange(location: 3, length: "第一".utf16.count),
            replacementText: "\n"
        )

        XCTAssertNil(result)
    }

    func testReturnDoesNotReplaceNonCollapsedQuoteSelection() {
        let body = "> 第一项"

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: NSRange(location: 2, length: "第一".utf16.count),
            replacementText: "\n"
        )

        XCTAssertNil(result)
    }

    func testReturnKeepsUTF16CursorAfterEmoji() throws {
        let body = "- 早安😀"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "- 早安😀\n- ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnKeepsUTF16CursorAfterEmojiInQuote() throws {
        let body = "> 早安😀"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "> 早安😀\n> ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testReturnKeepsUTF16CursorAfterEmojiInOrderedList() throws {
        let body = "1. 早安😀"

        let result = try XCTUnwrap(
            MarkdownLineContinuation.apply(
                to: body,
                selectedRange: cursor(at: body.utf16.count),
                replacementText: "\n"
            )
        )

        XCTAssertEqual(result.body, "1. 早安😀\n2. ")
        XCTAssertEqual(result.selectedRange, cursor(at: result.body.utf16.count))
    }

    func testRegularTextInputUsesDefaultBehavior() {
        let body = "- 第一项"

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: cursor(at: body.utf16.count),
            replacementText: "新"
        )

        XCTAssertNil(result)
    }

    func testRegularOrderedListTextInputUsesDefaultBehavior() {
        let body = "1. 第一项"

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: cursor(at: body.utf16.count),
            replacementText: "新"
        )

        XCTAssertNil(result)
    }

    func testRegularQuoteTextInputUsesDefaultBehavior() {
        let body = "> 第一项"

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: cursor(at: body.utf16.count),
            replacementText: "新"
        )

        XCTAssertNil(result)
    }

    func testBareOrderedListMarkerUsesDefaultBehavior() {
        let body = "1."

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: cursor(at: body.utf16.count),
            replacementText: "\n"
        )

        XCTAssertNil(result)
    }

    func testOverflowOrderedListNumberUsesDefaultBehavior() {
        let body = "\(Int.max). 第一项"

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: cursor(at: body.utf16.count),
            replacementText: "\n"
        )

        XCTAssertNil(result)
    }

    func testBareQuoteMarkerUsesDefaultBehavior() {
        let body = ">"

        let result = MarkdownLineContinuation.apply(
            to: body,
            selectedRange: cursor(at: body.utf16.count),
            replacementText: "\n"
        )

        XCTAssertNil(result)
    }

    private func cursor(at location: Int) -> NSRange {
        NSRange(location: location, length: 0)
    }
}
