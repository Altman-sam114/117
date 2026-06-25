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

    var excerpt: String {
        let plainText = body
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: ">", with: "")
            .split(separator: "\n")
            .map(String.init)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return plainText.isEmpty ? "还没有正文" : plainText
    }

    var wordCount: Int {
        body
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    var sections: [JournalSection] {
        JournalSection.extract(from: body)
    }

    var sectionCount: Int {
        sections.count
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

struct JournalSection: Identifiable, Hashable {
    var order: Int
    var title: String
    var markdown: String

    var id: String {
        "\(order)-\(title)"
    }

    var excerpt: String {
        let plainText = markdown
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "- [ ]", with: "")
            .replacingOccurrences(of: "- [x]", with: "")
            .replacingOccurrences(of: "- [X]", with: "")
            .replacingOccurrences(of: "-", with: "")
            .split(separator: "\n")
            .map(String.init)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

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
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

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
