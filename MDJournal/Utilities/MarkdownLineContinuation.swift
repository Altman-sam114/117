import Foundation

struct MarkdownLineContinuation {
    struct Result: Equatable {
        let body: String
        let selectedRange: NSRange
    }

    private struct LinePrefix {
        let continuation: String
        let removableRange: Range<String.Index>
        let contentBeforeCursor: Substring
    }

    static func apply(
        to body: String,
        selectedRange: NSRange,
        replacementText: String
    ) -> Result? {
        guard replacementText == "\n" else { return nil }

        let normalizedRange = clampedNSRange(selectedRange, in: body)
        guard normalizedRange.length == 0 else { return nil }

        let cursor = index(atOrBeforeUTF16Offset: normalizedRange.location, in: body)
        let currentLineStart = lineStart(before: cursor, in: body)
        guard !isInsideFencedCodeBlock(before: currentLineStart, in: body) else { return nil }

        let currentLineEnd = lineEnd(after: cursor, in: body)
        let currentLinePrefix = body[currentLineStart..<cursor]
        guard let continuationPrefix = continuationPrefix(in: currentLinePrefix) else { return nil }

        let lineSuffix = body[cursor..<currentLineEnd]
        if isEmptyContinuationLine(prefix: continuationPrefix, lineSuffix: lineSuffix) {
            return removingContinuationPrefix(continuationPrefix, from: body)
        }

        return continuingLine(
            with: continuationPrefix.continuation,
            in: body,
            at: cursor
        )
    }

    private static func continuationPrefix(in linePrefix: Substring) -> LinePrefix? {
        var markerStart = linePrefix.startIndex
        while markerStart < linePrefix.endIndex {
            let character = linePrefix[markerStart]
            guard character == " " || character == "\t" else { break }
            markerStart = linePrefix.index(after: markerStart)
        }

        let indentation = String(linePrefix[..<markerStart])
        let rest = linePrefix[markerStart...]

        if isChecklistPrefix(rest) {
            let markerEnd = linePrefix.index(markerStart, offsetBy: 6)
            return LinePrefix(
                continuation: "\(indentation)- [ ] ",
                removableRange: linePrefix.startIndex..<markerEnd,
                contentBeforeCursor: linePrefix[markerEnd...]
            )
        }

        if rest.hasPrefix("> ") {
            let markerEnd = linePrefix.index(markerStart, offsetBy: 2)
            return LinePrefix(
                continuation: "\(indentation)> ",
                removableRange: linePrefix.startIndex..<markerEnd,
                contentBeforeCursor: linePrefix[markerEnd...]
            )
        }

        if let orderedListPrefix = orderedListPrefix(
            in: linePrefix,
            markerStart: markerStart,
            indentation: indentation
        ) {
            return orderedListPrefix
        }

        guard let marker = rest.first, marker == "-" || marker == "*" || marker == "+" else {
            return nil
        }

        let spaceIndex = rest.index(after: rest.startIndex)
        guard spaceIndex < rest.endIndex, rest[spaceIndex] == " " else {
            return nil
        }

        let markerEnd = rest.index(after: spaceIndex)
        return LinePrefix(
            continuation: "\(indentation)\(marker) ",
            removableRange: linePrefix.startIndex..<markerEnd,
            contentBeforeCursor: linePrefix[markerEnd...]
        )
    }

    private static func orderedListPrefix(
        in linePrefix: Substring,
        markerStart: String.Index,
        indentation: String
    ) -> LinePrefix? {
        var numberEnd = markerStart
        while numberEnd < linePrefix.endIndex, linePrefix[numberEnd].isNumber {
            numberEnd = linePrefix.index(after: numberEnd)
        }

        guard numberEnd > markerStart,
              numberEnd < linePrefix.endIndex,
              linePrefix[numberEnd] == "."
        else {
            return nil
        }

        let spaceIndex = linePrefix.index(after: numberEnd)
        guard spaceIndex < linePrefix.endIndex, linePrefix[spaceIndex] == " " else {
            return nil
        }

        let numberText = String(linePrefix[markerStart..<numberEnd])
        guard let number = Int(numberText), number < Int.max else {
            return nil
        }

        let markerEnd = linePrefix.index(after: spaceIndex)
        return LinePrefix(
            continuation: "\(indentation)\(number + 1). ",
            removableRange: linePrefix.startIndex..<markerEnd,
            contentBeforeCursor: linePrefix[markerEnd...]
        )
    }

    private static func isChecklistPrefix(_ text: Substring) -> Bool {
        text.hasPrefix("- [ ] ") || text.hasPrefix("- [x] ") || text.hasPrefix("- [X] ")
    }

    private static func isEmptyContinuationLine(prefix: LinePrefix, lineSuffix: Substring) -> Bool {
        isWhitespaceOnly(prefix.contentBeforeCursor) && isWhitespaceOnly(lineSuffix)
    }

    private static func isWhitespaceOnly(_ text: Substring) -> Bool {
        var currentIndex = text.startIndex
        while currentIndex < text.endIndex {
            guard text[currentIndex].isHorizontalWhitespace else {
                return false
            }
            currentIndex = text.index(after: currentIndex)
        }
        return true
    }

    private static func removingContinuationPrefix(_ prefix: LinePrefix, from body: String) -> Result {
        let selectedLocation = NSRange(body.startIndex..<prefix.removableRange.lowerBound, in: body).length
        var updatedBody = body
        updatedBody.replaceSubrange(prefix.removableRange, with: "")

        return Result(
            body: updatedBody,
            selectedRange: NSRange(location: selectedLocation, length: 0)
        )
    }

    private static func continuingLine(
        with continuation: String,
        in body: String,
        at cursor: String.Index
    ) -> Result {
        let insertionLocation = NSRange(body.startIndex..<cursor, in: body).length
        let replacement = "\n\(continuation)"
        var updatedBody = body
        updatedBody.replaceSubrange(cursor..<cursor, with: replacement)

        return Result(
            body: updatedBody,
            selectedRange: NSRange(
                location: insertionLocation + replacement.utf16.count,
                length: 0
            )
        )
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

    private static func lineEnd(after index: String.Index, in text: String) -> String.Index {
        var currentIndex = index
        while currentIndex < text.endIndex {
            guard text[currentIndex] != "\n" else { break }
            currentIndex = text.index(after: currentIndex)
        }
        return currentIndex
    }

    private static func isInsideFencedCodeBlock(before lineStart: String.Index, in text: String) -> Bool {
        var isInsideFence = false

        var currentLineStart = text.startIndex
        var currentIndex = text.startIndex

        while currentIndex < lineStart {
            if text[currentIndex] == "\n" {
                if lineStartsFence(text[currentLineStart..<currentIndex]) {
                    isInsideFence.toggle()
                }

                currentIndex = text.index(after: currentIndex)
                currentLineStart = currentIndex
            } else {
                currentIndex = text.index(after: currentIndex)
            }
        }

        if currentLineStart < lineStart,
           lineStartsFence(text[currentLineStart..<lineStart]) {
            isInsideFence.toggle()
        }

        return isInsideFence
    }

    private static func lineStartsFence(_ line: Substring) -> Bool {
        var markerStart = line.startIndex
        while markerStart < line.endIndex {
            guard line[markerStart].isHorizontalWhitespace else { break }
            markerStart = line.index(after: markerStart)
        }

        return line[markerStart...].hasPrefix("```")
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

private extension Character {
    var isHorizontalWhitespace: Bool {
        unicodeScalars.allSatisfy { CharacterSet.whitespaces.contains($0) }
    }
}
