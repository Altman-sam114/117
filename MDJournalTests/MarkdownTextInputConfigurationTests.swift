import UIKit
import XCTest
@testable import MDJournal

final class MarkdownTextInputConfigurationTests: XCTestCase {
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
