import SwiftUI

struct MarkdownPreviewView: View {
    let markdown: String
    var accent: Color = .teal
    var maxContentWidth: CGFloat = 720

    var body: some View {
        let document = MarkdownBlockParser.parseDocument(markdown)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: document.shouldUseSectionGroups ? 14 : 12) {
                if document.blocks.isEmpty {
                    Text("暂无内容")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 60)
                } else if document.shouldUseSectionGroups {
                    ForEach(document.sectionGroups) { group in
                        sectionGroupView(group)
                    }
                } else {
                    ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                        blockView(block)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(previewBackground)
    }

    private var previewBackground: some View {
        LinearGradient(
            colors: [
                accent.opacity(0.08),
                Color(.secondarySystemGroupedBackground),
                Color(.secondarySystemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func sectionGroupView(_ group: MarkdownSectionGroup) -> some View {
        if group.isIntro {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(group.blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "number")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)

                    Text(group.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                if group.blocks.isEmpty {
                    Text("这个小节还没有内容")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(group.blocks.enumerated()), id: \.offset) { _, block in
                        blockView(block)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            Text(inlineMarkdown(text))
                .font(font(for: level))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, level == 1 ? 2 : 8)

        case let .paragraph(text):
            Text(inlineMarkdown(text))
                .font(.body)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)

        case let .quote(text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 4)

                Text(inlineMarkdown(text))
                    .font(.body.italic())
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

        case let .unorderedList(items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("•")
                            .font(.body.weight(.bold))
                            .foregroundStyle(accent)
                        Text(inlineMarkdown(item))
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

        case let .orderedList(items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(item.number).")
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(accent)
                            .frame(minWidth: 28, alignment: .trailing)

                        Text(inlineMarkdown(item.text))
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

        case let .checklist(items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isChecked ? accent : .secondary)
                        Text(inlineMarkdown(item.text))
                            .font(.body)
                            .strikethrough(item.isChecked)
                            .foregroundStyle(item.isChecked ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

        case let .code(code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.isEmpty ? " " : code)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
            )

        case .divider:
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(height: 1)
                .padding(.vertical, 8)
        }
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        if let attributedText = try? AttributedString(markdown: text) {
            return attributedText
        }

        return AttributedString(text)
    }

    private func font(for headingLevel: Int) -> Font {
        switch headingLevel {
        case 1:
            return .title.weight(.bold)
        case 2:
            return .title3.weight(.semibold)
        default:
            return .headline
        }
    }
}
