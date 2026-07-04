import SwiftUI
import UIKit

struct MarkdownBodyTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRange: $selectedRange, isFocused: $isFocused)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = Self.bodyFont
        textView.adjustsFontForContentSizeCategory = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        textView.textContainer.lineFragmentPadding = 0
        textView.text = text
        textView.selectedRange = Self.clampedRange(selectedRange, in: text)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.selectedRange = $selectedRange
        context.coordinator.isFocused = $isFocused

        if textView.font != Self.bodyFont {
            textView.font = Self.bodyFont
        }

        let hasMarkedText = textView.markedTextRange != nil

        if !hasMarkedText, textView.text != text {
            textView.text = text
        }

        if !hasMarkedText {
            let clampedSelection = Self.clampedRange(selectedRange, in: textView.text)
            if textView.selectedRange != clampedSelection {
                textView.selectedRange = clampedSelection
            }
        }

        if isFocused, !textView.isFirstResponder {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        } else if !isFocused, textView.isFirstResponder {
            DispatchQueue.main.async {
                textView.resignFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var selectedRange: Binding<NSRange>
        var isFocused: Binding<Bool>

        init(text: Binding<String>, selectedRange: Binding<NSRange>, isFocused: Binding<Bool>) {
            self.text = text
            self.selectedRange = selectedRange
            self.isFocused = isFocused
        }

        func textViewDidChange(_ textView: UITextView) {
            if text.wrappedValue != textView.text {
                text.wrappedValue = textView.text
            }

            selectedRange.wrappedValue = textView.selectedRange
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            selectedRange.wrappedValue = textView.selectedRange
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused.wrappedValue = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isFocused.wrappedValue = false
        }
    }

    private static var bodyFont: UIFont {
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let descriptor = baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor
        return UIFont(descriptor: descriptor, size: baseFont.pointSize)
    }

    private static func clampedRange(_ range: NSRange, in text: String) -> NSRange {
        let utf16Count = text.utf16.count

        guard range.location != NSNotFound else {
            return NSRange(location: utf16Count, length: 0)
        }

        let location = min(max(range.location, 0), utf16Count)
        let maximumLength = utf16Count - location
        let length = min(max(range.length, 0), maximumLength)
        return NSRange(location: location, length: length)
    }
}
