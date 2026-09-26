import SwiftUI
import UIKit
import XCTest
@testable import MDJournal

final class JournalInterfaceTests: XCTestCase {
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
        let entry = JournalEntry.starterEntry()
        try await render(
            EntryEditorView(entry: .constant(entry)),
            name: "editor-wide-light", size: CGSize(width: 1440, height: 900)
        )
        try await render(
            EntryEditorView(entry: .constant(entry)),
            name: "editor-phone-dark", size: CGSize(width: 390, height: 720), dark: true
        )
        try await render(
            EntryEditorView(entry: .constant(entry)),
            name: "editor-landscape", size: CGSize(width: 844, height: 320)
        )
        try await render(
            EntryEditorView(entry: .constant(entry)),
            name: "editor-accessibility", size: CGSize(width: 390, height: 720), typeSize: .accessibility3
        )
        try await render(
            EntryListView(
                overviewSnapshot: JournalListOverviewSnapshot(entries: [entry]),
                snapshot: JournalEntryListSnapshot(entries: [entry], searchText: "", selectedCategory: nil),
                selection: .constant(entry.id), searchText: .constant(""), selectedCategory: .constant(nil),
                onCreate: {}, onDelete: { _ in }, onShowStatistics: {}
            ),
            name: "library-light", size: CGSize(width: 320, height: 900)
        )
        try await render(
            StatisticsDashboardView(entries: [entry]),
            name: "statistics-wide", size: CGSize(width: 1100, height: 900)
        )
    }

    @MainActor
    private func render<Content: View>(
        _ content: Content, name: String, size: CGSize,
        dark: Bool = false, typeSize: DynamicTypeSize = .large
    ) async throws {
        let controller = UIHostingController(rootView: content
            .environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.dynamicTypeSize, typeSize)
            .environment(\.locale, Locale(identifier: "zh_CN")))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        controller.view.layoutIfNeeded()
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
}
