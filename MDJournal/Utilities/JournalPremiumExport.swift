import CoreText
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum JournalPremiumExportFormat: String, CaseIterable, Identifiable {
    case markdown = "Markdown 日记集"
    case pdf = "分页 PDF 日记集"

    var id: String { rawValue }
    var contentType: UTType {
        switch self {
        case .markdown: return UTType(filenameExtension: "md") ?? .plainText
        case .pdf: return .pdf
        }
    }
}

struct JournalPremiumExportSelection {
    var startDate: Date?
    var endDate: Date?
    var category: JournalEntry.Category?

    func entries(from entries: [JournalEntry], calendar: Calendar = .current) -> [JournalEntry] {
        let start = startDate.map { calendar.startOfDay(for: $0) }
        let end = endDate.flatMap {
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))
        }
        return entries.filter { entry in
            (start.map { entry.createdAt >= $0 } ?? true)
                && (end.map { entry.createdAt < $0 } ?? true)
                && (category.map { entry.category == $0 } ?? true)
        }.sorted {
            if $0.createdAt == $1.createdAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.createdAt < $1.createdAt
        }
    }
}

struct JournalPremiumPDFOptions: Equatable, Sendable {
    var includesCover = false
    var title = "我的日记集"

    var displayTitle: String {
        let cleaned = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return cleaned.isEmpty ? "我的日记集" : String(cleaned.prefix(80))
    }
}

struct JournalPremiumExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf, .plainText, UTType(filenameExtension: "md") ?? .plainText] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum JournalPremiumExportError: LocalizedError {
    case emptySelection
    case cannotCreatePDF
    case paginationFailed

    var errorDescription: String? {
        switch self {
        case .emptySelection: return "当前日期与分类下没有可导出的日记。"
        case .cannotCreatePDF: return "无法创建 PDF，请稍后重试。"
        case .paginationFailed: return "文字排版未能完成，请改用 Markdown 导出。"
        }
    }
}

actor JournalPremiumExportBuilder {
    func build(
        entries: [JournalEntry], format: JournalPremiumExportFormat,
        pdfOptions: JournalPremiumPDFOptions = JournalPremiumPDFOptions()
    ) throws -> Data {
        guard !entries.isEmpty else { throw JournalPremiumExportError.emptySelection }
        try Task.checkCancellation()
        switch format {
        case .markdown: return try Self.markdownData(entries: entries)
        case .pdf: return try Self.pdf(entries: entries, options: pdfOptions)
        }
    }

    static func markdown(entries: [JournalEntry]) -> String {
        entries.map { entry in
            "# \(entry.displayTitle)\n\n\(metadata(for: entry))\n\n\(entry.body)"
        }.joined(separator: "\n\n---\n\n") + "\n"
    }

    private static func markdownData(entries: [JournalEntry]) throws -> Data {
        var output = Data()
        for (index, entry) in entries.enumerated() {
            if index > 0 { try appendUTF8("\n\n---\n\n", to: &output) }
            try appendUTF8("# \(entry.displayTitle)\n\n\(metadata(for: entry))\n\n", to: &output)
            try appendUTF8(entry.body, to: &output)
        }
        try appendUTF8("\n", to: &output)
        return output
    }

    private static func appendUTF8(_ string: String, to output: inout Data) throws {
        let bytes = string.utf8
        var position = bytes.startIndex
        while position != bytes.endIndex {
            try Task.checkCancellation()
            let next = bytes.index(position, offsetBy: 65_536, limitedBy: bytes.endIndex) ?? bytes.endIndex
            output.append(contentsOf: bytes[position..<next])
            position = next
        }
    }

    private static func metadata(for entry: JournalEntry) -> String {
        let date = entry.createdAt.formatted(date: .abbreviated, time: .omitted)
        return "\(date) · \(entry.category.rawValue) · \(entry.mood.rawValue)"
    }

    private static func pdf(entries: [JournalEntry], options: JournalPremiumPDFOptions) throws -> Data {
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else {
            throw JournalPremiumExportError.cannotCreatePDF
        }
        var page = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let context = CGContext(consumer: consumer, mediaBox: &page, [kCGPDFContextTitle: options.displayTitle] as CFDictionary) else {
            throw JournalPremiumExportError.cannotCreatePDF
        }
        let font = CTFontCreateWithName("PingFangSC-Regular" as CFString, 12, nil)
        let headingFont = CTFontCreateWithName("PingFangSC-Semibold" as CFString, 19, nil)
        let textColor = CGColor(gray: 0.12, alpha: 1)
        let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
        let colorKey = NSAttributedString.Key(kCTForegroundColorAttributeName as String)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            fontKey: font, colorKey: textColor, .paragraphStyle: paragraphStyle
        ]
        let bodyRect = CGRect(x: 48, y: 52, width: page.width - 96, height: page.height - 104)
        var pageNumber = 1
        do {
            if options.includesCover {
                try Task.checkCancellation()
                drawCover(in: context, page: page, entries: entries, title: options.displayTitle)
            }
            for entry in entries {
                try Task.checkCancellation()
                // Keep layout storage bounded to one entry; each new entry begins on a fresh page.
                try autoreleasepool {
                    let text = NSMutableAttributedString(
                        string: entry.displayTitle + "\n\n", attributes: [fontKey: headingFont, colorKey: textColor]
                    )
                    text.append(NSAttributedString(string: Self.metadata(for: entry) + "\n\n", attributes: bodyAttributes))
                    text.append(NSAttributedString(string: entry.body, attributes: bodyAttributes))
                    text.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
                    let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
                    var offset = 0
                    while offset < text.length {
                        try Task.checkCancellation()
                        let visibleLength = try autoreleasepool {
                            context.beginPDFPage(nil)
                            context.saveGState()
                            defer { context.restoreGState(); context.endPDFPage() }
                            context.textMatrix = .identity
                            let frame = CTFramesetterCreateFrame(
                                framesetter, CFRange(location: offset, length: 0),
                                CGPath(rect: bodyRect, transform: nil), nil
                            )
                            let visible = CTFrameGetVisibleStringRange(frame)
                            guard visible.length > 0 else { throw JournalPremiumExportError.paginationFailed }
                            CTFrameDraw(frame, context)
                            let footer = NSAttributedString(string: "MD Journal · \(pageNumber)", attributes: [fontKey: font, colorKey: textColor])
                            let line = CTLineCreateWithAttributedString(footer as CFAttributedString)
                            context.textPosition = CGPoint(x: 48, y: 28)
                            CTLineDraw(line, context)
                            return visible.length
                        }
                        offset += visibleLength
                        pageNumber += 1
                    }
                }
            }
        } catch {
            context.closePDF()
            throw error
        }
        context.closePDF()
        return output as Data
    }

    private static func drawCover(in context: CGContext, page: CGRect, entries: [JournalEntry], title: String) {
        context.beginPDFPage(nil)
        context.saveGState()
        defer { context.restoreGState(); context.endPDFPage() }
        context.setFillColor(CGColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1))
        context.fill(page)
        let accent = CGColor(red: 0.13, green: 0.32, blue: 0.26, alpha: 1)
        context.setFillColor(accent)
        context.fill(CGRect(x: 56, y: 606, width: 48, height: 3))
        context.textMatrix = .identity

        func draw(_ string: String, size: CGFloat, rect: CGRect, color: CGColor) {
            let font = CTFontCreateWithName("PingFangSC-Regular" as CFString, size, nil)
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 8
            let text = NSAttributedString(string: string, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
                .paragraphStyle: style
            ])
            let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGPath(rect: rect, transform: nil), nil)
            CTFrameDraw(frame, context)
        }

        draw("MD JOURNAL / 私人日记集", size: 11, rect: CGRect(x: 56, y: 638, width: 480, height: 30), color: accent)
        draw(title, size: 30, rect: CGRect(x: 56, y: 300, width: 483, height: 278), color: CGColor(gray: 0.12, alpha: 1))
        let dates = entries.map(\.createdAt)
        let first = dates.min()?.formatted(date: .abbreviated, time: .omitted) ?? ""
        let last = dates.max()?.formatted(date: .abbreviated, time: .omitted) ?? ""
        let range = first == last ? first : "\(first) — \(last)"
        draw("\(range)\n\(entries.count) 篇记录 · 按日珍藏", size: 12, rect: CGRect(x: 56, y: 160, width: 483, height: 90), color: accent)
        draw("留给自己的文字，请妥善保管。", size: 10, rect: CGRect(x: 56, y: 48, width: 483, height: 32), color: CGColor(gray: 0.4, alpha: 1))
    }
}
