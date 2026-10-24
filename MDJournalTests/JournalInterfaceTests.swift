import SwiftUI
import UIKit
import XCTest
@testable import MDJournal

final class JournalInterfaceTests: XCTestCase {
    @MainActor
    func testCompactProductionNavigationLinkOpensPopsAndReopensTheSameEntry() async throws {
        let entries = Array(reviewEntries().prefix(2))
        let fixture = try makeNavigationStore(entries: entries)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let controller = UIHostingController(rootView: ContentView(store: fixture.store)
            .environment(\.horizontalSizeClass, .compact))
        let size = CGSize(width: 390, height: 844)
        let window = makeWindow(controller: controller, size: size)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await waitForHost("Compact ContentView must show its library first") {
            self.navigationController(in: controller)?.viewControllers.count == 1
        }
        XCTAssertNil(bodyInput(in: controller.view, text: entries[0].body))
        try attachHostImage(controller.view, name: "content-390x844-compact-library", size: size)

        try await activateFirstProductionEntry(in: controller.view)
        try await waitForHost("A production NavigationLink must push the selected editor") {
            self.navigationController(in: controller)?.viewControllers.count == 2
                && self.titleInput(in: controller.view, title: entries[0].title) != nil
                && self.bodyInput(in: controller.view, text: entries[0].body) != nil
        }
        try attachHostImage(controller.view, name: "content-390x844-compact-detail", size: size)
        let navigation = try XCTUnwrap(navigationController(in: controller))
        XCTAssertFalse(navigation.navigationBar.isHidden)
        XCTAssertFalse(try XCTUnwrap(navigation.topViewController).navigationItem.hidesBackButton)
        navigation.popViewController(animated: false)
        try await waitForHost("System pop must return to the library") {
            navigation.viewControllers.count == 1
                && self.bodyInput(in: controller.view, text: entries[0].body) == nil
        }
        try await activateFirstProductionEntry(in: controller.view)
        try await waitForHost("The same selected row must remain openable after pop") {
            navigation.viewControllers.count == 2
                && self.titleInput(in: controller.view, title: entries[0].title) != nil
        }
        XCTAssertEqual(fixture.store.entries, entries)
        XCTAssertEqual(fixture.store.revision, 0, "Navigation must not mutate persisted journals")
    }

    @MainActor
    func testCompactProductionCreateClearsBlockingFiltersAndShowsTheCreatedID() async throws {
        let entries = Array(reviewEntries().prefix(2))
        let fixture = try makeNavigationStore(entries: entries)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        var interaction: JournalContentInteraction?
        let controller = UIHostingController(rootView: ContentView(
            store: fixture.store, interactionObserver: { interaction = $0 }
        ).environment(\.horizontalSizeClass, .compact))
        let window = makeWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await waitForHost("Production ContentView must publish its installed actions") { interaction != nil }
        let actions = try XCTUnwrap(interaction)
        actions.searchText.wrappedValue = "a search that matches no journal"
        actions.selectedCategory.wrappedValue = .travel
        try await waitForHost("Filtering must not push a detail") {
            actions.compactPath.wrappedValue.isEmpty
                && self.navigationController(in: controller)?.viewControllers.count == 1
        }

        actions.createEntry()
        try await waitForHost("The production create action must open a new journal") {
            fixture.store.entries.count == entries.count + 1
                && self.navigationController(in: controller)?.viewControllers.count == 2
        }
        let created = try XCTUnwrap(fixture.store.entries.first)
        XCTAssertFalse(entries.contains { $0.id == created.id })
        XCTAssertEqual(actions.compactPath.wrappedValue, [created.id])
        XCTAssertEqual(actions.searchText.wrappedValue, "")
        XCTAssertNil(actions.selectedCategory.wrappedValue)
        XCTAssertNotNil(titleInput(in: controller.view, title: created.title))
        XCTAssertNotNil(bodyInput(in: controller.view, text: created.body))
        await fixture.store.flushPendingSave()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let saved = try decoder.decode([JournalEntry].self, from: Data(contentsOf: fixture.storageURL))
        XCTAssertEqual(saved.first?.id, created.id)
        XCTAssertEqual(saved.count, entries.count + 1)
    }

    @MainActor
    func testProductionNavigationRepairsFilteredAndDeletedSelectionsAcrossSizeClasses() async throws {
        let entries = Array(reviewEntries().prefix(2))
        let fixture = try makeNavigationStore(entries: entries)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let configuration = NavigationHostConfiguration()
        var interaction: JournalContentInteraction?
        let controller = UIHostingController(rootView: NavigationHostRoot(
            store: fixture.store, configuration: configuration, observer: { interaction = $0 }
        ))
        let window = makeWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await waitForHost("Production navigation actions must be installed") { interaction != nil }
        let actions = try XCTUnwrap(interaction)
        actions.compactPath.wrappedValue = [entries[0].id]
        try await waitForHost("A bound compact destination must show the real editor") {
            self.bodyInput(in: controller.view, text: entries[0].body) != nil
        }

        configuration.sizeClass = .regular
        window.frame.size = CGSize(width: 1360, height: 860)
        controller.view.frame = window.bounds
        try await waitForHost("Regular ContentView must retain the current journal in its split view") {
            self.splitController(in: controller) != nil
                && self.titleInput(in: controller.view, title: entries[0].title) != nil
        }
        configuration.sizeClass = .compact
        window.frame.size = CGSize(width: 390, height: 844)
        controller.view.frame = window.bounds
        try await waitForHost("Returning to compact width must retain the selected destination") {
            self.navigationController(in: controller)?.viewControllers.count == 2
                && self.titleInput(in: controller.view, title: entries[0].title) != nil
        }
        XCTAssertEqual(fixture.store.revision, 0)

        actions.searchText.wrappedValue = "a search that matches no journal"
        try await waitForHost("An empty visible result must remove an invalid detail") {
            actions.compactPath.wrappedValue.isEmpty
                && self.navigationController(in: controller)?.viewControllers.count == 1
        }
        actions.searchText.wrappedValue = ""
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(actions.compactPath.wrappedValue.isEmpty, "Selection repair must not push")
        actions.compactPath.wrappedValue = [entries[0].id]
        try await waitForHost("The original journal must be open before deletion") {
            self.titleInput(in: controller.view, title: entries[0].title) != nil
        }
        fixture.store.delete(entries[0])
        try await waitForHost("Deleting the current journal must repair to a visible remaining journal") {
            actions.compactPath.wrappedValue == [entries[1].id]
                && self.titleInput(in: controller.view, title: entries[1].title) != nil
        }
        fixture.store.delete(entries[1])
        try await waitForHost("Deleting the last journal must return to an empty library") {
            actions.compactPath.wrappedValue.isEmpty
                && self.navigationController(in: controller)?.viewControllers.count == 1
        }
        await fixture.store.flushPendingSave()
    }

    @MainActor
    func testProductionDoneAndWritingActionsCoordinateTitleAndBodyFirstResponders() async throws {
        let entry = reviewEntries()[0]
        var interaction: JournalEditorInteraction?
        let controller = UIHostingController(rootView: EntryEditorView(
            entry: .constant(entry), bodyPresentation: JournalEntryBodyPresentation(body: entry.body),
            interactionObserver: { interaction = $0 }
        ))
        let window = makeWindow(controller: controller, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true; window.rootViewController = nil }
        try await waitForHost("The production title, body and keyboard actions must exist") {
            interaction != nil && self.titleInput(in: controller.view, title: entry.title) != nil
                && self.bodyInput(in: controller.view, text: entry.body) != nil
        }
        let actions = try XCTUnwrap(interaction)
        let title = try XCTUnwrap(titleInput(in: controller.view, title: entry.title))
        let body = try XCTUnwrap(bodyInput(in: controller.view, text: entry.body))
        XCTAssertTrue(title.becomeFirstResponder())
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(title.isFirstResponder)
        actions.dismissKeyboard()
        try await waitForHost("The production Done action must dismiss the title keyboard") {
            !title.isFirstResponder && !body.isFirstResponder
        }
        actions.focusBody()
        try await waitForHost("The production writing action must focus the body") { body.isFirstResponder }
        let selection = (entry.body as NSString).range(of: "河边")
        XCTAssertNotEqual(selection.location, NSNotFound)
        body.selectedRange = selection
        try await Task.sleep(for: .milliseconds(100))
        actions.dismissKeyboard()
        try await waitForHost("Done must also dismiss the body keyboard") {
            !title.isFirstResponder && !body.isFirstResponder
        }
        XCTAssertEqual(body.selectedRange, selection)
        XCTAssertEqual(body.text, entry.body)

        XCTAssertTrue(title.becomeFirstResponder())
        try await Task.sleep(for: .milliseconds(100))
        actions.focusBody()
        try await waitForHost("Writing from a focused title must transfer focus to the body") {
            body.isFirstResponder && !title.isFirstResponder
        }
        actions.enterPreview()
        try await waitForHost("Preview must release both input responders") {
            !title.isFirstResponder && !body.isFirstResponder
                && self.bodyInput(in: controller.view, text: entry.body) == nil
        }
        actions.returnToEdit()
        try await waitForHost("Picker-style return to edit must preserve the unfocused state") {
            self.bodyInput(in: controller.view, text: entry.body) != nil
        }
        let restoredBody = try XCTUnwrap(bodyInput(in: controller.view, text: entry.body))
        XCTAssertFalse(restoredBody.isFirstResponder)
        XCTAssertFalse(title.isFirstResponder)
        XCTAssertEqual(restoredBody.selectedRange, selection)
        XCTAssertEqual(restoredBody.text, entry.body)
    }

    func testDeferredMarkdownSharePreservesTheFullDocumentAndUnicode() {
        let date = reviewDate("2026-10-22T12:00:00Z")
        for (title, body) in [
            ("标题 📝", "### 小节\n\n中文与 e\u{301} / 👨‍👩‍👧‍👦\n- **完整内容**\n"),
            (" \n", ""),
            ("多行", String(repeating: "正文，包含 emoji 🌊 和换行。\n", count: 200))
        ] {
            let entry = JournalEntry(title: title, body: body, createdAt: date, updatedAt: date)
            let item = JournalMarkdownShareItem(entry: entry)
            XCTAssertEqual(String(data: item.markdownData(), encoding: .utf8), entry.markdownDocument)
            XCTAssertEqual(item.entry, entry)
        }
    }

    @MainActor
    private func makeNavigationStore(entries: [JournalEntry]) throws -> (store: JournalStore, directory: URL, storageURL: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mdjournal-navigation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storageURL = directory.appendingPathComponent("entries.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(entries).write(to: storageURL, options: .atomic)
        return (JournalStore(storageURL: storageURL), directory, storageURL)
    }

    @MainActor
    private func makeWindow<Content: View>(controller: UIHostingController<Content>, size: CGSize) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        return window
    }

    @MainActor
    private func waitForHost(_ message: String, condition: () -> Bool) async throws {
        for _ in 0..<80 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTFail(message)
        throw NSError(domain: "JournalInterfaceHost", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    @MainActor
    private func navigationController(in controller: UIViewController) -> UINavigationController? {
        if let navigation = controller as? UINavigationController { return navigation }
        for child in controller.children {
            if let navigation = navigationController(in: child) { return navigation }
        }
        return nil
    }

    @MainActor
    private func splitController(in controller: UIViewController) -> UISplitViewController? {
        if let split = controller as? UISplitViewController { return split }
        for child in controller.children {
            if let split = splitController(in: child) { return split }
        }
        return nil
    }

    @MainActor
    private func collectionView(in view: UIView) -> UICollectionView? {
        if let collection = view as? UICollectionView { return collection }
        for child in view.subviews {
            if let collection = collectionView(in: child) { return collection }
        }
        return nil
    }

    @MainActor
    private func activateFirstProductionEntry(in view: UIView) async throws {
        try await waitForHost("Production List must have a visible journal section") {
            guard let collection = self.collectionView(in: view) else { return false }
            return collection.numberOfSections > 1 && collection.numberOfItems(inSection: 1) > 0
        }
        let collection = try XCTUnwrap(collectionView(in: view))
        let indexPath = IndexPath(item: 0, section: 1)
        collection.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        collection.layoutIfNeeded()
        collection.selectItem(at: indexPath, animated: false, scrollPosition: [])
        let delegate = try XCTUnwrap(collection.delegate)
        XCTAssertTrue(delegate.responds(to: #selector(UICollectionViewDelegate.collectionView(_:didSelectItemAt:))))
        delegate.collectionView?(collection, didSelectItemAt: indexPath)
    }

    @MainActor
    private func attachHostImage(_ view: UIView, name: String, size: CGSize) throws {
        view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        var didDraw = false
        let image = renderer.image { _ in
            didDraw = view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        XCTAssertTrue(didDraw, "Unable to render \(name)")
        let attachment = XCTAttachment(image: image)
        attachment.name = "review-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testNarrowTitleGetsThirdLineWhileWideAndAccessibilityPoliciesRemainExplicit() {
        for width: CGFloat in [320, 390, 819] {
            XCTAssertEqual(EntryEditorLayoutContract(width: width, dynamicTypeSize: .large).titleLineLimit, 3)
        }
        for width: CGFloat in [820, 1120, 1440] {
            XCTAssertEqual(EntryEditorLayoutContract(width: width, dynamicTypeSize: .large).titleLineLimit, 2)
        }
        for width: CGFloat in [320, 1440] {
            XCTAssertNil(EntryEditorLayoutContract(width: width, dynamicTypeSize: .accessibility3).titleLineLimit)
        }
    }

    @MainActor
    func testWritingInsetsAlignBodyWithThePaperHeaderAndPlaceholder() {
        XCTAssertEqual(MarkdownBodyTextView.writingInsets.left, JournalTheme.pageInset)
        XCTAssertEqual(MarkdownBodyTextView.writingInsets.right, JournalTheme.pageInset)
        XCTAssertEqual(MarkdownBodyTextView.writingInsets.top, 20)
        XCTAssertEqual(MarkdownBodyTextView.writingInsets.bottom, 24)
    }

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
        XCTAssertEqual(original.accessibilityLabel, "日记正文")
        XCTAssertEqual(original.textContainerInset, MarkdownBodyTextView.writingInsets)
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
        for name in ["JournalCanvas", "JournalPaper", "JournalInset", "JournalAccent", "JournalOnAccent", "JournalSeparator"] {
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

        let accent = try XCTUnwrap(UIColor(named: "JournalAccent"))
        let foreground = try XCTUnwrap(UIColor(named: "JournalOnAccent"))
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection(traitsFrom: [
                    UITraitCollection(userInterfaceStyle: style),
                    UITraitCollection(accessibilityContrast: contrast)
                ])
                let backgroundLuminance = luminance(accent.resolvedColor(with: traits))
                let foregroundLuminance = luminance(foreground.resolvedColor(with: traits))
                let ratio = (max(backgroundLuminance, foregroundLuminance) + 0.05)
                    / (min(backgroundLuminance, foregroundLuminance) + 0.05)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "Primary button contrast: \(style), \(contrast)")
            }
        }
    }

    @MainActor
    private func luminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
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
        try await render(
            MarkdownPreviewView(entryID: entry.id, markdown: entry.body),
            name: "preview-390x720-light", size: CGSize(width: 390, height: 720)
        )
        try await render(
            library, name: "library-320x900-dark", size: CGSize(width: 320, height: 900), dark: true
        )
        try await render(
            EmptyStateView(onCreate: {}), name: "empty-390x720-light", size: CGSize(width: 390, height: 720)
        )
        try await render(
            StatisticsDashboardView(entries: entries, bodyPresentations: store.bodyPresentations),
            name: "statistics-390x900-light", size: CGSize(width: 390, height: 900)
        )
        try await render(
            StatisticsDashboardView(entries: entries, bodyPresentations: store.bodyPresentations),
            name: "statistics-390x900-light-accessibility3", size: CGSize(width: 390, height: 900),
            typeSize: .accessibility3
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

@MainActor
private final class NavigationHostConfiguration: ObservableObject {
    @Published var sizeClass: UserInterfaceSizeClass = .compact
}

private struct NavigationHostRoot: View {
    let store: JournalStore
    @ObservedObject var configuration: NavigationHostConfiguration
    let observer: (JournalContentInteraction) -> Void

    var body: some View {
        ContentView(store: store, interactionObserver: observer)
            .environment(\.horizontalSizeClass, configuration.sizeClass)
    }
}
