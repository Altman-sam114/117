import SwiftUI

struct MarkdownToolbar: View {
    var accent: Color = .teal
    let onInsert: (MarkdownSnippet) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MarkdownSnippet.allCases) { snippet in
                    Button {
                        onInsert(snippet)
                    } label: {
                        Image(systemName: snippet.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)
                    .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(snippet.title)
                    .help(snippet.helpText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
}
