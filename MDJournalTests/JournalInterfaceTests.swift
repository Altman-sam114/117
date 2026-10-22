import SwiftUI
import UIKit
import XCTest
@testable import MDJournal

final class JournalInterfaceTests: XCTestCase {
    func testLowHeightChromeUsesOneToolRowAndCompactTitle() {
        for height: CGFloat in [200, 260, 320, 399] {
            XCTAssertTrue(EntryEditorChromeLayout.isCompactHeight(height))
            XCTAssertTrue(EntryEditorChromeLayout.usesInlineTools(
                availableWidth: 844, availableHeight: height, dynamicTypeSize: .large
            ))
            let header = EntryEditorChromeLayout.headerHeight(
                availableHeight: height, showsDetails: false, dynamicTypeSize: .large
            )
            XCTAssertLessThanOrEqual(header, 52)
            XCTAssertGreaterThan(height - header - 48, height * 0.5)
        }
        XCTAssertFalse(EntryEditorChromeLayout.isCompactHeight(400))
        XCTAssertFalse(EntryEditorChromeLayout.usesInlineTools(
            availableWidth: 820, availableHeight: 720, dynamicTypeSize: .large
        ))
        XCTAssertTrue(EntryEditorChromeLayout.usesInlineTools(
            availableWidth: 390, availableHeight: 720, dynamicTypeSize: .large
        ))
        XCTAssertTrue(EntryEditorChromeLayout.usesInlineTools(
            availableWidth: 1440, availableHeight: 720, dynamicTypeSize: .accessibility1
        ))
    }

    func testCanvasFitsItsViewportAndPreservesNarrowWritingSpace() {
        for width: CGFloat in [320, 390, 819, 820, 1119, 1120, 1440] {
            for height: CGFloat in [260, 320, 720, 900] {
                for size: DynamicTypeSize in [.large, .accessibility3] {
                    let layout = EntryEditorLayoutContract(width: width, dynamicTypeSize: size)
                    let canvas = EntryEditorCanvasLayout(
                        width: width, height: height, dynamicTypeSize: size,
                        usesSplitPreview: layout.usesSplitPreview
                    )
                    XCTAssertGreaterThan(canvas.paperWidth, 0)
                    XCTAssertGreaterThan(canvas.paperHeight, 0)
                    XCTAssertLessThanOrEqual(canvas.paperWidth + canvas.horizontalInset * 2, width)
                    XCTAssertEqual(canvas.paperHeight + canvas.verticalInset * 2, height)
                    if width < 820 || height < 400 || size.isAccessibilitySize {
                        XCTAssertEqual(canvas.paperWidth, width)
                        XCTAssertEqual(canvas.paperHeight, height)
                    } else {
                        XCTAssertLessThan(canvas.paperWidth, width)
                        XCTAssertLessThan(canvas.paperHeight, height)
                    }
                    if layout.usesSplitPreview {
                        XCTAssertGreaterThan((canvas.paperWidth - 1) / 2, 500)
                    }
                }
            }
        }
    }

    @MainActor
    func testBodyFontTracksSwiftUIDynamicTypeAndRetainsMatchingFont() throws {
        let textView = UITextView()
        for size: DynamicTypeSize in [.large, .xxxLarge, .accessibility1, .accessibility3, .accessibility5] {
            let category = MarkdownBodyTextView.contentSizeCategory(for: size)
            MarkdownBodyTextView.configureBodyFontIfNeeded(textView, category: category)
            let font = try XCTUnwrap(textView.font)
            let expected = UIFont.preferredFont(
                forTextStyle: .body, compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
            )
            XCTAssertEqual(font.pointSize, expected.pointSize)
            MarkdownBodyTextView.configureBodyFontIfNeeded(textView, category: category)
            XCTAssertTrue(textView.font === font)
        }
        XCTAssertGreaterThan(try XCTUnwrap(textView.font).pointSize, 40)
    }

    @MainActor
    func testTitleInputIdentitySurvivesCompactHeightTransition() async throws {
        let entry = JournalEntry.starterEntry()
        let controller = UIHostingController(rootView: EntryEditorView(entry: .constant(entry), bodyPresentation: JournalEntryBodyPresentation(body: entry.body)))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 844, height: 720))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        let original = try XCTUnwrap(titleInput(in: controller.view, title: entry.title))

        for height: CGFloat in [320, 720] {
            window.frame.size.height = height
            controller.view.frame = window.bounds
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(150))
            let current = try XCTUnwrap(titleInput(in: controller.view, title: entry.title))
            XCTAssertTrue(original === current, "Height changes must preserve the title input")
        }
    }

    @MainActor
    private func titleInput(in view: UIView, title: String) -> UIView? {
        if let input = view as? UITextField, input.text == title { return input }
        if let input = view as? UITextView, input.text == title { return input }
        for child in view.subviews {
            if let input = titleInput(in: child, title: title) { return input }
        }
        return nil
    }

    @MainActor
    func testBodyInputAndUTF16SelectionSurviveSingleAndSplitWidthTransitions() async throws {
        let entry = reviewEntries()[0]
        let controller = UIHostingController(rootView: EntryEditorView(entry: .constant(entry), bodyPresentation: JournalEntryBodyPresentation(body: entry.body)))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 980, height: 900))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        let original = try XCTUnwrap(bodyInput(in: controller.view, text: entry.body))
        XCTAssertTrue(original.becomeFirstResponder())
        let selectedRange = (entry.body as NSString).range(of: "河边")
        XCTAssertNotEqual(selectedRange.location, NSNotFound)
        original.selectedRange = selectedRange
        try await Task.sleep(for: .milliseconds(150))

        for width: CGFloat in [1240, 980, 1440, 980] {
            window.frame.size.width = width
            controller.view.frame = window.bounds
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(150))
            let current = try XCTUnwrap(bodyInput(in: controller.view, text: entry.body))
            XCTAssertTrue(original === current, "Width changes must preserve the production body input")
            XCTAssertEqual(current.selectedRange, selectedRange)
            XCTAssertTrue(current.isFirstResponder)
        }
    }

    @MainActor
    private func bodyInput(in view: UIView, text: String) -> UITextView? {
        if let input = view as? UITextView, input.text == text { return input }
        for child in view.subviews {
            if let input = bodyInput(in: child, text: text) { return input }
        }
        return nil
    }

    func testHeaderBudgetKeepsMostOfTheViewportForWriting() {
        for height: CGFloat in [0, 260, 390, 720, 1000] {
            for size: DynamicTypeSize in [.large, .xxxLarge, .accessibility1, .accessibility5] {
                for expanded in [false, true] {
                    let header = EntryEditorChromeLayout.headerHeight(
                        availableHeight: height, showsDetails: expanded, dynamicTypeSize: size
                    )
                    XCTAssertGreaterThanOrEqual(header, 0)
                    XCTAssertLessThanOrEqual(header, height * 0.38)
                }
            }
        }
        XCTAssertLessThan(
            EntryEditorChromeLayout.headerHeight(availableHeight: 720, showsDetails: false, dynamicTypeSize: .large),
            EntryEditorChromeLayout.headerHeight(availableHeight: 720, showsDetails: true, dynamicTypeSize: .large)
        )
    }

    func testDashboardUsesOneColumnAtNarrowWidthsAndAccessibilitySizes() {
        XCTAssertEqual(JournalDashboardLayout.columnCount(width: 390, dynamicTypeSize: .large), 1)
        XCTAssertEqual(JournalDashboardLayout.columnCount(width: 819, dynamicTypeSize: .large), 1)
        XCTAssertEqual(JournalDashboardLayout.columnCount(width: 820, dynamicTypeSize: .large), 2)
        for size: DynamicTypeSize in [.accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5] {
            XCTAssertEqual(JournalDashboardLayout.columnCount(width: 1440, dynamicTypeSize: size), 1)
        }
    }

    @MainActor
    func testSemanticColorsArePackagedForEveryAppearance() throws {
        for name in ["JournalCanvas", "JournalPaper", "JournalInset", "JournalAccent", "JournalSeparator"] {
            let color = try XCTUnwrap(UIColor(named: name), "Missing asset: \(name)")
            for style in [UIUserInterfaceStyle.light, .dark] {
                for contrast in [UIAccessibilityContrast.normal, .high] {
                    let traits = UITraitCollection(traitsFrom: [
                        UITraitCollection(userInterfaceStyle: style),
                        UITraitCollection(accessibilityContrast: contrast)
                    ])
                    XCTAssertEqual(color.resolvedColor(with: traits).cgColor.alpha, 1)
                }
            }
        }
    }

    /// Review attachments are real SwiftUI renders on the CI simulator, not interaction tests.
    @MainActor
    func testRenderInterfaceReviewSheets() async throws {
        let entries = reviewEntries()
        let entry = entries[0]
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mdjournal-interface-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let storageURL = temporaryDirectory.appendingPathComponent("entries.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(entries).write(to: storageURL, options: .atomic)
        let store = JournalStore(storageURL: storageURL)
        XCTAssertEqual(store.entries.count, entries.count)
        XCTAssertEqual(store.revision, 0, "Render fixtures must load without writing user data")

        // These are iOS regular-width production renders, not Mac window screenshots.
        try await render(
            ContentView(store: store).environment(\.horizontalSizeClass, .regular),
            name: "content-1360x860-light-regular", size: CGSize(width: 1360, height: 860)
        )
        try await render(
            ContentView(store: store).environment(\.horizontalSizeClass, .regular),
            name: "content-1120x720-light-regular", size: CGSize(width: 1120, height: 720)
        )
        try await render(
            EntryEditorView(entry: .constant(entry), bodyPresentation: JournalEntryBodyPresentation(body: entry.body)),
            name: "editor-1440x900-light-split", size: CGSize(width: 1440, height: 900)
        )
        try await render(
            EntryEditorView(entry: .constant(entry), bodyPresentation: JournalEntryBodyPresentation(body: entry.body)),
            name: "editor-390x720-light", size: CGSize(width: 390, height: 720)
        )
        try await render(
            EntryEditorView(entry: .constant(entry), bodyPresentation: JournalEntryBodyPresentation(body: entry.body)),
            name: "editor-390x720-dark", size: CGSize(width: 390, height: 720), dark: true
        )
        try await render(
            EntryEditorView(entry: .constant(entry), bodyPresentation: JournalEntryBodyPresentation(body: entry.body)),
            name: "editor-844x320-light-compact", size: CGSize(width: 844, height: 320)
        )
        try await render(
            EntryEditorView(entry: .constant(entry), bodyPresentation: JournalEntryBodyPresentation(body: entry.body)),
            name: "editor-390x720-light-accessibility3", size: CGSize(width: 390, height: 720), typeSize: .accessibility3
        )
        let library = EntryListView(
            overviewSnapshot: JournalListOverviewSnapshot(
                entries: entries, bodyPresentations: store.bodyPresentations, calendar: reviewCalendar, now: reviewDate("2026-10-22T12:00:00Z")
            ),
            snapshot: JournalEntryListSnapshot(entries: entries, searchText: "", selectedCategory: nil),
            bodyPresentations: store.bodyPresentations,
            selection: .constant(entry.id), searchText: .constant(""), selectedCategory: .constant(nil),
            onCreate: {}, onDelete: { _ in }, onShowStatistics: {}
        )
        try await render(library, name: "library-320x900-light", size: CGSize(width: 320, height: 900))
        try await render(
            library, name: "library-320x900-light-history", size: CGSize(width: 320, height: 900),
            scrollToBottom: true
        )
        try await render(
            library, name: "library-320x900-light-accessibility3", size: CGSize(width: 320, height: 900),
            typeSize: .accessibility3
        )
        try await render(
            StatisticsDashboardView(entries: entries, bodyPresentations: store.bodyPresentations),
            name: "statistics-1100x900-light", size: CGSize(width: 1100, height: 900)
        )
    }

    private var reviewCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func reviewDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func reviewEntries() -> [JournalEntry] {
        let records: [(String, String, JournalEntry.Category, JournalEntry.Mood)] = [
            ("把普通的一天慢慢写下来：河边散步、读书，还有新的念头 📝", "2026-10-22T12:00:00Z", .daily, .calm),
            ("把步子放慢一点", "2026-10-18T12:00:00Z", .health, .happy),
            ("工作台上的小发现", "2026-09-28T12:00:00Z", .workStudy, .focused),
            ("周末去看海 🌊", "2026-09-12T12:00:00Z", .travel, .happy),
            ("九月之前，整理书桌", "2026-08-31T12:00:00Z", .inspiration, .tired),
            ("去年的今天", "2025-10-22T12:00:00Z", .daily, .calm),
            ("一段值得回看的文字", "2025-10-03T12:00:00Z", .inspiration, .focused),
            ("秋雨", "2025-09-10T12:00:00Z", .daily, .rainy)
        ]
        return records.enumerated().map { index, record in
            JournalEntry(
                id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", index + 1))!,
                title: record.0,
                body: """
                ### 今天的片刻

                下午走到河边，风把树叶吹得很轻。📝 先记下一个细节，再让想法慢慢展开。
                一段中文和 a few English words 放在同一页，读起来仍然从容。

                ### 值得记住

                - 留一点时间给自己
                - **认真完成**手边的小事

                > 日子不必很特别，也值得留下。

                ### 明天的小事

                - [ ] 读完手边的书
                - [x] 给朋友回一封信

                1. 整理想法
                2. 从一件小事开始
                """,
                createdAt: reviewDate(record.1), updatedAt: reviewDate(record.1),
                category: record.2, mood: record.3
            )
        }
    }

    @MainActor
    private func render<Content: View>(
        _ content: Content, name: String, size: CGSize,
        dark: Bool = false, typeSize: DynamicTypeSize = .large, scrollToBottom: Bool = false
    ) async throws {
        let controller = UIHostingController(rootView: content
            .environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.dynamicTypeSize, typeSize)
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .environment(\.calendar, reviewCalendar)
            .environment(\.timeZone, reviewCalendar.timeZone))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        controller.view.layoutIfNeeded()
        if scrollToBottom {
            let scrollView = try XCTUnwrap(scrollableList(in: controller.view))
            scrollView.setContentOffset(CGPoint(
                x: 0, y: max(-scrollView.adjustedContentInset.top,
                             scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
            ), animated: false)
            try await Task.sleep(for: .milliseconds(150))
            controller.view.layoutIfNeeded()
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        var didDraw = false
        let image = renderer.image { _ in
            didDraw = controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        XCTAssertTrue(didDraw, "Unable to render \(name)")
        XCTAssertEqual(image.size, size)
        let attachment = XCTAttachment(image: image)
        attachment.name = "review-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func scrollableList(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView, scrollView.contentSize.height > scrollView.bounds.height {
            return scrollView
        }
        for child in view.subviews {
            if let scrollView = scrollableList(in: child) { return scrollView }
        }
        return nil
    }
}
