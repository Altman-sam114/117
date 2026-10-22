import Foundation

/// A bounded, non-persistent projection; it never retains section Markdown or the source body.
struct JournalEntryBodyPresentation: Equatable, Sendable {
    struct Section: Identifiable, Equatable, Sendable {
        let id: Int
        let title: String
        let excerpt: String
    }

    static let excerptLimit = 160
    let wordCount: Int
    let hasVisibleContent: Bool
    let excerpt: String
    let sections: [Section]

    var sectionCount: Int { sections.count }

    init(body: String) {
        let summary = JournalEntryBodySummary(body: body)
        wordCount = summary.wordCount
        hasVisibleContent = summary.metrics.hasVisibleContent
        excerpt = Self.bounded(summary.excerpt)
        sections = summary.sections.map {
            Section(id: $0.order, title: Self.bounded($0.title), excerpt: Self.bounded($0.excerpt))
        }
    }

    private static func bounded(_ text: String) -> String {
        guard let end = text.index(text.startIndex, offsetBy: excerptLimit, limitedBy: text.endIndex),
              end != text.endIndex else { return text }
        return String(text[..<end]) + "…"
    }
}
