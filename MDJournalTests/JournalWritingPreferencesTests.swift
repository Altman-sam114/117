import SwiftUI
import UIKit
import XCTest
@testable import MDJournal

final class JournalWritingPreferencesTests: XCTestCase {
    @MainActor
    func testUnknownStoredPreferencesFallBackWithoutChangingTheJournalFormat() {
        XCTAssertEqual(
            JournalWritingPreferences(fontRaw: "future-font", sizeRaw: "-999", spacingRaw: "unknown"),
            JournalWritingPreferences()
        )
        XCTAssertNil(JournalAppearance.system.colorScheme)
        XCTAssertEqual(JournalAppearance.light.colorScheme, .light)
        XCTAssertEqual(JournalAppearance.dark.colorScheme, .dark)
        XCTAssertEqual(Set([
            JournalPreferenceKey.appearance, JournalPreferenceKey.writingFont,
            JournalPreferenceKey.writingSize, JournalPreferenceKey.writingSpacing,
            JournalAppLockStore.enabledDefaultsKey, JournalAppLockStore.hidesInactiveContentDefaultsKey
        ]).count, 6)
    }

    @MainActor
    func testEveryFontAndSizeContinuesToScaleForAccessibility() {
        for font in JournalWritingFont.allCases {
            for size in JournalWritingSize.allCases {
                let preferences = JournalWritingPreferences(font: font, size: size)
                let standard = preferences.uiFont(category: .large)
                XCTAssertEqual(standard.pointSize, size.basePointSize, accuracy: 0.01)
                var previousSize = standard.pointSize
                for category: UIContentSizeCategory in [
                    .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
                    .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge
                ] {
                    let accessible = preferences.uiFont(category: category)
                    let traits = UITraitCollection(preferredContentSizeCategory: category)
                    let expected = UIFontMetrics(forTextStyle: .body).scaledValue(
                        for: size.basePointSize, compatibleWith: traits
                    )
                    XCTAssertEqual(accessible.pointSize, expected, accuracy: 0.01, "Every accessibility size must match the native body-font scale")
                    XCTAssertGreaterThan(accessible.pointSize, previousSize)
                    previousSize = accessible.pointSize
                }
                XCTAssertGreaterThan(previousSize, 40, "The largest accessibility category must remain available for every writing font")
            }
        }
    }

    @MainActor
    func testNativeWritingStylePreservesUnicodeSelectionAndReusesMatchingAttributes() throws {
        let input = UITextView()
        let body = "中文 👨‍👩‍👧‍👦 e\u{301}\n第二行"
        input.text = body
        let selection = (body as NSString).range(of: "👨‍👩‍👧‍👦 e\u{301}")
        input.selectedRange = selection
        let preferences = JournalWritingPreferences(font: .serif, size: .comfortable, spacing: .relaxed)
        MarkdownBodyTextView.configureWritingStyleIfNeeded(input, category: .large, preferences: preferences)
        XCTAssertEqual(input.text, body)
        XCTAssertEqual(input.selectedRange, selection)
        let font = try XCTUnwrap(input.font)
        let style = try XCTUnwrap(input.typingAttributes[.paragraphStyle] as? NSParagraphStyle)
        XCTAssertEqual(font.pointSize, 19, accuracy: 0.01)
        XCTAssertEqual(style.lineSpacing, 5, accuracy: 0.01)
        let stored = try XCTUnwrap(input.textStorage.attribute(.paragraphStyle, at: body.utf16.count - 1, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertEqual(stored.lineSpacing, style.lineSpacing)
        MarkdownBodyTextView.configureWritingStyleIfNeeded(input, category: .large, preferences: preferences)
        XCTAssertTrue(input.font === font, "An unchanged render must not reapply attributes across the full body")
        XCTAssertTrue((input.typingAttributes[.paragraphStyle] as? NSParagraphStyle) === style)
        MarkdownBodyTextView.configureWritingStyleIfNeeded(input, category: .large, preferences: JournalWritingPreferences())
        XCTAssertEqual(input.text, body)
        XCTAssertEqual(input.selectedRange, selection)
        XCTAssertEqual((input.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.lineSpacing, 0)
    }
}
