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
        let result = JournalBoundedBodyDerivation.scan(body, excerptLimit: Self.excerptLimit)
        wordCount = result.wordCount
        hasVisibleContent = result.hasVisibleContent
        excerpt = result.excerpt
        sections = result.sections
    }
}
