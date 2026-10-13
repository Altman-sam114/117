import SwiftUI

struct MarkdownToolbar: View {
    var accent: Color = JournalTheme.accent
    let onInsert: (MarkdownSnippet) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(MarkdownSnippet.allCases) { snippet in
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
                    .background(JournalTheme.inset, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(snippet.title)
                    .help(snippet.helpText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(JournalTheme.paper)
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
