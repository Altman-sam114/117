import Foundation

enum MarkdownSnippet: String, CaseIterable, Identifiable {
    case heading
    case bold
    case italic
    case quote
    case bullet
    case orderedList
    case checklist
    case code
    case divider

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heading:
            return "小节"
        case .bold:
            return "加粗"
        case .italic:
            return "斜体"
        case .quote:
            return "引用"
        case .bullet:
            return "列表"
        case .orderedList:
            return "有序列表"
        case .checklist:
            return "待办"
        case .code:
            return "代码"
        case .divider:
            return "分割线"
        }
    }

    var systemImage: String {
        switch self {
        case .heading:
            return "textformat.size"
        case .bold:
            return "bold"
        case .italic:
            return "italic"
        case .quote:
            return "quote.opening"
        case .bullet:
            return "list.bullet"
        case .orderedList:
            return "list.number"
        case .checklist:
            return "checklist"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .divider:
            return "minus"
        }
    }

    var helpText: String {
        "\(title)（\(MarkdownSnippetCommandShortcut(snippet: self).displayText)）"
    }

    var markdown: String {
        switch self {
        case .heading:
            return "### 小节标题\n"
        case .bold:
            return "**重点**"
        case .italic:
            return "*想法*"
        case .quote:
            return "> 记下一句话\n"
        case .bullet:
            return "- "
        case .orderedList:
            return "1. "
        case .checklist:
            return "- [ ] "
        case .code:
            return "```\n\n```\n"
        case .divider:
            return "---\n"
        }
    }
}
