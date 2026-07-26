import SwiftUI

enum JournalEntryNavigationDirection: String, CaseIterable, Identifiable, Equatable {
    case newer
    case older

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newer:
            return "较新日记"
        case .older:
            return "较早日记"
        }
    }
}

enum JournalEntryNavigation {
    static func destinationID(
        in entries: [JournalEntry],
        selection: JournalEntry.ID?,
        direction: JournalEntryNavigationDirection
    ) -> JournalEntry.ID? {
        guard let selection,
              let currentIndex = entries.firstIndex(where: { $0.id == selection })
        else {
            return nil
        }

        let destinationIndex: Int
        switch direction {
        case .newer:
            destinationIndex = currentIndex - 1
        case .older:
            destinationIndex = currentIndex + 1
        }

        guard entries.indices.contains(destinationIndex) else {
            return nil
        }
        return entries[destinationIndex].id
    }
}

struct JournalEntryNavigationShortcut: Equatable {
    let direction: JournalEntryNavigationDirection
    let modifiers: EventModifiers = [.command, .option]

    var keyEquivalent: KeyEquivalent {
        switch direction {
        case .newer:
            return .upArrow
        case .older:
            return .downArrow
        }
    }

    var identifier: String {
        "\(modifiers.rawValue)-\(keyIdentifier)"
    }

    var displayText: String {
        switch direction {
        case .newer:
            return "⌘⌥↑"
        case .older:
            return "⌘⌥↓"
        }
    }

    private var keyIdentifier: String {
        switch direction {
        case .newer:
            return "upArrow"
        case .older:
            return "downArrow"
        }
    }
}
