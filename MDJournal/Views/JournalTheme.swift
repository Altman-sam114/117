import SwiftUI

/// Colors resolve light, dark, and increased-contrast appearances in assets.
enum JournalTheme {
    static let canvas = Color("JournalCanvas")
    static let paper = Color("JournalPaper")
    static let inset = Color("JournalInset")
    static let accent = Color("JournalAccent")
    static let separator = Color("JournalSeparator")
    static let cornerRadius: CGFloat = 14
    static let pageInset: CGFloat = 24
    static let readableWidth: CGFloat = 760
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
