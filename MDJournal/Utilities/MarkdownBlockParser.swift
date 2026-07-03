import Foundation

enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case quote(String)
    case unorderedList([String])
    case checklist([ChecklistItem])
    case code(String)
    case divider
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

enum MarkdownBlockParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []
        var unorderedItems: [String] = []
        var checklistItems: [ChecklistItem] = []
        var codeLines: [String] = []
        var isReadingCode = false

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
            paragraphLines.removeAll()
        }

        func flushUnorderedList() {
            guard !unorderedItems.isEmpty else { return }
            blocks.append(.unorderedList(unorderedItems))
            unorderedItems.removeAll()
        }

        func flushChecklist() {
            guard !checklistItems.isEmpty else { return }
            blocks.append(.checklist(checklistItems))
            checklistItems.removeAll()
        }

        func flushInlineBlocks() {
            flushParagraph()
            flushUnorderedList()
            flushChecklist()
        }

        for rawLine in lines {
            let isBlankLine = rawLine.trimmingCharacters(in: .whitespaces).isEmpty
            let trimmedLine = rawLine.trimmingLeadingWhitespace()

            if isReadingCode {
                if trimmedLine.hasPrefix("```") {
                    blocks.append(.code(codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                    isReadingCode = false
                } else {
                    codeLines.append(rawLine)
                }
                continue
            }

            if trimmedLine.hasPrefix("```") {
                flushInlineBlocks()
                isReadingCode = true
                continue
            }

            if isBlankLine {
                flushInlineBlocks()
                continue
            }

            if trimmedLine == "---" || trimmedLine == "***" {
                flushInlineBlocks()
                blocks.append(.divider)
                continue
            }

            if let heading = heading(from: trimmedLine) {
                flushInlineBlocks()
                blocks.append(.heading(level: heading.level, text: heading.text))
                continue
            }

            if let quote = quote(from: trimmedLine) {
                flushInlineBlocks()
                blocks.append(.quote(quote))
                continue
            }

            if let item = checklistItem(from: trimmedLine) {
                flushParagraph()
                flushUnorderedList()
                checklistItems.append(item)
                continue
            }

            if let item = unorderedItem(from: trimmedLine) {
                flushParagraph()
                flushChecklist()
                unorderedItems.append(item)
                continue
            }

            flushUnorderedList()
            flushChecklist()
            paragraphLines.append(rawLine)
        }

        if isReadingCode {
            blocks.append(.code(codeLines.joined(separator: "\n")))
        }

        flushInlineBlocks()
        return blocks
    }

    static func groupedByLevelThree(_ markdown: String) -> [MarkdownSectionGroup] {
        let blocks = parse(markdown)
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
            currentBlocks.removeAll()
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

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let markerCount = line.prefix { $0 == "#" }.count
        guard (1...3).contains(markerCount) else { return nil }

        let marker = String(repeating: "#", count: markerCount) + " "
        guard line.hasPrefix(marker) else { return nil }

        let text = String(line.dropFirst(marker.count))
        return (markerCount, text)
    }

    private static func quote(from line: String) -> String? {
        guard line.hasPrefix("> ") else { return nil }
        return String(line.dropFirst(2))
    }

    private static func unorderedItem(from line: String) -> String? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return String(line.dropFirst(2))
        }

        return nil
    }

    private static func checklistItem(from line: String) -> ChecklistItem? {
        if line.hasPrefix("- [ ] ") {
            return ChecklistItem(isChecked: false, text: String(line.dropFirst(6)))
        }

        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            return ChecklistItem(isChecked: true, text: String(line.dropFirst(6)))
        }

        return nil
    }
}

private extension String {
    func trimmingLeadingWhitespace() -> String {
        String(drop(while: { $0 == " " || $0 == "\t" }))
    }
}
