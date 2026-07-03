import XCTest
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

    func testKeySnippetMarkdownMatchesCurrentToolbarContract() {
        XCTAssertEqual(MarkdownSnippet.heading.markdown, "### 小节标题\n")
        XCTAssertEqual(MarkdownSnippet.bold.markdown, "**重点**")
        XCTAssertEqual(MarkdownSnippet.checklist.markdown, "- [ ] ")
        XCTAssertEqual(MarkdownSnippet.code.markdown, "```\n\n```\n")
        XCTAssertEqual(MarkdownSnippet.divider.markdown, "---\n")
    }
}
