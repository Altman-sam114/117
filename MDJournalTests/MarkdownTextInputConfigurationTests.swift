import SwiftUI
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

    func testTextViewDidChangePublishesTextWithoutReadingBinding() {
        let textProbe = BindingProbe(value: "旧正文")
        let selectionProbe = BindingProbe(value: NSRange(location: 0, length: 0))
        let focusProbe = BindingProbe(value: false)
        let coordinator = MarkdownBodyTextView.Coordinator(
            text: textProbe.binding,
            selectedRange: selectionProbe.binding,
            isFocused: focusProbe.binding
        )
        let textView = UITextView()
        let updatedText = "新的正文"
        let updatedRange = NSRange(location: updatedText.utf16.count, length: 0)
        textView.text = updatedText
        textView.selectedRange = updatedRange

        coordinator.textViewDidChange(textView)

        XCTAssertEqual(textProbe.getterCount, 0)
        XCTAssertEqual(textProbe.setterCount, 1)
        XCTAssertEqual(textProbe.value, updatedText)
        XCTAssertEqual(selectionProbe.value, updatedRange)
    }

    func testLineContinuationPublishesTextOnceWithoutReadingBinding() {
        let body = "- 第一项"
        let initialRange = NSRange(location: body.utf16.count, length: 0)
        let expectedBody = "- 第一项\n- "
        let expectedRange = NSRange(location: expectedBody.utf16.count, length: 0)
        let textProbe = BindingProbe(value: body)
        let selectionProbe = BindingProbe(value: initialRange)
        let focusProbe = BindingProbe(value: false)
        let coordinator = MarkdownBodyTextView.Coordinator(
            text: textProbe.binding,
            selectedRange: selectionProbe.binding,
            isFocused: focusProbe.binding
        )
        let textView = UITextView()
        textView.text = body
        textView.selectedRange = initialRange

        let shouldApplySystemChange = coordinator.textView(
            textView,
            shouldChangeTextIn: initialRange,
            replacementText: "\n"
        )

        XCTAssertFalse(shouldApplySystemChange)
        XCTAssertEqual(textView.text, expectedBody)
        XCTAssertEqual(textView.selectedRange, expectedRange)
        XCTAssertEqual(textProbe.getterCount, 0)
        XCTAssertEqual(textProbe.setterCount, 1)
        XCTAssertEqual(textProbe.value, expectedBody)
        XCTAssertEqual(selectionProbe.value, expectedRange)
    }

    func testIndentationPublishesTextOnceWithoutReadingBinding() {
        let body = "今天\n- 第一项"
        let initialRange = NSRange(location: body.utf16.count, length: 0)
        let expectedBody = "今天\n  - 第一项"
        let expectedRange = NSRange(location: expectedBody.utf16.count, length: 0)
        let textProbe = BindingProbe(value: body)
        let selectionProbe = BindingProbe(value: initialRange)
        let focusProbe = BindingProbe(value: false)
        let coordinator = MarkdownBodyTextView.Coordinator(
            text: textProbe.binding,
            selectedRange: selectionProbe.binding,
            isFocused: focusProbe.binding
        )
        let textView = UITextView()
        textView.text = body
        textView.selectedRange = initialRange

        coordinator.applyIndentation(.indent, to: textView)

        XCTAssertEqual(textView.text, expectedBody)
        XCTAssertEqual(textView.selectedRange, expectedRange)
        XCTAssertEqual(textProbe.getterCount, 0)
        XCTAssertEqual(textProbe.setterCount, 1)
        XCTAssertEqual(textProbe.value, expectedBody)
        XCTAssertEqual(selectionProbe.value, expectedRange)
    }
}

private final class BindingProbe<Value> {
    var value: Value
    private(set) var getterCount = 0
    private(set) var setterCount = 0

    init(value: Value) {
        self.value = value
    }

    var binding: Binding<Value> {
        Binding(
            get: {
                self.getterCount += 1
                return self.value
            },
            set: { newValue in
                self.setterCount += 1
                self.value = newValue
            }
        )
    }
}
