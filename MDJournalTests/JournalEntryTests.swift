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

    func testBodySummaryMatchesCurrentDerivedTextMetricsAndSections() {
        let body = [
            "alpha beta",
            "### Plan",
            "four five"
        ].joined(separator: "\n")

        let summary = JournalEntryBodySummary(body: body)
        let metrics = JournalEntryBodyMetrics(body: body)

        XCTAssertEqual(summary.excerpt, "alpha beta  Plan four five")
        XCTAssertEqual(summary.wordCount, 6)
        XCTAssertEqual(summary.sectionCount, 1)
        XCTAssertEqual(summary.sections.map(\.title), ["Plan"])
        XCTAssertEqual(summary.sections.first?.markdown, "four five")
        XCTAssertEqual(metrics.wordCount, 6)
        XCTAssertEqual(metrics.sectionCount, 1)
        XCTAssertEqual(metrics.sections.map(\.title), ["Plan"])
        XCTAssertEqual(metrics.sections.first?.markdown, "four five")
        XCTAssertEqual(summary.metrics, metrics)
    }

    func testBodyMetricsCountsWordsWithoutAllocatingSplitSegments() {
        let cases: [(body: String, count: Int)] = [
            ("", 0),
            ("   \n\t  ", 0),
            (" alpha  beta\n\n gamma\t delta ", 4),
            ("中文 English\n混排", 3),
            ("### 标题\n- [ ] 任务", 6),
            ("\r\nalpha\r\nbeta\r", 2),
            ("a\u{00A0}b\u{3000}c", 3),
            ("  one  ", 1),
            ("one\n", 1),
            ("\tone", 1)
        ]

        for testCase in cases {
            XCTAssertEqual(
                JournalEntryBodyMetrics.wordCount(in: testCase.body),
                testCase.count,
                "Unexpected word count for body: \(testCase.body.debugDescription)"
            )
            XCTAssertEqual(
                JournalEntryBodyMetrics(body: testCase.body).wordCount,
                testCase.count,
                "Unexpected metrics word count for body: \(testCase.body.debugDescription)"
            )
        }
    }

    func testBodyMetricsReportsVisibleContentUsingCharacterWhitespaceSemantics() {
        let cases: [(name: String, body: String)] = [
            ("empty", ""),
            ("ASCII whitespace", " \t\n\r"),
            ("Foundation newlines", "\r\n\u{000B}\u{000C}\u{0085}\u{2028}\u{2029}"),
            ("Unicode whitespace", "\u{00A0}\u{2003}\u{3000}"),
            ("punctuation", "!?.,;:"),
            ("emoji", "😀"),
            ("standalone combining mark", "\u{301}"),
            ("composed character", "e\u{301}"),
            ("Markdown marker", "### "),
            ("ordinary body", "中文 English\n普通正文"),
            ("long body", String(repeating: "长正文 e\u{301}\n", count: 128))
        ]

        for testCase in cases {
            XCTAssertEqual(
                JournalEntryBodyMetrics(body: testCase.body).hasVisibleContent,
                testCase.body.contains { !$0.isWhitespace },
                "Unexpected visible-content result for \(testCase.name)"
            )
        }
    }

    func testBodyMetricsPreservesWordAndSectionResultsInSharedScan() {
        let cases: [
            (
                name: String,
                body: String,
                wordCount: Int,
                titles: [String],
                markdown: [String],
                excerpts: [String]
            )
        ] = [
            (
                "plain body without sections",
                "中文 English\r\n混排 😀",
                4,
                [],
                [],
                []
            ),
            (
                "mixed Foundation newlines and composed characters",
                "导言\r\n### 第一节\u{000B}内容 😀\u{000C}### 第二节\u{0085}e\u{301} 结束\u{2028}",
                9,
                ["第一节", "第二节"],
                ["内容 😀", "e\u{301} 结束"],
                ["内容 😀", "e\u{301} 结束"]
            ),
            (
                "empty title invalid marker and fenced code",
                "前言\n###无效\n \t### \n\u{0060}\u{0060}\u{0060}\n### 代码\n正文\n\u{0060}\u{0060}\u{0060}",
                8,
                ["未命名小节", "代码"],
                ["\u{0060}\u{0060}\u{0060}", "正文\n\u{0060}\u{0060}\u{0060}"],
                ["还没有内容", "正文"]
            )
        ]

        for testCase in cases {
            let metrics = JournalEntryBodyMetrics(body: testCase.body)

            XCTAssertEqual(metrics.wordCount, testCase.wordCount, "Unexpected word count for \(testCase.name)")
            XCTAssertEqual(metrics.sectionCount, testCase.titles.count, "Unexpected section count for \(testCase.name)")
            XCTAssertEqual(metrics.sections.map(\.order), Array(testCase.titles.indices))
            XCTAssertEqual(metrics.sections.map(\.title), testCase.titles)
            XCTAssertEqual(metrics.sections.map(\.markdown), testCase.markdown)
            XCTAssertEqual(metrics.sections.map(\.excerpt), testCase.excerpts)
            XCTAssertEqual(
                metrics.sections.map(\.id),
                zip(testCase.titles.indices, testCase.titles).map { "\($0.0)-\($0.1)" }
            )
            XCTAssertEqual(metrics.sections, JournalSection.extract(from: testCase.body))
            XCTAssertEqual(metrics.wordCount, JournalEntryBodyMetrics.wordCount(in: testCase.body))
        }
    }

    func testOverviewMetricsMatchesLegacyWordAndSectionResultsAcrossBoundaries() {
        let cases: [(name: String, body: String)] = [
            ("empty", ""),
            ("whitespace and newlines", "   \n\t\r\n\u{000B}\u{000C}"),
            ("emoji and combining characters", "😀 e\u{301} 中文\u{00A0}word\n"),
            ("mixed Foundation newlines", "正文\r\n### A\u{000B}内容\u{000C}### B\u{0085}尾部\u{2028}### C\u{2029}"),
            ("marker at document start", "### 标题"),
            ("marker at EOF", "正文\n### "),
            ("consecutive and empty markers", "### \n###  \n### 有内容"),
            ("ASCII indentation", " \t### 合法"),
            ("invalid marker forms", "\u{00A0}### 非法\n###无效\n###\t非法\n#### 四级\n正文 ### 行内"),
            ("fenced code marker", "```\n### 代码中的标题\n```"),
            ("long body without section", String(repeating: "长正文 😀\n", count: 128)),
            ("long body with final section", String(repeating: "长正文 e\u{301}\n", count: 128) + "### 末节")
        ]

        for testCase in cases {
            let overview = JournalEntryOverviewMetrics(body: testCase.body)

            XCTAssertEqual(
                overview.wordCount,
                JournalEntryBodyMetrics.wordCount(in: testCase.body),
                "Unexpected word count for \(testCase.name)"
            )
            XCTAssertEqual(
                overview.hasLevelThreeSection,
                JournalSection.containsLevelThreeSection(in: testCase.body),
                "Unexpected section presence for \(testCase.name)"
            )
        }
    }

    func testBodySummaryCleansMarkdownMarkersWithoutKeepingBlankLines() {
        let body = [
            "# 标题",
            "",
            "**重点** `代码`",
            "> 引用"
        ].joined(separator: "\n")

        let summary = JournalEntryBodySummary(body: body)

        XCTAssertEqual(summary.excerpt, "标题 重点 代码  引用")
    }

    func testEntryDerivedPropertiesDelegateToBodySummary() throws {
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-04-05T12:00:00Z"))
        let entryID = try XCTUnwrap(UUID(uuidString: "66666666-6666-6666-6666-666666666666"))
        let entry = JournalEntry(
            id: entryID,
            title: "派生数据",
            body: "alpha beta\n### Plan\nfour five",
            createdAt: createdAt,
            updatedAt: createdAt
        )

        let summary = entry.bodySummary
        let metrics = entry.bodyMetrics

        XCTAssertEqual(entry.excerpt, summary.excerpt)
        XCTAssertEqual(entry.wordCount, summary.wordCount)
        XCTAssertEqual(entry.sections, summary.sections)
        XCTAssertEqual(entry.sectionCount, summary.sectionCount)
        XCTAssertEqual(metrics.wordCount, summary.wordCount)
        XCTAssertEqual(metrics.sections, summary.sections)
        XCTAssertEqual(metrics.sectionCount, summary.sectionCount)
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

    func testJournalSectionExtractPreservesExactSectionsAcrossNewlineAndMarkerBoundaries() {
        let cases: [(name: String, body: String, titles: [String], markdown: [String], excerpts: [String])] = [
            (
                "LF",
                "导言\n \t### 第一节\n内容一\n\n内容二\n### 第二节\n",
                ["第一节", "第二节"],
                ["内容一\n\n内容二", ""],
                ["内容一 内容二", "还没有内容"]
            ),
            (
                "CR",
                "导言\r \t### 第一节\r内容一\r\r内容二\r### 第二节\r",
                ["第一节", "第二节"],
                ["内容一\n\n内容二", ""],
                ["内容一 内容二", "还没有内容"]
            ),
            (
                "CRLF",
                "导言\r\n \t### 第一节\r\n内容一\r\n\r\n内容二\r\n### 第二节\r\n",
                ["第一节", "第二节"],
                ["内容一\n\n内容二", ""],
                ["内容一 内容二", "还没有内容"]
            ),
            (
                "mixed Foundation newlines",
                "导言\r\n### A\u{000B}one\u{000C}two\u{0085}### B\u{2028}tail\u{2029}",
                ["A", "B"],
                ["one\ntwo", "tail"],
                ["one two", "tail"]
            ),
            (
                "invalid markers and non-ASCII indentation",
                "正文\n###没有空格\n###\t非法\n###\u{00A0}非法\n\u{00A0}### 非法\n#### 四级\n \t### 合法\n正文",
                ["合法"],
                ["正文"],
                ["正文"]
            ),
            (
                "empty and consecutive sections",
                "导言\n### \n###  \n \t\n### 有内容\n\n",
                ["未命名小节", "未命名小节", "有内容"],
                ["", "", ""],
                ["还没有内容", "还没有内容", "还没有内容"]
            ),
            (
                "fenced code remains ordinary text",
                "```\n### 代码标题\n代码\n```\n### 正文标题\n正文",
                ["代码标题", "正文标题"],
                ["代码\n```", "正文"],
                ["代码", "正文"]
            )
        ]

        for testCase in cases {
            let sections = JournalSection.extract(from: testCase.body)

            XCTAssertEqual(sections.count, testCase.titles.count, "Unexpected count for \(testCase.name)")
            XCTAssertEqual(sections.map(\.order), Array(testCase.titles.indices), "Unexpected order for \(testCase.name)")
            XCTAssertEqual(sections.map(\.title), testCase.titles, "Unexpected titles for \(testCase.name)")
            XCTAssertEqual(sections.map(\.markdown), testCase.markdown, "Unexpected markdown for \(testCase.name)")
            XCTAssertEqual(sections.map(\.excerpt), testCase.excerpts, "Unexpected excerpts for \(testCase.name)")
            XCTAssertEqual(
                sections.map(\.id),
                zip(testCase.titles.indices, testCase.titles).map { "\($0.0)-\($0.1)" },
                "Unexpected IDs for \(testCase.name)"
            )
        }
    }

    func testContainsLevelThreeSectionMatchesExtractionAcrossBoundaries() {
        let cases: [(name: String, body: String, expected: Bool)] = [
            ("empty", "", false),
            ("horizontal whitespace", "  \t  ", false),
            ("newlines only", "\n\r\n\u{2028}\u{2029}", false),
            ("plain body", "普通正文 with emoji 😀", false),
            ("level two", "## 标题", false),
            ("level four", "#### 标题", false),
            ("missing separator", "###没有空格", false),
            ("tab separator", "###\t标题", false),
            ("mid line", "正文 ### 标题", false),
            ("document start", "### 标题", true),
            ("empty title", "### ", true),
            ("extra title space", "###  标题", true),
            ("leading space", "   ### 标题", true),
            ("leading tab", "\t\t### 标题", true),
            ("mixed ASCII indentation", " \t \t### 标题", true),
            ("non-breaking space", "\u{00A0}### 标题", false),
            ("full-width space", "\u{3000}### 标题", false),
            ("byte order mark", "\u{FEFF}### 标题", false),
            ("line feed", "正文\n### 标题", true),
            ("vertical tab", "正文\u{000B}### 标题", true),
            ("form feed", "正文\u{000C}### 标题", true),
            ("carriage return", "正文\r### 标题", true),
            ("carriage return line feed", "正文\r\n### 标题", true),
            ("next line", "正文\u{0085}### 标题", true),
            ("line separator", "正文\u{2028}### 标题", true),
            ("paragraph separator", "正文\u{2029}### 标题", true),
            ("consecutive mixed newlines", "正文\r\n\u{2028}\n \t### 标题", true),
            ("trailing newline", "正文\n", false),
            ("multiple sections", "### 第一节\n内容\n### 第二节", true),
            ("fenced code", "```\n### 代码中的标题\n```", true),
            ("unicode before and after", "中文😀e\u{301}\n### 标题😀e\u{301}", true),
            ("long body without section", String(repeating: "正文内容\n", count: 512), false),
            ("long body with final section", String(repeating: "正文内容\n", count: 512) + "### 末节", true)
        ]

        for testCase in cases {
            let actual = JournalSection.containsLevelThreeSection(in: testCase.body)

            XCTAssertEqual(
                actual,
                testCase.expected,
                "Unexpected section detection for \(testCase.name): \(testCase.body.debugDescription)"
            )
            XCTAssertEqual(
                actual,
                !JournalSection.extract(from: testCase.body).isEmpty,
                "Fast path diverged from extraction for \(testCase.name)"
            )
        }
    }

    func testJournalSectionExcerptCleansTaskMarkersAndBlankLines() {
        let section = JournalSection(
            order: 0,
            title: "任务",
            markdown: [
                "- [ ] **整理**",
                "",
                "- [X] `完成`",
                "- 普通项目"
            ].joined(separator: "\n")
        )

        XCTAssertEqual(section.excerpt, "整理  完成  普通项目")
    }
}
