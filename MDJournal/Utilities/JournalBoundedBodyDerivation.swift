import Foundation

enum JournalBoundedBodyDerivation {
    struct Result {
        let wordCount: Int
        let hasVisibleContent: Bool
        let excerpt: String
        let sections: [JournalEntryBodyPresentation.Section]
    }

    static func scan(_ body: String, excerptLimit: Int) -> Result {
        var wordCount = 0
        var isInsideWord = false
        var hasVisibleContent = false
        var summary = BoundedMarkdownSummary(limit: excerptLimit, removesListMarkers: false)
        var sections = BoundedJournalSections(limit: excerptLimit)
        var lineStart = body.startIndex
        var index = body.startIndex

        while index < body.endIndex {
            let character = body[index]
            let nextIndex = body.index(after: index)
            let isWhitespace = character.isWhitespace
            if !isWhitespace { hasVisibleContent = true }
            if isWhitespace || character.isNewline {
                isInsideWord = false
            } else if !isInsideWord {
                wordCount += 1
                isInsideWord = true
            }

            summary.consumeSharedCharacter(character)
            if character.unicodeScalars.allSatisfy({ CharacterSet.newlines.contains($0) }) {
                sections.consume(body[lineStart..<index])
                lineStart = nextIndex
            }
            index = nextIndex
        }

        sections.consume(body[lineStart..<body.endIndex])
        sections.finish()
        return Result(
            wordCount: wordCount, hasVisibleContent: hasVisibleContent,
            excerpt: summary.finish(fallback: "还没有正文"), sections: sections.values
        )
    }
}

private struct BoundedJournalSections {
    private let limit: Int
    private var title: String?
    private var summary: BoundedMarkdownSummary
    private(set) var values: [JournalEntryBodyPresentation.Section] = []

    init(limit: Int) {
        self.limit = limit
        summary = BoundedMarkdownSummary(limit: limit, removesListMarkers: true)
    }

    mutating func consume(_ rawLine: Substring) {
        let line = rawLine.drop(while: { $0 == " " || $0 == "\t" })
        if line.hasPrefix("### ") {
            flush()
            var boundedTitle = BoundedTrimmedText(limit: limit)
            for character in line.dropFirst(4) {
                boundedTitle.append(character)
                if boundedTitle.isTruncated { break }
            }
            title = boundedTitle.finish(fallback: "未命名小节")
        } else if title != nil {
            summary.consumeLine(rawLine)
            summary.endLine()
        }
    }

    mutating func finish() {
        flush()
    }

    private mutating func flush() {
        guard let title else { return }
        values.append(.init(id: values.count, title: title, excerpt: summary.finish(fallback: "还没有内容")))
        summary = BoundedMarkdownSummary(limit: limit, removesListMarkers: true)
    }
}

private struct BoundedMarkdownSummary {
    private let removesListMarkers: Bool
    private var text: BoundedTrimmedText
    private var currentLineHasContent = false
    private var hasPreviousNonemptyLine = false

    init(limit: Int, removesListMarkers: Bool) {
        self.removesListMarkers = removesListMarkers
        text = BoundedTrimmedText(limit: limit)
    }

    mutating func consumeSharedCharacter(_ character: Character) {
        guard !text.isTruncated else { return }
        // The body summary splits literal LF; sections normalize Foundation newlines separately.
        if character == "\n" {
            endLine()
        } else {
            appendContent(character)
        }
    }

    mutating func consumeLine(_ line: Substring) {
        guard !text.isTruncated else { return }
        var index = line.startIndex
        while index < line.endIndex, !text.isTruncated {
            if removesListMarkers,
               line[index...].hasPrefix("- [ ]") || line[index...].hasPrefix("- [x]")
                || line[index...].hasPrefix("- [X]") {
                line.formIndex(&index, offsetBy: 5)
                continue
            }
            appendContent(line[index])
            line.formIndex(after: &index)
        }
    }

    mutating func endLine() {
        if currentLineHasContent { hasPreviousNonemptyLine = true }
        currentLineHasContent = false
    }

    func finish(fallback: String) -> String {
        text.finish(fallback: fallback)
    }

    private mutating func appendContent(_ character: Character) {
        switch character {
        case "#", "*", "`", ">": return
        case "-" where removesListMarkers: return
        default: break
        }
        if !currentLineHasContent {
            if hasPreviousNonemptyLine { text.append(" ") }
            currentLineHasContent = true
        }
        text.append(character)
    }
}

private struct BoundedTrimmedText {
    private let limit: Int
    private var retained = String()
    private var retainedCount = 0
    private var pendingWhitespace = String()
    private var pendingWhitespaceOverflow = false
    private(set) var isTruncated = false

    init(limit: Int) {
        self.limit = max(0, limit)
    }

    mutating func append(_ character: Character) {
        guard !isTruncated else { return }
        var appended = String()
        for scalar in character.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if !retained.isEmpty || !appended.isEmpty, !pendingWhitespaceOverflow {
                    pendingWhitespace.unicodeScalars.append(scalar)
                }
            } else {
                appended.append(contentsOf: pendingWhitespace)
                pendingWhitespace.removeAll(keepingCapacity: true)
                pendingWhitespaceOverflow = false
                appended.unicodeScalars.append(scalar)
            }
        }

        if !appended.isEmpty {
            if let last = retained.last {
                // Removed markers can join emoji/combining characters across the append boundary.
                retainedCount += (String(last) + appended).count - 1
            } else {
                retainedCount = appended.count
            }
            retained.append(contentsOf: appended)
        }

        if retainedCount > limit {
            retained = String(retained.prefix(limit))
            retainedCount = limit
            pendingWhitespace.removeAll(keepingCapacity: false)
            isTruncated = true
        } else if let end = pendingWhitespace.index(
            pendingWhitespace.startIndex, offsetBy: limit + 1, limitedBy: pendingWhitespace.endIndex
        ), end != pendingWhitespace.endIndex {
            // Keep one overflow grapheme until later content confirms these spaces are not trailing.
            pendingWhitespace = String(pendingWhitespace[..<end])
            pendingWhitespaceOverflow = true
        }
    }

    func finish(fallback: String) -> String {
        if retained.isEmpty, !isTruncated { return fallback }
        return retained + (isTruncated ? "…" : "")
    }
}
