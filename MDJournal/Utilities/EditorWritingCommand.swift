import SwiftUI

enum EditorWritingCommand: String, CaseIterable, Identifiable {
    case focusBody
    case togglePreview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focusBody:
            return "聚焦正文"
        case .togglePreview:
            return "显示/隐藏预览"
        }
    }

    var systemImage: String {
        switch self {
        case .focusBody:
            return "text.cursor"
        case .togglePreview:
            return "rectangle.split.2x1"
        }
    }
}

struct EditorWritingCommandShortcut: Equatable {
    let key: Character
    let modifiers: EventModifiers

    init(command: EditorWritingCommand) {
        key = Self.key(for: command)
        modifiers = [.command, .option]
    }

    var keyEquivalent: KeyEquivalent {
        KeyEquivalent(key)
    }

    var identifier: String {
        "\(modifiers.rawValue)-\(key)"
    }

    private static func key(for command: EditorWritingCommand) -> Character {
        switch command {
        case .focusBody:
            return "e"
        case .togglePreview:
            return "p"
        }
    }
}
