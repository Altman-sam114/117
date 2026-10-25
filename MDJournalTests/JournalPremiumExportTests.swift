import PDFKit
import XCTest
@testable import MDJournal

final class JournalPremiumExportTests: XCTestCase {
    func testDateAndCategorySelectionIncludesBothDaysAcrossDaylightSaving() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let formatter = ISO8601DateFormatter()
        let first = try XCTUnwrap(formatter.date(from: "2026-03-08T08:00:00Z"))
        let last = try XCTUnwrap(formatter.date(from: "2026-03-09T06:59:59Z"))
        let outside = try XCTUnwrap(formatter.date(from: "2026-03-09T07:00:00Z"))
        let entries = [entry("首", date: first), entry("末", date: last), entry("外", date: outside), entry("分类外", date: first, category: .travel)]
        let selection = JournalPremiumExportSelection(startDate: first, endDate: first, category: .daily)
        XCTAssertEqual(selection.entries(from: entries, calendar: calendar).map(\.title), ["首", "末"])
    }

    func testUnfilteredExportSortsWithoutMutatingEntriesOrBodies() {
        let early = entry("早", date: Date(timeIntervalSince1970: 100))
        let late = entry("晚", date: Date(timeIntervalSince1970: 200))
        let source = [late, early]
        let selected = JournalPremiumExportSelection().entries(from: source)
        XCTAssertEqual(selected.map(\.id), [early.id, late.id])
        XCTAssertEqual(source, [late, early])
        XCTAssertEqual(selected[0].body, early.body)
    }

    func testMarkdownExportPreservesUnicodeLineEndingsAndLiteralMarkdown() {
        let original = "### 今天\r\n**原文** 👨‍👩‍👧‍👦 e\u{301}\n- [ ] 不改写\n```swift\nlet x = 1\n```"
        let record = JournalEntry(title: "日记", body: original, category: .inspiration, mood: .focused)
        let output = JournalPremiumExportBuilder.markdown(entries: [record])
        XCTAssertTrue(output.contains(original))
        XCTAssertTrue(output.hasPrefix("# 日记\n\n"))
        XCTAssertTrue(output.contains("灵感 · 专注"))
        XCTAssertEqual(record.body, original)
    }

    func testBuilderRejectsEmptySelectionAndProducesUTF8Markdown() async throws {
        let builder = JournalPremiumExportBuilder()
        do {
            _ = try await builder.build(entries: [], format: .markdown)
            XCTFail("Empty exports must be rejected")
        } catch JournalPremiumExportError.emptySelection {
        }
        var record = entry("中文", date: Date(timeIntervalSince1970: 100))
        record.body = String(repeating: "a", count: 65_535) + "👨‍👩‍👧‍👦\r\n"
            + String(repeating: "### 完整正文\n末尾保留 e\u{301}\n", count: 4000)
        let data = try await builder.build(entries: [record], format: .markdown)
        XCTAssertEqual(String(data: data, encoding: .utf8), JournalPremiumExportBuilder.markdown(entries: [record]))
    }

    @MainActor
    func testCancelledBuilderNeverReturnsPartialOutput() async throws {
        let record = entry("取消导出", date: Date(timeIntervalSince1970: 100))
        for format in JournalPremiumExportFormat.allCases {
            let task = Task { try await JournalPremiumExportBuilder().build(entries: [record], format: format) }
            task.cancel()
            do {
                _ = try await task.value
                XCTFail("A cancelled \(format) export must not return a partial file")
            } catch is CancellationError {
            }
        }
    }

    func testPDFPaginatesLongChineseBodyAndRetainsLastLine() async throws {
        let body = (1...180).map { "第\($0)行：把普通的一天慢慢写下来，保留每一个细节。" }.joined(separator: "\n")
            + "\nFINAL_EXPORT_MARKER"
        let record = JournalEntry(title: "长篇日记", body: body)
        let final = JournalEntry(
            title: "下一篇日记", body: String(repeating: "接着记录新的片段。\n", count: 120) + "LAST_ENTRY_EXPORT_MARKER"
        )
        let data = try await JournalPremiumExportBuilder().build(entries: [record, final], format: .pdf)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(document.pageCount, 1)
        XCTAssertTrue(document.string?.contains("长篇日记") == true)
        XCTAssertTrue(document.string?.contains("FINAL_EXPORT_MARKER") == true)
        XCTAssertTrue(document.string?.contains("下一篇日记") == true)
        XCTAssertTrue(document.page(at: document.pageCount - 1)?.string?.contains("LAST_ENTRY_EXPORT_MARKER") == true)
        XCTAssertEqual(record.body, body)
        XCTAssertTrue((0..<document.pageCount).allSatisfy { document.page(at: $0)?.bounds(for: .mediaBox).size == CGSize(width: 595, height: 842) })
    }

    private func entry(_ title: String, date: Date, category: JournalEntry.Category = .daily) -> JournalEntry {
        JournalEntry(title: title, body: "### 今天\n原文 \(title)", createdAt: date, category: category)
    }
}
