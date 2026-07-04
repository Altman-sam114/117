import Foundation

struct MarkdownSnippetInsertion {
    struct Result: Equatable {
        let body: String
        let selectedRange: NSRange
    }

    private struct Replacement {
        let text: String
        let selectedRange: NSRange
    }

    static func apply(
        snippet: MarkdownSnippet,
        to body: String,
        selectedRange: NSRange
    ) -> Result {
        let targetRange = clampedRange(for: selectedRange, in: body)
        let targetNSRange = NSRange(targetRange, in: body)
        let selectedText = String(body[targetRange])
        let replacement = replacement(for: snippet, selectedText: selectedText)

        var updatedBody = body
        updatedBody.replaceSubrange(targetRange, with: replacement.text)

        let updatedSelection = NSRange(
            location: targetNSRange.location + replacement.selectedRange.location,
            length: replacement.selectedRange.length
        )

        return Result(
            body: updatedBody,
            selectedRange: clampedNSRange(updatedSelection, in: updatedBody)
        )
    }

    private static func replacement(for snippet: MarkdownSnippet, selectedText: String) -> Replacement {
        if selectedText.isEmpty {
            return emptySelectionReplacement(for: snippet)
        }

        switch snippet {
        case .heading:
            return wrappingReplacement(prefix: "### ", suffix: "\n", selectedText: selectedText)
        case .bold:
            return wrappingReplacement(prefix: "**", suffix: "**", selectedText: selectedText)
        case .italic:
            return wrappingReplacement(prefix: "*", suffix: "*", selectedText: selectedText)
        case .quote:
            return prefixedLineReplacement(prefix: "> ", selectedText: selectedText)
        case .bullet:
            return prefixedLineReplacement(prefix: "- ", selectedText: selectedText)
        case .checklist:
            return prefixedLineReplacement(prefix: "- [ ] ", selectedText: selectedText)
        case .code:
            return codeBlockReplacement(selectedText: selectedText)
        case .divider:
            return Replacement(
                text: snippet.markdown,
                selectedRange: NSRange(location: snippet.markdown.utf16.count, length: 0)
            )
        }
    }

    private static func emptySelectionReplacement(for snippet: MarkdownSnippet) -> Replacement {
        switch snippet {
        case .heading:
            return placeholderReplacement(text: snippet.markdown, placeholder: "小节标题")
        case .bold:
            return placeholderReplacement(text: snippet.markdown, placeholder: "重点")
        case .italic:
            return placeholderReplacement(text: snippet.markdown, placeholder: "想法")
        case .quote:
            return placeholderReplacement(text: snippet.markdown, placeholder: "记下一句话")
        case .bullet, .checklist, .divider:
            return Replacement(
                text: snippet.markdown,
                selectedRange: emptySelectionRange(at: snippet.markdown.utf16.count, in: snippet.markdown)
            )
        case .code:
            return Replacement(
                text: snippet.markdown,
                selectedRange: emptySelectionRange(at: "```\n".utf16.count, in: snippet.markdown)
            )
        }
    }

    private static func wrappingReplacement(prefix: String, suffix: String, selectedText: String) -> Replacement {
        let text = "\(prefix)\(selectedText)\(suffix)"
        return Replacement(
            text: text,
            selectedRange: NSRange(location: prefix.utf16.count, length: selectedText.utf16.count)
        )
    }

    private static func prefixedLineReplacement(prefix: String, selectedText: String) -> Replacement {
        var lines = selectedText.components(separatedBy: "\n")
        let preservesTrailingNewline = selectedText.hasSuffix("\n")
        if preservesTrailingNewline {
            lines.removeLast()
        }

        var text = lines
            .map { "\(prefix)\($0)" }
            .joined(separator: "\n")
        if preservesTrailingNewline {
            text += "\n"
        }

        return Replacement(
            text: text,
            selectedRange: NSRange(location: 0, length: text.utf16.count)
        )
    }

    private static func codeBlockReplacement(selectedText: String) -> Replacement {
        let body = selectedText.hasSuffix("\n") ? selectedText : "\(selectedText)\n"
        let text = "```\n\(body)```\n"

        return Replacement(
            text: text,
            selectedRange: NSRange(location: "```\n".utf16.count, length: selectedText.utf16.count)
        )
    }

    private static func placeholderReplacement(text: String, placeholder: String) -> Replacement {
        if let range = text.range(of: placeholder) {
            return Replacement(text: text, selectedRange: NSRange(range, in: text))
        }

        return Replacement(
            text: text,
            selectedRange: NSRange(location: text.utf16.count, length: 0)
        )
    }

    private static func emptySelectionRange(at location: Int, in text: String) -> NSRange {
        clampedNSRange(NSRange(location: location, length: 0), in: text)
    }

    private static func clampedRange(for nsRange: NSRange, in text: String) -> Range<String.Index> {
        let normalizedRange = clampedNSRange(nsRange, in: text)
        let startIndex = index(atOrBeforeUTF16Offset: normalizedRange.location, in: text)
        let endIndex = index(
            atOrBeforeUTF16Offset: normalizedRange.location + normalizedRange.length,
            in: text
        )

        if startIndex <= endIndex {
            return startIndex..<endIndex
        }

        return startIndex..<startIndex
    }

    private static func clampedNSRange(_ nsRange: NSRange, in text: String) -> NSRange {
        let utf16Count = text.utf16.count

        guard nsRange.location != NSNotFound else {
            return NSRange(location: utf16Count, length: 0)
        }

        let location = min(max(nsRange.location, 0), utf16Count)
        let maximumLength = utf16Count - location
        let length = min(max(nsRange.length, 0), maximumLength)

        return NSRange(location: location, length: length)
    }

    private static func index(atOrBeforeUTF16Offset offset: Int, in text: String) -> String.Index {
        let targetOffset = min(max(offset, 0), text.utf16.count)
        var currentIndex = text.startIndex
        var currentOffset = 0

        while currentIndex < text.endIndex {
            if currentOffset == targetOffset {
                return currentIndex
            }

            let nextIndex = text.index(after: currentIndex)
            let nextOffset = currentOffset + text[currentIndex..<nextIndex].utf16.count

            if nextOffset == targetOffset {
                return nextIndex
            }

            if nextOffset > targetOffset {
                return currentIndex
            }

            currentIndex = nextIndex
            currentOffset = nextOffset
        }

        return text.endIndex
    }
}
