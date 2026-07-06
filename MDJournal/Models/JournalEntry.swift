import Foundation

struct JournalEntry: Identifiable, Codable, Hashable {
    enum Category: String, CaseIterable, Codable, Identifiable {
        case daily = "日常"
        case workStudy = "工作学习"
        case inspiration = "灵感"
        case travel = "旅行"
        case health = "健康"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .daily:
                return "house"
            case .workStudy:
                return "book"
            case .inspiration:
                return "sparkles"
            case .travel:
                return "map"
            case .health:
                return "heart"
            }
        }
    }

    enum Mood: String, CaseIterable, Codable, Identifiable {
        case calm = "平静"
        case happy = "开心"
        case tired = "疲惫"
        case focused = "专注"
        case rainy = "低落"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .calm:
                return "leaf"
            case .happy:
                return "sun.max"
            case .tired:
                return "moon"
            case .focused:
                return "target"
            case .rainy:
                return "cloud.rain"
            }
        }
    }

    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var category: Category
    var mood: Mood

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        category: Category = .daily,
        mood: Mood = .calm
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
        self.mood = mood
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case createdAt
        case updatedAt
        case category
        case mood
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        category = try container.decodeIfPresent(Category.self, forKey: .category) ?? .daily
        mood = try container.decodeIfPresent(Mood.self, forKey: .mood) ?? .calm
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(category, forKey: .category)
        try container.encode(mood, forKey: .mood)
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return createdAt.journalTitleText
        }

        return trimmedTitle
    }

    var bodySummary: JournalEntryBodySummary {
        JournalEntryBodySummary(body: body)
    }

    var bodyMetrics: JournalEntryBodyMetrics {
        JournalEntryBodyMetrics(body: body)
    }

    var excerpt: String {
        bodySummary.excerpt
    }

    var wordCount: Int {
        bodySummary.wordCount
    }

    var sections: [JournalSection] {
        bodySummary.sections
    }

    var sectionCount: Int {
        bodySummary.sectionCount
    }

    var sectionSummaryText: String {
        if sections.isEmpty {
            return "未添加小节"
        }

        return sections.prefix(3).map(\.title).joined(separator: " / ")
    }

    var markdownDocument: String {
        """
        # \(displayTitle)

        \(body)
        """
    }

    static var emptyFallback: JournalEntry {
        JournalEntry(title: "", body: "")
    }

    static func starterEntry(now: Date = Date()) -> JournalEntry {
        JournalEntry(
            title: now.journalTitleText,
            body: """
            ### 今天发生了什么

            - 记录一件值得留下的事
            - 写下一个具体细节

            ### 我的感受

            > 此刻真实的状态，比写得漂亮更重要。

            ### 明天可以做的小事

            - [ ] 给自己一个容易完成的行动
            """,
            createdAt: now,
            updatedAt: now,
            category: .daily,
            mood: .calm
        )
    }
}

struct JournalEntryBodyMetrics: Equatable {
    let wordCount: Int
    let sections: [JournalSection]

    var sectionCount: Int {
        sections.count
    }

    init(body: String) {
        wordCount = Self.wordCount(in: body)
        sections = JournalSection.extract(from: body)
    }

    static func wordCount(in body: String) -> Int {
        var count = 0
        var isInsideWord = false

        for character in body {
            if character.isWhitespace || character.isNewline {
                isInsideWord = false
            } else if !isInsideWord {
                count += 1
                isInsideWord = true
            }
        }

        return count
    }
}

struct JournalEntryBodySummary: Equatable {
    let excerpt: String
    let metrics: JournalEntryBodyMetrics

    var wordCount: Int {
        metrics.wordCount
    }

    var sections: [JournalSection] {
        metrics.sections
    }

    var sectionCount: Int {
        metrics.sectionCount
    }

    init(body: String) {
        metrics = JournalEntryBodyMetrics(body: body)

        let plainText = MarkdownSummaryText.plainText(from: body, removesListMarkers: false)

        excerpt = plainText.isEmpty ? "还没有正文" : plainText
    }
}

struct JournalSection: Identifiable, Hashable {
    var order: Int
    var title: String
    var markdown: String

    var id: String {
        "\(order)-\(title)"
    }

    var excerpt: String {
        let plainText = MarkdownSummaryText.plainText(from: markdown, removesListMarkers: true)

        return plainText.isEmpty ? "还没有内容" : plainText
    }

    static func extract(from markdown: String) -> [JournalSection] {
        let lines = markdown.components(separatedBy: .newlines)
        var sections: [JournalSection] = []
        var currentTitle: String?
        var currentLines: [String] = []

        func flushSection() {
            guard let currentTitle else { return }
            sections.append(
                JournalSection(
                    order: sections.count,
                    title: currentTitle,
                    markdown: currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            currentLines.removeAll()
        }

        for line in lines {
            let trimmedLine = line.trimmingLeadingWhitespace()

            if trimmedLine.hasPrefix("### ") {
                flushSection()
                let sectionTitle = String(trimmedLine.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                currentTitle = sectionTitle.isEmpty ? "未命名小节" : sectionTitle
                continue
            }

            if currentTitle != nil {
                currentLines.append(line)
            }
        }

        flushSection()
        return sections
    }
}

private extension String {
    func trimmingLeadingWhitespace() -> String {
        String(drop(while: { $0 == " " || $0 == "\t" }))
    }
}

private enum MarkdownSummaryText {
    static func plainText(from markdown: String, removesListMarkers: Bool) -> String {
        var result = String()
        var line = String()
        result.reserveCapacity(markdown.count)
        line.reserveCapacity(markdown.count)

        var index = markdown.startIndex
        while index < markdown.endIndex {
            if markdown[index] == "\n" {
                appendLine(line, to: &result)
                line.removeAll(keepingCapacity: true)
                markdown.formIndex(after: &index)
                continue
            }

            if removesListMarkers {
                if markdown[index...].hasPrefix("- [ ]") {
                    markdown.formIndex(&index, offsetBy: 5)
                    continue
                }

                if markdown[index...].hasPrefix("- [x]") || markdown[index...].hasPrefix("- [X]") {
                    markdown.formIndex(&index, offsetBy: 5)
                    continue
                }
            }

            let character = markdown[index]
            if shouldSkip(character, removesListMarkers: removesListMarkers) {
                markdown.formIndex(after: &index)
                continue
            }

            line.append(character)
            markdown.formIndex(after: &index)
        }

        appendLine(line, to: &result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func appendLine(_ line: String, to result: inout String) {
        guard !line.isEmpty else { return }

        if !result.isEmpty {
            result.append(" ")
        }

        result.append(line)
    }

    private static func shouldSkip(_ character: Character, removesListMarkers: Bool) -> Bool {
        switch character {
        case "#", "*", "`", ">":
            return true
        case "-":
            return removesListMarkers
        default:
            return false
        }
    }
}
