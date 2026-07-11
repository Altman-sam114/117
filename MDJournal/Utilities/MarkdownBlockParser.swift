import Foundation

enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case quote(String)
    case unorderedList([String])
    case orderedList([OrderedListItem])
    case checklist([ChecklistItem])
    case code(String)
    case divider
}

struct OrderedListItem: Equatable {
    var number: String
    var text: String
}

struct ChecklistItem: Equatable {
    var isChecked: Bool
    var text: String
}

struct MarkdownSectionGroup: Identifiable, Equatable {
    var id: Int { order }
    var order: Int
    var title: String
    var blocks: [MarkdownBlock]
    var isIntro: Bool
}

struct MarkdownParseResult: Equatable {
    let blocks: [MarkdownBlock]
    let sectionGroups: [MarkdownSectionGroup]

    var shouldUseSectionGroups: Bool {
        sectionGroups.contains { !$0.isIntro }
    }
}

enum MarkdownBlockParser {
    static func parseDocument(_ markdown: String) -> MarkdownParseResult {
        let blocks = parse(markdown)
        return MarkdownParseResult(
            blocks: blocks,
            sectionGroups: groupedByLevelThree(from: blocks)
        )
    }

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []
        var unorderedItems: [String] = []
        var orderedItems: [OrderedListItem] = []
        var checklistItems: [ChecklistItem] = []
        var codeLines: [String] = []
        var isReadingCode = false

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
            paragraphLines.removeAll(keepingCapacity: true)
        }

        func flushUnorderedList() {
            guard !unorderedItems.isEmpty else { return }
            blocks.append(.unorderedList(unorderedItems))
            unorderedItems.removeAll(keepingCapacity: true)
        }

        func flushOrderedList() {
            guard !orderedItems.isEmpty else { return }
            blocks.append(.orderedList(orderedItems))
            orderedItems.removeAll(keepingCapacity: true)
        }

        func flushChecklist() {
            guard !checklistItems.isEmpty else { return }
            blocks.append(.checklist(checklistItems))
            checklistItems.removeAll(keepingCapacity: true)
        }

        func flushInlineBlocks() {
            flushParagraph()
            flushUnorderedList()
            flushOrderedList()
            flushChecklist()
        }

        forEachLineComponent(in: markdown) { rawLine in
            if isReadingCode {
                let trimmedLine = rawLine.leadingWhitespaceTrimmed()
                if trimmedLine.hasPrefix("```") {
                    blocks.append(.code(codeLines.joined(separator: "\n")))
                    codeLines.removeAll(keepingCapacity: true)
                    isReadingCode = false
                } else {
                    codeLines.append(String(rawLine))
                }
                return
            }

            let isBlankLine = rawLine.isHorizontalWhitespaceOnly
            if isBlankLine {
                flushInlineBlocks()
                return
            }

            let trimmedLine = rawLine.leadingWhitespaceTrimmed()

            if trimmedLine.hasPrefix("```") {
                flushInlineBlocks()
                isReadingCode = true
                return
            }

            if trimmedLine == "---" || trimmedLine == "***" {
                flushInlineBlocks()
                blocks.append(.divider)
                return
            }

            if let heading = heading(from: trimmedLine) {
                flushInlineBlocks()
                blocks.append(.heading(level: heading.level, text: heading.text))
                return
            }

            if let quote = quote(from: trimmedLine) {
                flushInlineBlocks()
                blocks.append(.quote(quote))
                return
            }

            if let item = checklistItem(from: trimmedLine) {
                flushParagraph()
                flushUnorderedList()
                flushOrderedList()
                checklistItems.append(item)
                return
            }

            if let item = unorderedItem(from: trimmedLine) {
                flushParagraph()
                flushOrderedList()
                flushChecklist()
                unorderedItems.append(item)
                return
            }

            if let item = orderedItem(from: trimmedLine) {
                flushParagraph()
                flushUnorderedList()
                flushChecklist()
                orderedItems.append(item)
                return
            }

            flushUnorderedList()
            flushOrderedList()
            flushChecklist()
            paragraphLines.append(String(rawLine))
        }

        if isReadingCode {
            blocks.append(.code(codeLines.joined(separator: "\n")))
        }

        flushInlineBlocks()
        return blocks
    }

    static func groupedByLevelThree(_ markdown: String) -> [MarkdownSectionGroup] {
        groupedByLevelThree(from: parse(markdown))
    }

    private static func groupedByLevelThree(from blocks: [MarkdownBlock]) -> [MarkdownSectionGroup] {
        var groups: [MarkdownSectionGroup] = []
        var currentTitle = "开篇"
        var currentBlocks: [MarkdownBlock] = []
        var currentIsIntro = true

        func flushGroup() {
            guard !currentBlocks.isEmpty || !currentIsIntro else { return }
            groups.append(
                MarkdownSectionGroup(
                    order: groups.count,
                    title: currentTitle,
                    blocks: currentBlocks,
                    isIntro: currentIsIntro
                )
            )
            currentBlocks.removeAll(keepingCapacity: true)
        }

        for block in blocks {
            if case let .heading(level, title) = block, level == 3 {
                flushGroup()
                let sectionTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                currentTitle = sectionTitle.isEmpty ? "未命名小节" : sectionTitle
                currentIsIntro = false
                continue
            }

            currentBlocks.append(block)
        }

        flushGroup()
        return groups
    }

    private static func forEachLineComponent(in markdown: String, _ body: (Substring) -> Void) {
        var componentStart = markdown.startIndex

        while componentStart < markdown.endIndex,
              let separatorRange = markdown.rangeOfCharacter(
                from: .newlines,
                range: componentStart..<markdown.endIndex
              ) {
            body(markdown[componentStart..<separatorRange.lowerBound])
            componentStart = markdown.indexAfterNewline(at: separatorRange)
        }

        body(markdown[componentStart..<markdown.endIndex])
    }

    private static func heading(from line: Substring) -> (level: Int, text: String)? {
        let markerCount = line.prefix { $0 == "#" }.count
        guard (1...3).contains(markerCount) else { return nil }

        let marker = String(repeating: "#", count: markerCount) + " "
        guard line.hasPrefix(marker) else { return nil }

        let text = String(line.dropFirst(marker.count))
        return (markerCount, text)
    }

    private static func quote(from line: Substring) -> String? {
        guard line.hasPrefix("> ") else { return nil }
        return String(line.dropFirst(2))
    }

    private static func unorderedItem(from line: Substring) -> String? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return String(line.dropFirst(2))
        }

        return nil
    }

    private static func orderedItem(from line: Substring) -> OrderedListItem? {
        var numberEnd = line.startIndex
        while numberEnd < line.endIndex, line[numberEnd].isNumber {
            numberEnd = line.index(after: numberEnd)
        }

        guard numberEnd > line.startIndex,
              numberEnd < line.endIndex,
              line[numberEnd] == "."
        else {
            return nil
        }

        let spaceIndex = line.index(after: numberEnd)
        guard spaceIndex < line.endIndex, line[spaceIndex] == " " else {
            return nil
        }

        let contentStart = line.index(after: spaceIndex)
        let text = contentStart < line.endIndex ? String(line[contentStart...]) : ""
        return OrderedListItem(
            number: String(line[line.startIndex..<numberEnd]),
            text: text
        )
    }

    private static func checklistItem(from line: Substring) -> ChecklistItem? {
        if line.hasPrefix("- [ ] ") {
            return ChecklistItem(isChecked: false, text: String(line.dropFirst(6)))
        }

        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            return ChecklistItem(isChecked: true, text: String(line.dropFirst(6)))
        }

        return nil
    }
}

private extension Substring {
    var isHorizontalWhitespaceOnly: Bool {
        unicodeScalars.allSatisfy { CharacterSet.whitespaces.contains($0) }
    }

    func leadingWhitespaceTrimmed() -> Substring {
        drop(while: { $0 == " " || $0 == "\t" })
    }
}

private extension String {
    func indexAfterNewline(at range: Range<String.Index>) -> String.Index {
        guard self[range] == "\r",
              range.upperBound < endIndex,
              self[range.upperBound] == "\n"
        else {
            return range.upperBound
        }

        return index(after: range.upperBound)
    }
}
