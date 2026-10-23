import SwiftUI

struct EmptyStateView: View {
    let onCreate: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(JournalTheme.inset)
                            .frame(width: 88, height: 108)
                            .rotationEffect(.degrees(-8))
                        RoundedRectangle(cornerRadius: 12)
                            .fill(JournalTheme.paper)
                            .frame(width: 88, height: 108)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(JournalTheme.separator)
                            }
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(JournalTheme.accent)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text("把今天，写成一页。")
                            .font(.system(.largeTitle, design: .serif).weight(.medium))
                        Text("选择一篇日记继续写，或从一个新的念头开始。")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                    Button(action: onCreate) {
                        Label("新建日记", systemImage: "square.and.pencil")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(JournalTheme.accent)

                    Label("仅在本机存储 · 无需账号", systemImage: "internaldrive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(32)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity, minHeight: max(0, proxy.size.height - 64))
            }
            .background { JournalBackdrop() }
        }
    }
}
