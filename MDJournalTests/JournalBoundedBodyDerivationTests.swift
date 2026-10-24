import Foundation
import XCTest
@testable import MDJournal

final class JournalBoundedBodyDerivationTests: XCTestCase {
    func testBoundedPresentationMatchesLegacyWhitespaceAndFoundationNewlines() {
        let newlines = ["\n", "\r", "\r\n", "\u{000B}", "\u{000C}", "\u{0085}", "\u{2028}", "\u{2029}"]
        for body in ["", " \t\n\r\n", "### ", "### 标题", "正文\n\n\n尾部", "#\n*\n`\n>"] {
            assertMatchesLegacy(body)
        }
        for newline in newlines {
            assertMatchesLegacy("开头\(newline)### 第一节\(newline)\(newline)   正文\(newline)\t\(newline)尾部  \(newline)### \(newline)\(newline)")
            assertMatchesLegacy(" \(newline)### 第一节\(newline)  \(newline)### 第二节\(newline)结束\(newline)")
        }
        assertMatchesLegacy("### 混合\r第一行\r\n第二行\u{0085}\u{2028}第三行\n\n尾部\u{2029}")
    }

    func testBoundedPresentationMatchesLegacyTaskMarkersAnywhere() {
        for content in [
            "- [ ] 空待办\n- [x] 已完成\n- [X] 大写\n- 普通列表",
            "开头- [ ]中间- [x]结尾- [X]",
            "- [ ]\n- [x]\n- [X]",
            "- [ ] \n  \n- [x] \n\t",
            "- [y] 保留括号\n- [] 不完整\n-[ ] 无空格\n- [x ] 多空格",
            "文字 #*`> 和连字符 - 以及 - [ ] 任务",
            "- [x]\u{0301} 与 - [ ]\u{FE0F} 保留原始匹配边界"
        ] {
            assertMatchesLegacy("### 任务\n\n\(content)\n\n### 结尾\n\(content)")
        }
    }

    func testBoundedPresentationKeepsLegacyFencedCodeAndHeadingRules() {
        assertMatchesLegacy("""
        前言不属于小节
        ### 外部
        ```markdown
        ### 围栏内仍按既有小节规则识别
        - [ ] 不把派生器变成 Markdown 解析器
        ```
        \t### Tab 缩进
        正文
          ### 空格缩进
        > 引用
        \u{00A0}### 非 ASCII 缩进不识别
        #### 四级不识别
        ###\t无 ASCII 空格不识别
        ###\(" ")
        ### 末尾
        """)
    }

    func testBoundedPresentationPreservesUnicodeAndExactCharacterLimits() {
        let prefix = String(repeating: "字", count: 159)
        for text in [
            String(repeating: "e\u{0301}", count: 160),
            String(repeating: "👨‍👩‍👧‍👦", count: 161),
            prefix + "\u{1F1E8}#\u{1F1F3}",
            prefix + "\u{1F1E8}#\u{1F1F3}尾",
            " \u{0301} 前导组合字符 \u{00A0}\u{2003}",
            "*\u{FE0F} 和 #\u{0301} 不能当成独立标记删去",
            "\u{200B}零宽字符\u{2060}保留"
        ] {
            assertMatchesLegacy(text)
            assertMatchesLegacy("### \(text)\n\(text)\n### 结尾\n\(text)")
        }
    }

    func testLongPendingWhitespaceIsTrimmedOrIncludedWithoutFalseOverflow() {
        let spaces = String(repeating: " \t\u{2003}", count: 8_000)
        assertMatchesLegacy(spaces + "短正文" + spaces)
        assertMatchesLegacy("短正文" + spaces + "有后文")
        assertMatchesLegacy("### " + spaces + "短标题" + spaces + "\n短正文" + spaces)
        assertMatchesLegacy("### 空小节\n" + spaces + "\n### 有正文\n开头\n" + spaces + "\n尾部")
        assertMatchesLegacy("### 超长\n" + String(repeating: "a **词** - [ ] 内容 📝\n", count: 1_000))
        XCTAssertEqual(JournalEntryBodyPresentation(body: "短正文" + spaces).excerpt, "短正文")
    }

    func testBoundedPresentationMatchesLegacyDeterministicMixedFragments() {
        let fragments = [
            "文字", " e\u{0301} ", "👨‍👩‍👧‍👦", "\u{1F1E8}#\u{1F1F3}", "- [ ]", "- [x]", "- [X]",
            "#", "*", "`", ">", "-", " ", "\t", "\n", "\r\n", "\r", "\u{0085}", "\u{2028}",
            "### ", "### 小节\n", "\t### 缩进\r\n", "\u{00A0}### 非法", "```\n", " \u{0301} "
        ]
        var state: UInt64 = 0x9500_2026
        for _ in 0..<64 {
            var body = String()
            for _ in 0..<48 {
                state = state &* 6_364_136_223_846_793_005 &+ 1
                body += fragments[Int((state >> 32) % UInt64(fragments.count))]
            }
            assertMatchesLegacy(body)
        }
    }

    func testCloudBenchmarkRecordsBoundedAndLegacyDerivationWithoutTimingThresholds() throws {
        let paragraph = "日记片刻 📝 与 e\u{0301}：**认真记录** - [x] 完成一步，给明天留下从容。\n> 一段英文 words and 中文。\n\n"
        let sectionBody = String(repeating: paragraph, count: max(1, 4_000 / paragraph.count))
        let body = (0..<40).map { "### 第\($0 + 1)小节\n\n\(sectionBody)" }.joined(separator: "\n")
        XCTAssertGreaterThanOrEqual(body.count, 100_000)
        XCTAssertLessThanOrEqual(body.count, 300_000)
        let reference = legacyProjection(body)
        XCTAssertEqual(projection(JournalEntryBodyPresentation(body: body)), reference)

        let clock = ContinuousClock()
        var legacyMilliseconds: [Double] = []
        var boundedMilliseconds: [Double] = []
        for _ in 0..<3 {
            let legacyStart = clock.now
            let legacy = legacyProjection(body)
            legacyMilliseconds.append(milliseconds(legacyStart.duration(to: clock.now)))
            let boundedStart = clock.now
            let bounded = projection(JournalEntryBodyPresentation(body: body))
            boundedMilliseconds.append(milliseconds(boundedStart.duration(to: clock.now)))
            XCTAssertEqual(legacy, reference)
            XCTAssertEqual(bounded, reference)
        }
        let report: [String: Any] = [
            "measurement": "Synchronous model derivation; not UI frame rate, input latency or allocation measurement",
            "buildConfiguration": "Debug",
            "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString,
            "bodyCharacterCount": body.count,
            "bodyUTF8ByteCount": body.utf8.count,
            "sectionCount": reference.sections.count,
            "iterations": 3,
            "resultsEquivalent": true,
            "legacyPath": "JournalEntryBodySummary plus per-section excerpts and final 160 Character truncation",
            "boundedPath": "JournalEntryBodyPresentation using JournalBoundedBodyDerivation",
            "legacyMilliseconds": legacyMilliseconds,
            "boundedMilliseconds": boundedMilliseconds,
            "legacyMedianMilliseconds": legacyMilliseconds.sorted()[1],
            "boundedMedianMilliseconds": boundedMilliseconds.sorted()[1],
            "timingThresholdEnforced": false
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "performance-bounded-body-derivation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private struct Projection: Equatable {
        let wordCount: Int
        let hasVisibleContent: Bool
        let excerpt: String
        let sections: [JournalEntryBodyPresentation.Section]
    }

    private func legacyProjection(_ body: String) -> Projection {
        let summary = JournalEntryBodySummary(body: body)
        return Projection(
            wordCount: summary.wordCount, hasVisibleContent: summary.metrics.hasVisibleContent,
            excerpt: bounded(summary.excerpt), sections: summary.sections.map {
                .init(id: $0.order, title: bounded($0.title), excerpt: bounded($0.excerpt))
            }
        )
    }

    private func projection(_ value: JournalEntryBodyPresentation) -> Projection {
        Projection(
            wordCount: value.wordCount, hasVisibleContent: value.hasVisibleContent,
            excerpt: value.excerpt, sections: value.sections
        )
    }

    private func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1_000_000_000_000_000
    }

    private func assertMatchesLegacy(_ body: String, file: StaticString = #filePath, line: UInt = #line) {
        let reference = JournalEntryBodySummary(body: body)
        let actual = JournalEntryBodyPresentation(body: body)
        XCTAssertEqual(actual.wordCount, reference.wordCount, file: file, line: line)
        XCTAssertEqual(actual.hasVisibleContent, reference.metrics.hasVisibleContent, file: file, line: line)
        XCTAssertEqual(actual.excerpt, bounded(reference.excerpt), file: file, line: line)
        XCTAssertEqual(actual.sectionCount, reference.sectionCount, file: file, line: line)
        XCTAssertLessThanOrEqual(actual.excerpt.count, JournalEntryBodyPresentation.excerptLimit + 1, file: file, line: line)
        for (section, expected) in zip(actual.sections, reference.sections) {
            XCTAssertEqual(section.id, expected.order, file: file, line: line)
            XCTAssertEqual(section.title, bounded(expected.title), file: file, line: line)
            XCTAssertEqual(section.excerpt, bounded(expected.excerpt), file: file, line: line)
            XCTAssertLessThanOrEqual(section.title.count, JournalEntryBodyPresentation.excerptLimit + 1, file: file, line: line)
            XCTAssertLessThanOrEqual(section.excerpt.count, JournalEntryBodyPresentation.excerptLimit + 1, file: file, line: line)
        }
    }

    private func bounded(_ text: String) -> String {
        let limit = JournalEntryBodyPresentation.excerptLimit
        guard let end = text.index(text.startIndex, offsetBy: limit, limitedBy: text.endIndex),
              end != text.endIndex else { return text }
        return String(text[..<end]) + "…"
    }
}
