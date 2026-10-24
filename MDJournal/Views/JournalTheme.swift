import SwiftUI

/// Colors resolve light, dark, and increased-contrast appearances in assets.
enum JournalTheme {
    static let canvas = Color("JournalCanvas")
    static let paper = Color("JournalPaper")
    static let inset = Color("JournalInset")
    static let accent = Color("JournalAccent")
    static let onAccent = Color("JournalOnAccent")
    static let separator = Color("JournalSeparator")
    static let cornerRadius: CGFloat = 14
    static let pageInset: CGFloat = 24
    static let readableWidth: CGFloat = 760
    static let canvasInset: CGFloat = 24
}

struct JournalBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [JournalTheme.canvas, JournalTheme.paper, JournalTheme.canvas],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct JournalSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(JournalTheme.paper, in: RoundedRectangle(cornerRadius: JournalTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: JournalTheme.cornerRadius)
                    .strokeBorder(JournalTheme.separator, lineWidth: 1)
            }
    }
}

extension View {
    func journalSurface() -> some View {
        modifier(JournalSurface())
    }
}
