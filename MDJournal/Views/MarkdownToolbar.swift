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
                            .frame(width: 44, height: 44)
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
