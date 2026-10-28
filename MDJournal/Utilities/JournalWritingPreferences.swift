import SwiftUI
import UIKit

enum JournalPreferenceKey {
    static let appearance = "journal.appearance"
    static let writingFont = "journal.writing.font"
    static let writingSize = "journal.writing.size"
    static let writingSpacing = "journal.writing.spacing"
}

enum JournalAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色纸页"
        case .dark: return "深色纸页"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum JournalWritingFont: String, CaseIterable, Identifiable {
    case rounded, serif, monospaced

    var id: String { rawValue }
    var title: String {
        switch self {
        case .rounded: return "圆润"
        case .serif: return "书页"
        case .monospaced: return "等宽"
        }
    }
    var design: Font.Design {
        switch self {
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        }
    }
    var uiDesign: UIFontDescriptor.SystemDesign {
        switch self {
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        }
    }
}

enum JournalWritingSize: String, CaseIterable, Identifiable {
    case standard, comfortable, large

    var id: String { rawValue }
    var title: String {
        switch self {
        case .standard: return "标准"
        case .comfortable: return "舒适"
        case .large: return "大字"
        }
    }
    var basePointSize: CGFloat {
        switch self {
        case .standard: return 17
        case .comfortable: return 19
        case .large: return 21
        }
    }
}

enum JournalWritingSpacing: String, CaseIterable, Identifiable {
    case standard, relaxed

    var id: String { rawValue }
    var title: String { self == .standard ? "标准" : "疏朗" }
    var extraLineSpacing: CGFloat { self == .standard ? 0 : 5 }
}

struct JournalWritingPreferences: Equatable {
    var font: JournalWritingFont = .rounded
    var size: JournalWritingSize = .standard
    var spacing: JournalWritingSpacing = .standard

    init(font: JournalWritingFont = .rounded, size: JournalWritingSize = .standard, spacing: JournalWritingSpacing = .standard) {
        self.font = font
        self.size = size
        self.spacing = spacing
    }

    init(fontRaw: String, sizeRaw: String, spacingRaw: String) {
        font = JournalWritingFont(rawValue: fontRaw) ?? .rounded
        size = JournalWritingSize(rawValue: sizeRaw) ?? .standard
        spacing = JournalWritingSpacing(rawValue: spacingRaw) ?? .standard
    }

    func uiFont(category: UIContentSizeCategory) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        let base = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits)
        let descriptor = base.fontDescriptor.withDesign(font.uiDesign) ?? base.fontDescriptor
        let pointSize = size == .standard ? base.pointSize
            : UIFontMetrics(forTextStyle: .body).scaledValue(for: size.basePointSize, compatibleWith: traits)
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

private struct JournalWritingPreferencesKey: EnvironmentKey {
    static let defaultValue = JournalWritingPreferences()
}

extension EnvironmentValues {
    var journalWritingPreferences: JournalWritingPreferences {
        get { self[JournalWritingPreferencesKey.self] }
        set { self[JournalWritingPreferencesKey.self] = newValue }
    }
}

private struct JournalPreferencesModifier: ViewModifier {
    @AppStorage(JournalPreferenceKey.appearance) private var appearance = JournalAppearance.system.rawValue
    @AppStorage(JournalPreferenceKey.writingFont) private var font = JournalWritingFont.rounded.rawValue
    @AppStorage(JournalPreferenceKey.writingSize) private var size = JournalWritingSize.standard.rawValue
    @AppStorage(JournalPreferenceKey.writingSpacing) private var spacing = JournalWritingSpacing.standard.rawValue

    func body(content: Content) -> some View {
        content
            .environment(\.journalWritingPreferences, JournalWritingPreferences(fontRaw: font, sizeRaw: size, spacingRaw: spacing))
            .preferredColorScheme((JournalAppearance(rawValue: appearance) ?? .system).colorScheme)
    }
}

extension View {
    func journalPreferences() -> some View { modifier(JournalPreferencesModifier()) }
}
