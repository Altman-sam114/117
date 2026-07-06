import SwiftUI

enum EditorWritingCommand: String, CaseIterable, Identifiable {
    case focusBody
    case focusWriting
    case indentLines
    case outdentLines
    case togglePreview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focusBody:
            return "聚焦正文"
        case .focusWriting:
            return "专注写作"
        case .indentLines:
            return "增加缩进"
        case .outdentLines:
            return "减少缩进"
        case .togglePreview:
            return "显示/隐藏预览"
        }
    }

    var systemImage: String {
        switch self {
        case .focusBody:
            return "text.cursor"
        case .focusWriting:
            return "rectangle.leadinghalf.inset.filled"
        case .indentLines:
            return "increase.indent"
        case .outdentLines:
            return "decrease.indent"
        case .togglePreview:
            return "rectangle.split.2x1"
        }
    }

    var helpText: String {
        "\(title)（\(EditorWritingCommandShortcut(command: self).displayText)）"
    }

    var indentationDirection: MarkdownLineIndentation.Direction? {
        switch self {
        case .indentLines:
            return .indent
        case .outdentLines:
            return .outdent
        case .focusBody, .focusWriting, .togglePreview:
            return nil
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

    var displayText: String {
        "⌘⌥\(String(key).uppercased())"
    }

    private static func key(for command: EditorWritingCommand) -> Character {
        switch command {
        case .focusBody:
            return "e"
        case .focusWriting:
            return "w"
        case .indentLines:
            return "]"
        case .outdentLines:
            return "["
        case .togglePreview:
            return "p"
        }
    }
}
