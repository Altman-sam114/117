import SwiftUI
import UIKit
import XCTest
@testable import MDJournal

final class MarkdownTextInputConfigurationTests: XCTestCase {
    @MainActor
    func testProductionBridgeInitializationAndExternalSynchronizationDoNotPublishBindings() async throws {
        let initialBody = "正文 📝 与 e\u{301}"
        let textProbe = BindingProbe(value: initialBody)
        let selectionProbe = BindingProbe(value: NSRange(location: NSNotFound, length: 0))
        let focusProbe = BindingProbe(value: false)
        let suite = "mdjournal-bridge-preferences-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        func bridge() -> some View {
            MarkdownBodyTextView(
                text: textProbe.binding, selectedRange: selectionProbe.binding, isFocused: focusProbe.binding
            )
            .journalPreferences()
            .defaultAppStorage(defaults)
        }
        let controller = UIHostingController(rootView: bridge())
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive },
            "The production bridge requires the test host's foreground scene"
        )
        let window = try XCTUnwrap(scene.windows.first { $0.isKeyWindow })
        let originalRoot = window.rootViewController
        let wasHidden = window.isHidden
        window.rootViewController = nil
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.endEditing(true)
            window.rootViewController = nil
            window.rootViewController = originalRoot
            window.isHidden = wasHidden
            window.makeKey()
        }
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        let input = try XCTUnwrap(findBodyInput(in: controller.view))
        let coordinator = try XCTUnwrap(input.delegate as? MarkdownBodyTextView.Coordinator)
        XCTAssertEqual(input.text, initialBody)
        XCTAssertEqual(input.selectedRange, NSRange(location: initialBody.utf16.count, length: 0))
        XCTAssertEqual(textProbe.setterCount, 0)
        XCTAssertEqual(selectionProbe.setterCount, 0)
        XCTAssertEqual(focusProbe.setterCount, 0)

        let externalBody = "新正文：👨‍👩‍👧‍👦 e\u{301} 与末尾"
        let externalSelection = (externalBody as NSString).range(of: "正文")
        textProbe.value = externalBody
        selectionProbe.value = externalSelection
        controller.rootView = bridge()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(try XCTUnwrap(findBodyInput(in: controller.view)) === input)
        XCTAssertEqual(input.text, externalBody)
        XCTAssertEqual(input.selectedRange, externalSelection)
        XCTAssertEqual(textProbe.value, externalBody)
        XCTAssertEqual(selectionProbe.value, externalSelection)
        XCTAssertEqual(textProbe.setterCount, 0, "External body synchronization must not become a local edit")
        XCTAssertEqual(selectionProbe.setterCount, 0, "Programmatic selection changes must not feed back into SwiftUI")
        XCTAssertEqual(focusProbe.setterCount, 0)

        let userSelection = (externalBody as NSString).range(of: "末尾")
        input.selectedRange = userSelection
        coordinator.textViewDidChangeSelection(input)
        XCTAssertEqual(selectionProbe.value, userSelection)
        XCTAssertEqual(selectionProbe.setterCount, 1)
        XCTAssertEqual(textProbe.setterCount, 0)
        XCTAssertEqual(focusProbe.setterCount, 0)
        XCTAssertEqual(
            coordinator.syncState.decision(for: externalBody, selectedRange: userSelection, hasMarkedText: false),
            .synchronizeBodyAndSelection,
            "A user selection callback must still not create a body-publication fast path"
        )

        defaults.set(JournalWritingFont.serif.rawValue, forKey: JournalPreferenceKey.writingFont)
        defaults.set(JournalWritingSize.large.rawValue, forKey: JournalPreferenceKey.writingSize)
        defaults.set(JournalWritingSpacing.relaxed.rawValue, forKey: JournalPreferenceKey.writingSpacing)
        controller.rootView = bridge()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(try XCTUnwrap(findBodyInput(in: controller.view)) === input)
        XCTAssertEqual(input.text, externalBody)
        XCTAssertEqual(input.selectedRange, userSelection)
        XCTAssertEqual(textProbe.setterCount, 0)
        XCTAssertEqual(selectionProbe.setterCount, 1)
        XCTAssertEqual(focusProbe.setterCount, 0)
        XCTAssertGreaterThan(try XCTUnwrap(input.font).pointSize, 17)
        XCTAssertGreaterThan((input.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.lineSpacing ?? 0, 0)

        XCTAssertTrue(input.becomeFirstResponder(), "The fixture must support actual keyboard focus before testing cancellation")
        XCTAssertTrue(input.isFirstResponder)
        XCTAssertTrue(focusProbe.value, "The production delegate must observe the real focus transition")
        XCTAssertTrue(input.resignFirstResponder())
        XCTAssertFalse(input.isFirstResponder)
        XCTAssertFalse(focusProbe.value)
        focusProbe.value = true
        coordinator.synchronizeFocus(input, shouldBeFocused: true)
        MarkdownBodyTextView.dismantleUIView(input, coordinator: coordinator)
        XCTAssertNil(input.delegate, "A detached bridge must no longer receive UIKit callbacks")
        let setterCounts = (textProbe.setterCount, selectionProbe.setterCount, focusProbe.setterCount)
        input.text = "Detached text must never become a journal edit"
        input.selectedRange = NSRange(location: 0, length: 0)
        coordinator.textViewDidChange(input)
        coordinator.textViewDidChangeSelection(input)
        coordinator.textViewDidBeginEditing(input)
        coordinator.textViewDidEndEditing(input)
        coordinator.applyIndentation(.indent, to: input)
        XCTAssertFalse(coordinator.textView(input, shouldChangeTextIn: input.selectedRange, replacementText: "\n"))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(input.isFirstResponder, "Dismantling must invalidate a focus request queued on the main queue")
        XCTAssertEqual(textProbe.value, externalBody)
        XCTAssertEqual(selectionProbe.value, userSelection)
        XCTAssertTrue(focusProbe.value)
        XCTAssertEqual(textProbe.setterCount, setterCounts.0)
        XCTAssertEqual(selectionProbe.setterCount, setterCounts.1)
        XCTAssertEqual(focusProbe.setterCount, setterCounts.2)
    }

    @MainActor
    private func findBodyInput(in view: UIView) -> UITextView? {
        if let input = view as? UITextView { return input }
        for child in view.subviews {
            if let input = findBodyInput(in: child) { return input }
        }
        return nil
    }

    func testMarkdownBodyTextViewSyncStateNeedsBodyPublicationForFastPath() {
        var state = MarkdownBodyTextViewSyncState()
        let body = "正文"
        let changedSelection = NSRange(location: 2, length: 0)

        XCTAssertEqual(
            state.decision(
                for: body,
                selectedRange: changedSelection,
                hasMarkedText: false
            ),
            .synchronizeBodyAndSelection
        )
    }

    func testMarkdownBodyTextViewSyncStateUsesOneShotLocalPublicationFastPath() {
        var state = MarkdownBodyTextViewSyncState()
        let body = "本地正文"
        let selection = NSRange(location: 8, length: 0)

        XCTAssertEqual(
            state.decision(for: body, selectedRange: selection, hasMarkedText: false),
            .synchronizeBodyAndSelection
        )

        state.markLocalPublication(body: body, selectedRange: selection)

        XCTAssertEqual(
            state.decision(for: body, selectedRange: selection, hasMarkedText: false),
            .keepLocalPublication
        )
        XCTAssertEqual(
            state.decision(for: body, selectedRange: selection, hasMarkedText: false),
            .synchronizeBodyAndSelection
        )
    }

    func testMarkdownBodyTextViewSyncStateRejectsMismatchedExternalSelection() {
        var state = MarkdownBodyTextViewSyncState()
        let body = "本地正文"
        state.markLocalPublication(body: body, selectedRange: NSRange(location: 8, length: 0))

        XCTAssertEqual(
            state.decision(
                for: body,
                selectedRange: NSRange(location: 2, length: 1),
                hasMarkedText: false
            ),
            .synchronizeBodyAndSelection
        )
    }

    func testMarkdownBodyTextViewSyncStateDefersMarkedTextWithoutConsumingLocalPublication() {
        var state = MarkdownBodyTextViewSyncState()
        let body = "本地正文"
        let selection = NSRange(location: 8, length: 0)
        state.markLocalPublication(body: body, selectedRange: selection)

        XCTAssertEqual(
            state.decision(for: body, selectedRange: selection, hasMarkedText: true),
            .deferMarkedText
        )
        XCTAssertEqual(
            state.decision(for: body, selectedRange: selection, hasMarkedText: false),
            .keepLocalPublication
        )
    }

    func testMarkdownBodyTextViewSyncStateRejectsDifferentBodyWithMatchingSelection() {
        var state = MarkdownBodyTextViewSyncState()
        let selection = NSRange(location: 8, length: 0)
        state.markLocalPublication(body: "本地正文", selectedRange: selection)

        XCTAssertEqual(
            state.decision(
                for: "外部正文",
                selectedRange: selection,
                hasMarkedText: false
            ),
            .synchronizeBodyAndSelection
        )
    }

    func testTextViewDidChangeSelectionDoesNotCreateBodyFastPath() {
        let textProbe = BindingProbe(value: "正文")
        let selectionProbe = BindingProbe(value: NSRange(location: 0, length: 0))
        let focusProbe = BindingProbe(value: false)
        let coordinator = MarkdownBodyTextView.Coordinator(
            text: textProbe.binding,
            selectedRange: selectionProbe.binding,
            isFocused: focusProbe.binding
        )
        let textView = UITextView()
        textView.text = textProbe.value
        textView.selectedRange = NSRange(location: 2, length: 0)

        coordinator.textViewDidChangeSelection(textView)

        XCTAssertEqual(
            coordinator.syncState.decision(
                for: textView.text,
                selectedRange: textView.selectedRange,
                hasMarkedText: false
            ),
            .synchronizeBodyAndSelection
        )
    }

    func testTextViewDidChangeRecordsLocalPublicationForTheNextBridgeUpdate() {
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

        XCTAssertEqual(
            coordinator.syncState.decision(
                for: updatedText,
                selectedRange: updatedRange,
                hasMarkedText: false
            ),
            .keepLocalPublication
        )
    }

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
        let getterCountBeforeAction = textProbe.getterCount
        let setterCountBeforeAction = textProbe.setterCount

        coordinator.textViewDidChange(textView)

        XCTAssertEqual(textProbe.getterCount - getterCountBeforeAction, 0)
        XCTAssertEqual(textProbe.setterCount - setterCountBeforeAction, 1)
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
        let getterCountBeforeAction = textProbe.getterCount
        let setterCountBeforeAction = textProbe.setterCount

        let shouldApplySystemChange = coordinator.textView(
            textView,
            shouldChangeTextIn: initialRange,
            replacementText: "\n"
        )

        XCTAssertFalse(shouldApplySystemChange)
        XCTAssertEqual(textView.text, expectedBody)
        XCTAssertEqual(textView.selectedRange, expectedRange)
        XCTAssertEqual(textProbe.getterCount - getterCountBeforeAction, 0)
        XCTAssertEqual(textProbe.setterCount - setterCountBeforeAction, 1)
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
        let getterCountBeforeAction = textProbe.getterCount
        let setterCountBeforeAction = textProbe.setterCount

        coordinator.applyIndentation(.indent, to: textView)

        XCTAssertEqual(textView.text, expectedBody)
        XCTAssertEqual(textView.selectedRange, expectedRange)
        XCTAssertEqual(textProbe.getterCount - getterCountBeforeAction, 0)
        XCTAssertEqual(textProbe.setterCount - setterCountBeforeAction, 1)
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
