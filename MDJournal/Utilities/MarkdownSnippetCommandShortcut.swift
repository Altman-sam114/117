import SwiftUI

struct MarkdownSnippetCommandShortcut: Equatable {
    let key: Character
    let modifiers: EventModifiers

    init(snippet: MarkdownSnippet) {
        key = Self.key(for: snippet)
        modifiers = [.command, .option]
    }

    var keyEquivalent: KeyEquivalent {
        KeyEquivalent(key)
    }

    var identifier: String {
        "\(modifiers.rawValue)-\(key)"
    }

    private static func key(for snippet: MarkdownSnippet) -> Character {
        switch snippet {
        case .heading:
            return "1"
        case .bold:
            return "b"
        case .italic:
            return "i"
        case .quote:
            return "q"
        case .bullet:
            return "l"
        case .checklist:
            return "t"
        case .code:
            return "k"
        case .divider:
            return "r"
        }
    }
}
