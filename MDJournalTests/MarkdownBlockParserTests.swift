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
            "1. 第一项",
            "2. 第二项",
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
                .orderedList([
                    OrderedListItem(number: "1", text: "第一项"),
                    OrderedListItem(number: "2", text: "第二项")
                ]),
                .checklist([
                    ChecklistItem(isChecked: false, text: "待办"),
                    ChecklistItem(isChecked: true, text: "完成")
                ]),
                .divider,
                .code("let value = 1")
            ]
        )
    }

    func testParseFlushesOrderedListsBetweenBlockTypes() {
        let markdown = [
            "1. 第一项",
            "2. 第二项",
            "",
            "正文",
            "3. 第三项",
            "- 无序",
            "- [ ] 待办",
            "4. 第四项"
        ].joined(separator: "\n")

        XCTAssertEqual(
            MarkdownBlockParser.parse(markdown),
            [
                .orderedList([
                    OrderedListItem(number: "1", text: "第一项"),
                    OrderedListItem(number: "2", text: "第二项")
                ]),
                .paragraph("正文"),
                .orderedList([OrderedListItem(number: "3", text: "第三项")]),
                .unorderedList(["无序"]),
                .checklist([ChecklistItem(isChecked: false, text: "待办")]),
                .orderedList([OrderedListItem(number: "4", text: "第四项")])
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

    func testParseKeepsOrderedListMarkersInsideCodeBlock() {
        let markdown = [
            "```",
            "1. code",
            "2. still code",
            "```",
            "1. 正文列表"
        ].joined(separator: "\n")

        XCTAssertEqual(
            MarkdownBlockParser.parse(markdown),
            [
                .code("1. code\n2. still code"),
                .orderedList([OrderedListItem(number: "1", text: "正文列表")])
            ]
        )
    }

    func testParseRejectsUnsupportedOrderedListMarkers() {
        let markdown = [
            "1.",
            "1) 不是有序列表",
            "abc. 也不是"
        ].joined(separator: "\n")

        XCTAssertEqual(
            MarkdownBlockParser.parse(markdown),
            [.paragraph("1.\n1) 不是有序列表\nabc. 也不是")]
        )
    }

    func testParseTrimsLeadingWhitespaceAndAllowsEmptyOrderedListItems() {
        let markdown = [
            "  9. 缩进项",
            "10. "
        ].joined(separator: "\n")

        XCTAssertEqual(
            MarkdownBlockParser.parse(markdown),
            [
                .orderedList([
                    OrderedListItem(number: "9", text: "缩进项"),
                    OrderedListItem(number: "10", text: "")
                ])
            ]
        )
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

    func testParseDocumentReturnsBlocksAndSectionGroupsFromSameMarkdown() {
        let markdown = [
            "# 标题",
            "开篇说明",
            "",
            "### 第一节",
            "- [ ] 待办",
            "",
            "### 第二节",
            "1. 第一步",
            "2. 第二步",
            "",
            "内容二"
        ].joined(separator: "\n")

        let document = MarkdownBlockParser.parseDocument(markdown)

        XCTAssertEqual(document.blocks, MarkdownBlockParser.parse(markdown))
        XCTAssertEqual(document.sectionGroups, MarkdownBlockParser.groupedByLevelThree(markdown))
        XCTAssertTrue(document.shouldUseSectionGroups)
        XCTAssertEqual(
            document.sectionGroups,
            [
                MarkdownSectionGroup(
                    order: 0,
                    title: "开篇",
                    blocks: [
                        .heading(level: 1, text: "标题"),
                        .paragraph("开篇说明")
                    ],
                    isIntro: true
                ),
                MarkdownSectionGroup(
                    order: 1,
                    title: "第一节",
                    blocks: [
                        .checklist([ChecklistItem(isChecked: false, text: "待办")])
                    ],
                    isIntro: false
                ),
                MarkdownSectionGroup(
                    order: 2,
                    title: "第二节",
                    blocks: [
                        .orderedList([
                            OrderedListItem(number: "1", text: "第一步"),
                            OrderedListItem(number: "2", text: "第二步")
                        ]),
                        .paragraph("内容二")
                    ],
                    isIntro: false
                )
            ]
        )
    }

    func testParseDocumentDoesNotTreatLevelThreeHeadingInsideCodeAsSection() {
        let markdown = [
            "开篇说明",
            "",
            "```",
            "### 这不是小节",
            "```"
        ].joined(separator: "\n")

        let document = MarkdownBlockParser.parseDocument(markdown)

        XCTAssertFalse(document.shouldUseSectionGroups)
        XCTAssertEqual(
            document.sectionGroups,
            [
                MarkdownSectionGroup(
                    order: 0,
                    title: "开篇",
                    blocks: [
                        .paragraph("开篇说明"),
                        .code("### 这不是小节")
                    ],
                    isIntro: true
                )
            ]
        )
    }

    func testInlineMarkdownSkipsParserForPlainText() {
        XCTAssertFalse(MarkdownPreviewView.shouldParseInlineMarkdown("今天写了普通中文和 English 123。"))
        XCTAssertFalse(MarkdownPreviewView.shouldParseInlineMarkdown("没有样式的段落\n第二行"))
    }

    func testInlineMarkdownKeepsParserForSupportedOrAmbiguousMarkers() {
        let markdownLikeTexts = [
            "**加粗**",
            "_斜体_",
            "`代码`",
            "[链接](https://example.com)",
            "![图片](image.png)",
            "<https://example.com>",
            "Tom &amp; Jerry",
            "\\*转义星号",
            "~~删除线~~",
            "表格 | 分隔"
        ]

        for text in markdownLikeTexts {
            XCTAssertTrue(
                MarkdownPreviewView.shouldParseInlineMarkdown(text),
                "Expected Markdown parsing for: \(text)"
            )
        }
    }
}
