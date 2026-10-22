import SwiftUI

struct MarkdownToolbar: View {
    var accent: Color = JournalTheme.accent
    var showsCommonActions = true
    let onInsert: (MarkdownSnippet) -> Void

    var body: some View {
        HStack(spacing: 2) {
            if showsCommonActions {
                ForEach([MarkdownSnippet.heading, .bold, .checklist]) { snippet in
                    Button {
                        onInsert(snippet)
                    } label: {
                        Label(snippet.title, systemImage: snippet.systemImage)
                            .labelStyle(.iconOnly)
                            .font(.body)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)
                    .accessibilityLabel(snippet.title)
                    .help(snippet.helpText)
                }
            }
            MarkdownToolsMenu(onInsert: onInsert)
        }
    }
}

struct MarkdownToolsMenu: View {
    let onInsert: (MarkdownSnippet) -> Void

    var body: some View {
        Menu {
            ForEach(MarkdownSnippet.allCases) { snippet in
                Button { onInsert(snippet) } label: {
                    Label(snippet.title, systemImage: snippet.systemImage)
                }
                .help(snippet.helpText)
            }
        } label: {
            Image(systemName: "textformat")
                .font(.body)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(JournalTheme.accent)
        .accessibilityLabel("插入 Markdown")
        .help("插入标题、列表与 Markdown 格式")
    }
}
