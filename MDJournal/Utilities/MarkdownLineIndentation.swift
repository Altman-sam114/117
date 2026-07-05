import Foundation

struct MarkdownLineIndentation {
    enum Direction {
        case indent
        case outdent
    }

    struct Result: Equatable {
        let body: String
        let selectedRange: NSRange
    }

    private struct Operation {
        let range: Range<String.Index>
        let location: Int
        let replacedLength: Int
        let replacement: String

        var replacementLength: Int {
            replacement.utf16.count
        }
    }

    private static let indentationUnit = "  "

    static func apply(
        to body: String,
        selectedRange: NSRange,
        direction: Direction
    ) -> Result? {
        let normalizedRange = clampedNSRange(selectedRange, in: body)
        let lineStarts = selectedLineStarts(for: normalizedRange, in: body)
        let operations = lineStarts.compactMap { lineStart in
            operation(for: lineStart, direction: direction, in: body)
        }

        guard !operations.isEmpty else { return nil }

        var updatedBody = body
        for operation in operations.sorted(by: { $0.location > $1.location }) {
            updatedBody.replaceSubrange(operation.range, with: operation.replacement)
        }

        return Result(
            body: updatedBody,
            selectedRange: updatedRange(normalizedRange, applying: operations)
        )
    }

    private static func operation(
        for lineStart: String.Index,
        direction: Direction,
        in body: String
    ) -> Operation? {
        switch direction {
        case .indent:
            return Operation(
                range: lineStart..<lineStart,
                location: NSRange(body.startIndex..<lineStart, in: body).length,
                replacedLength: 0,
                replacement: indentationUnit
            )
        case .outdent:
            guard lineStart < body.endIndex else { return nil }

            if body[lineStart...].hasPrefix(indentationUnit) {
                let end = body.index(lineStart, offsetBy: indentationUnit.count)
                return Operation(
                    range: lineStart..<end,
                    location: NSRange(body.startIndex..<lineStart, in: body).length,
                    replacedLength: indentationUnit.utf16.count,
                    replacement: ""
                )
            }

            if body[lineStart] == "\t" {
                let end = body.index(after: lineStart)
                return Operation(
                    range: lineStart..<end,
                    location: NSRange(body.startIndex..<lineStart, in: body).length,
                    replacedLength: "\t".utf16.count,
                    replacement: ""
                )
            }

            return nil
        }
    }

    private static func selectedLineStarts(for range: NSRange, in text: String) -> [String.Index] {
        let selectionStart = index(atOrBeforeUTF16Offset: range.location, in: text)
        let effectiveEndOffset: Int
        if range.length > 0 {
            effectiveEndOffset = max(range.location, range.location + range.length - 1)
        } else {
            effectiveEndOffset = range.location
        }

        let selectionEnd = index(atOrBeforeUTF16Offset: effectiveEndOffset, in: text)
        let firstLineStart = lineStart(before: selectionStart, in: text)
        let lastLineStart = lineStart(before: selectionEnd, in: text)

        var starts = [String.Index]()
        var currentStart = firstLineStart
        while true {
            starts.append(currentStart)
            guard currentStart != lastLineStart,
                  let nextStart = nextLineStart(after: currentStart, in: text)
            else {
                break
            }
            currentStart = nextStart
        }

        return starts
    }

    private static func updatedRange(_ range: NSRange, applying operations: [Operation]) -> NSRange {
        let isCollapsed = range.length == 0
        var location = range.location
        var end = range.location + range.length

        for operation in operations.sorted(by: { $0.location < $1.location }) {
            location = adjustedBoundary(
                location,
                for: operation,
                includeInsertionAtBoundary: isCollapsed
            )
            end = adjustedBoundary(
                end,
                for: operation,
                includeInsertionAtBoundary: isCollapsed
            )
        }

        return NSRange(location: max(0, location), length: max(0, end - location))
    }

    private static func adjustedBoundary(
        _ boundary: Int,
        for operation: Operation,
        includeInsertionAtBoundary: Bool
    ) -> Int {
        let operationEnd = operation.location + operation.replacedLength
        let delta = operation.replacementLength - operation.replacedLength

        if operation.replacedLength == 0 {
            if operation.location < boundary || (includeInsertionAtBoundary && operation.location == boundary) {
                return boundary + delta
            }
            return boundary
        }

        if boundary <= operation.location {
            return boundary
        }

        if boundary >= operationEnd {
            return boundary + delta
        }

        return operation.location
    }

    private static func lineStart(before index: String.Index, in text: String) -> String.Index {
        var currentIndex = index
        while currentIndex > text.startIndex {
            let previousIndex = text.index(before: currentIndex)
            guard text[previousIndex] != "\n" else { break }
            currentIndex = previousIndex
        }
        return currentIndex
    }

    private static func nextLineStart(after lineStart: String.Index, in text: String) -> String.Index? {
        var currentIndex = lineStart
        while currentIndex < text.endIndex {
            if text[currentIndex] == "\n" {
                return text.index(after: currentIndex)
            }
            currentIndex = text.index(after: currentIndex)
        }
        return nil
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
