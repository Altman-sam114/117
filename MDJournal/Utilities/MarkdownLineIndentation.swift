import Foundation

struct MarkdownLineIndentation {
    enum Direction: Equatable {
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

    private struct LineStart {
        let index: String.Index
        let location: Int
    }

    private static let indentationUnit = "  "

    static func apply(
        to body: String,
        selectedRange: NSRange,
        direction: Direction
    ) -> Result? {
        let normalizedRange = clampedNSRange(selectedRange, in: body)
        let effectiveEndOffset = effectiveEndOffset(for: normalizedRange)
        let allLineStarts = lineStarts(in: body, throughUTF16Offset: effectiveEndOffset)
        let lineStarts = selectedLineStarts(
            for: normalizedRange,
            effectiveEndOffset: effectiveEndOffset,
            from: allLineStarts
        )
        let operations = lineStarts.compactMap { lineStart in
            operation(for: lineStart, direction: direction, in: body)
        }

        guard !operations.isEmpty else { return nil }

        var updatedBody = body
        for operation in operations.reversed() {
            updatedBody.replaceSubrange(operation.range, with: operation.replacement)
        }

        return Result(
            body: updatedBody,
            selectedRange: updatedRange(normalizedRange, applying: operations)
        )
    }

    private static func operation(
        for lineStart: LineStart,
        direction: Direction,
        in body: String
    ) -> Operation? {
        let index = lineStart.index

        switch direction {
        case .indent:
            return Operation(
                range: index..<index,
                location: lineStart.location,
                replacedLength: 0,
                replacement: indentationUnit
            )
        case .outdent:
            guard index < body.endIndex else { return nil }

            if body[index...].hasPrefix(indentationUnit) {
                let end = body.index(index, offsetBy: indentationUnit.count)
                return Operation(
                    range: index..<end,
                    location: lineStart.location,
                    replacedLength: indentationUnit.utf16.count,
                    replacement: ""
                )
            }

            if body[index] == "\t" {
                let end = body.index(after: index)
                return Operation(
                    range: index..<end,
                    location: lineStart.location,
                    replacedLength: "\t".utf16.count,
                    replacement: ""
                )
            }

            if body[index] == " " {
                let end = body.index(after: index)
                return Operation(
                    range: index..<end,
                    location: lineStart.location,
                    replacedLength: " ".utf16.count,
                    replacement: ""
                )
            }

            return nil
        }
    }

    private static func selectedLineStarts(
        for range: NSRange,
        effectiveEndOffset: Int,
        from lineStarts: [LineStart]
    ) -> ArraySlice<LineStart> {
        let firstLineIndex = lineStartIndex(containingUTF16Offset: range.location, in: lineStarts)
        let lastLineIndex = lineStartIndex(containingUTF16Offset: effectiveEndOffset, in: lineStarts)

        return lineStarts[firstLineIndex...lastLineIndex]
    }

    private static func updatedRange(_ range: NSRange, applying operations: [Operation]) -> NSRange {
        let isCollapsed = range.length == 0
        var location = range.location
        var end = range.location + range.length

        for operation in operations {
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

    private static func effectiveEndOffset(for range: NSRange) -> Int {
        if range.length > 0 {
            max(range.location, range.location + range.length - 1)
        } else {
            range.location
        }
    }

    private static func lineStarts(in text: String, throughUTF16Offset limit: Int) -> [LineStart] {
        let clampedLimit = min(max(limit, 0), text.utf16.count)
        var starts = [LineStart(index: text.startIndex, location: 0)]
        guard clampedLimit > 0 else { return starts }

        var currentIndex = text.startIndex
        var currentOffset = 0

        while currentIndex < text.endIndex {
            let nextIndex = text.index(after: currentIndex)
            currentOffset += text[currentIndex..<nextIndex].utf16.count

            if text[currentIndex] == "\n" {
                starts.append(LineStart(index: nextIndex, location: currentOffset))
            }

            currentIndex = nextIndex

            if currentOffset >= clampedLimit {
                break
            }
        }

        return starts
    }

    private static func lineStartIndex(containingUTF16Offset offset: Int, in lineStarts: [LineStart]) -> Int {
        var lowerBound = 0
        var upperBound = lineStarts.count

        while lowerBound < upperBound {
            let middleIndex = (lowerBound + upperBound) / 2
            if lineStarts[middleIndex].location <= offset {
                lowerBound = middleIndex + 1
            } else {
                upperBound = middleIndex
            }
        }

        return max(0, lowerBound - 1)
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
}
