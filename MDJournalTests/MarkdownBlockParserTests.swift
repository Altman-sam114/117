import XCTest
@testable import MDJournal

final class MarkdownBlockParserTests: XCTestCase {
    func testParseRecognizesSupportedBlocks() {
        let markdown = [
            "# 标题",
            "",
            "第一段",
            "第二段",
            "",
            "> 引文",
            "- 甲",
            "* 乙",
            "- [ ] 待办",
            "- [x] 完成",
            "---",
            "```",
            "let value = 1",
            "```"
        ].joined(separator: "\n")

        let blocks = MarkdownBlockParser.parse(markdown)

        XCTAssertEqual(
            blocks,
            [
                .heading(level: 1, text: "标题"),
                .paragraph("第一段\n第二段"),
                .quote("引文"),
                .unorderedList(["甲", "乙"]),
                .checklist([
                    ChecklistItem(isChecked: false, text: "待办"),
                    ChecklistItem(isChecked: true, text: "完成")
                ]),
                .divider,
                .code("let value = 1")
            ]
        )
    }

    func testParseFlushesUnclosedCodeBlock() {
        let markdown = [
            "```",
            "let value = 1",
            "print(value)"
        ].joined(separator: "\n")

        XCTAssertEqual(MarkdownBlockParser.parse(markdown), [.code("let value = 1\nprint(value)")])
    }

    func testGroupedByLevelThreePreservesIntroAndSections() {
        let markdown = [
            "开篇说明",
            "",
            "### 第一节",
            "内容一",
            "",
            "### ",
            "空标题内容"
        ].joined(separator: "\n")

        let groups = MarkdownBlockParser.groupedByLevelThree(markdown)

        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0], MarkdownSectionGroup(order: 0, title: "开篇", blocks: [.paragraph("开篇说明")], isIntro: true))
        XCTAssertEqual(groups[1], MarkdownSectionGroup(order: 1, title: "第一节", blocks: [.paragraph("内容一")], isIntro: false))
        XCTAssertEqual(groups[2], MarkdownSectionGroup(order: 2, title: "未命名小节", blocks: [.paragraph("空标题内容")], isIntro: false))
    }
}
