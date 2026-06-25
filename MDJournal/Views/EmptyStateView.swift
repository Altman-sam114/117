import SwiftUI

struct EmptyStateView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.teal)

            VStack(spacing: 6) {
                Text("选择或新建一篇日记")
                    .font(.title3.weight(.semibold))

                Text("用 Markdown 写下当天的记录，然后切到预览查看排版。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onCreate) {
                Label("新建日记", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(maxWidth: 380)
    }
}
