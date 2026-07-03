import XCTest
@testable import MDJournal

final class JournalEntryTests: XCTestCase {
    func testDecodesLegacyEntryMissingUpdatedAtCategoryAndMood() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "title": "旧日记",
          "body": "legacy body",
          "createdAt": "2026-01-02T12:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try XCTUnwrap(json.data(using: .utf8))
        let entry = try decoder.decode(JournalEntry.self, from: data)
        let expectedID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let expectedDate = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-02T12:00:00Z"))

        XCTAssertEqual(entry.id, expectedID)
        XCTAssertEqual(entry.title, "旧日记")
        XCTAssertEqual(entry.body, "legacy body")
        XCTAssertEqual(entry.createdAt, expectedDate)
        XCTAssertEqual(entry.updatedAt, expectedDate)
        XCTAssertEqual(entry.category, .daily)
        XCTAssertEqual(entry.mood, .calm)
    }

    func testDisplayTitleFallsBackToCreatedDateWhenTitleIsBlank() throws {
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-04T12:00:00Z"))
        let entryID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let entry = JournalEntry(
            id: entryID,
            title: " \n ",
            body: "正文",
            createdAt: createdAt,
            updatedAt: createdAt
        )

        XCTAssertEqual(entry.displayTitle, createdAt.journalTitleText)
    }

    func testStarterEntryContainsDefaultLevelThreeSections() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-06T12:00:00Z"))
        let entry = JournalEntry.starterEntry(now: now)

        XCTAssertEqual(entry.createdAt, now)
        XCTAssertEqual(entry.updatedAt, now)
        XCTAssertTrue(entry.body.contains("### 今天发生了什么"))
        XCTAssertTrue(entry.body.contains("### 我的感受"))
        XCTAssertTrue(entry.body.contains("### 明天可以做的小事"))
        XCTAssertEqual(entry.sections.map(\.title), ["今天发生了什么", "我的感受", "明天可以做的小事"])
    }

    func testJournalSectionExtractsOnlyLevelThreeSectionsAndCleansExcerpt() {
        let markdown = [
            "###没有空格不识别",
            "## 二级标题不识别",
            "### 第一节",
            "- [ ] **完成** `记录`",
            "> 引用",
            "#### 四级标题不是新小节",
            "内容",
            "### ",
            "- [x] "
        ].joined(separator: "\n")

        let sections = JournalSection.extract(from: markdown)

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections.map(\.title), ["第一节", "未命名小节"])
        XCTAssertTrue(sections[0].markdown.contains("#### 四级标题不是新小节"))
        XCTAssertTrue(sections[0].excerpt.contains("完成"))
        XCTAssertTrue(sections[0].excerpt.contains("记录"))
        XCTAssertTrue(sections[0].excerpt.contains("引用"))
        XCTAssertFalse(sections[0].excerpt.contains("[ ]"))
        XCTAssertFalse(sections[0].excerpt.contains("**"))
        XCTAssertFalse(sections[0].excerpt.contains("`"))
        XCTAssertEqual(sections[1].excerpt, "还没有内容")
    }
}
