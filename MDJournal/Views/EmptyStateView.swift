import SwiftUI

struct EmptyStateView: View {
    let onCreate: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "book.closed")
                        .font(.largeTitle)
                        .foregroundStyle(JournalTheme.accent)
                        .padding(24)
                        .background(JournalTheme.inset, in: RoundedRectangle(cornerRadius: 24))
                        .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text("给今天，留一页。")
                            .font(.system(.title, design: .serif).weight(.medium))
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
                }
                .padding(32)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .background(JournalTheme.canvas)
        }
    }
}
