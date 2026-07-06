import UIKit
import XCTest
@testable import MDJournal

final class MarkdownTextInputConfigurationTests: XCTestCase {
    func testMarkdownBodyFontConfigurationAppliesPreferredRoundedBodyFont() {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 10)

        MarkdownBodyTextView.configureBodyFontIfNeeded(textView)

        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let descriptor = baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor
        let expectedFont = UIFont(descriptor: descriptor, size: baseFont.pointSize)
        XCTAssertEqual(textView.font, expectedFont)
    }

    func testMarkdownBodyFontConfigurationKeepsMatchingFont() throws {
        let textView = UITextView()

        MarkdownBodyTextView.configureBodyFontIfNeeded(textView)
        let configuredFont = try XCTUnwrap(textView.font)
        MarkdownBodyTextView.configureBodyFontIfNeeded(textView)
        let currentFont = try XCTUnwrap(textView.font)

        XCTAssertTrue(currentFont === configuredFont)
    }

    func testMarkdownInputDisablesSmartTextSubstitutions() {
        let textView = UITextView()

        MarkdownBodyTextView.configureMarkdownInputTraits(textView)

        XCTAssertEqual(textView.smartDashesType, .no)
        XCTAssertEqual(textView.smartQuotesType, .no)
        XCTAssertEqual(textView.smartInsertDeleteType, .no)
    }

    func testMarkdownInputConfigurationCanBeReapplied() {
        let textView = UITextView()
        textView.smartDashesType = .yes
        textView.smartQuotesType = .yes
        textView.smartInsertDeleteType = .yes

        MarkdownBodyTextView.configureMarkdownInputTraits(textView)

        XCTAssertEqual(textView.smartDashesType, .no)
        XCTAssertEqual(textView.smartQuotesType, .no)
        XCTAssertEqual(textView.smartInsertDeleteType, .no)
    }
}
