import SwiftUI
import UIKit
import Vision
import XCTest
@testable import MDJournal

final class JournalInterfaceTests: XCTestCase {
    @MainActor
    func testCompactProductionNavigationLinkOpensPopsAndReopensTheSameEntry() async throws {
        executionTimeAllowance = 60
        let entries = Array(reviewEntries().prefix(2))
        let fixture = try makeNavigationStore(entries: entries)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let suite = "mdjournal-navigation-gate-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: JournalAppLockStore.enabledDefaultsKey)
        let appLock = JournalAppLockStore(defaults: defaults)
        let subscriptions = JournalSubscriptionStore(startsAutomatically: false)
        let hostScene = try foregroundWindowScene()
        var observedScenePhase: ScenePhase?
        let controller = UIHostingController(rootView: NavigationPrivacyHostRoot(
            store: fixture.store, appLock: appLock, subscriptions: subscriptions, scene: hostScene,
            observeScenePhase: { observedScenePhase = $0 }
        )
            .environment(\.horizontalSizeClass, .compact))
        let size = CGSize(width: 390, height: 844)
        let (window, restoreWindow) = try makeWindow(controller: controller, size: size)
        defer { restoreWindow() }
        try await waitForHost("The production privacy gate must be active and uncovered before journal navigation") {
            observedScenePhase == .active && window.windowScene?.activationState == .foregroundActive
                && !appLock.needsPrivacyCover(sceneIsActive: true)
                && self.nativePrivacyCover(in: window) == nil
        }
        XCTAssertFalse(appLock.isEnabled)
        XCTAssertEqual(appLock.state, .unlocked)
        XCTAssertEqual(observedScenePhase, .active)
        XCTAssertNil(nativePrivacyCover(in: window))
        try await waitForHost("Compact ContentView must show its library first") {
            self.navigationController(in: controller)?.viewControllers.count == 1
        }
        let navigation = try XCTUnwrap(navigationController(in: controller))
        try await waitForSettledNavigation(navigation, in: window, viewport: controller.view)
        XCTAssertNil(bodyInput(in: controller.view, text: entries[0].body))
        traceCompactNavigation("library capture begin")
        try attachHostImage(controller.view, name: "content-390x844-compact-library", size: size)
        traceCompactNavigation("library capture end; activation begin")

        try await activateFirstProductionEntry(in: controller.view)
        traceCompactNavigation("activation end; push wait begin")
        try await waitForHost("A production NavigationLink must push the selected editor") {
            self.navigationController(in: controller)?.viewControllers.count == 2
        }
        traceCompactNavigation("push wait end; inputs wait begin")
        try await waitForHost("The pushed editor must contain the selected journal's title and body") {
            self.titleInput(in: controller.view, title: entries[0].title) != nil
                && self.bodyInput(in: controller.view, text: entries[0].body) != nil
        }
        traceCompactNavigation("inputs wait end; destination settled wait begin")
        try await waitForSettledNavigation(navigation, in: window, viewport: controller.view)
        traceCompactNavigation("destination settled wait end; detail capture begin")
        try attachHostImage(controller.view, name: "content-390x844-compact-detail", size: size)
        traceCompactNavigation("detail capture end")
        XCTAssertFalse(navigation.navigationBar.isHidden)
        XCTAssertFalse(try XCTUnwrap(navigation.topViewController).navigationItem.hidesBackButton)
        navigation.popViewController(animated: false)
        try await waitForHost("System pop must return to the library") {
            navigation.viewControllers.count == 1
                && self.bodyInput(in: controller.view, text: entries[0].body) == nil
        }
        try await waitForSettledNavigation(navigation, in: window, viewport: controller.view)
        try await activateFirstProductionEntry(in: controller.view)
        try await waitForHost("The same selected row must remain openable after pop") {
            navigation.viewControllers.count == 2
                && self.titleInput(in: controller.view, title: entries[0].title) != nil
        }
        try await waitForSettledNavigation(navigation, in: window, viewport: controller.view)
        XCTAssertEqual(fixture.store.entries, entries)
        XCTAssertEqual(fixture.store.revision, 0, "Navigation must not mutate persisted journals")

        let scene = try XCTUnwrap(window.windowScene)
        let nativeBounds = scene.coordinateSpace.bounds
        let nativeSize = CGSize(width: 393, height: 852)
        XCTAssertEqual(nativeBounds.size, nativeSize, "Capture requires the actual configured iPhone scene")
        XCTAssertEqual(window.screen.scale, 3, "Capture requires the actual configured iPhone display scale")
        guard nativeBounds.size == nativeSize, window.screen.scale == 3 else { return }
        let canvas = try XCTUnwrap(window.rootViewController as? NavigationHostCanvasController)
        canvas.updateContentSize(nativeSize)
        controller.view.setNeedsLayout()
        try await waitForHost("The iPhone destination must fill its restored native scene") {
            window.frame == nativeBounds && window.bounds.size == nativeSize
                && controller.view.bounds.size == nativeSize
                && self.titleInput(in: controller.view, title: entries[0].title) != nil
                && self.bodyInput(in: controller.view, text: entries[0].body) != nil
        }
        try await waitForSettledNavigation(navigation, in: window, viewport: controller.view)
        try attachNativeAppStoreImage(
            window, name: "appstore-iphone-detail-1179x2556", pointSize: nativeSize,
            pixelSize: CGSize(width: 1179, height: 2556)
        )
        navigation.popViewController(animated: false)
        try await waitForHost("The native iPhone library must show its production rows after system pop") {
            guard let collection = self.collectionView(in: controller.view) else { return false }
            return navigation.viewControllers.count == 1
                && self.bodyInput(in: controller.view, text: entries[0].body) == nil
                && collection.numberOfSections == 2 && collection.numberOfItems(inSection: 1) == 2
        }
        try await waitForSettledNavigation(navigation, in: window, viewport: controller.view)
        try attachNativeAppStoreImage(
            window, name: "appstore-iphone-library-1179x2556", pointSize: nativeSize,
            pixelSize: CGSize(width: 1179, height: 2556)
        )
    }

    @MainActor
    func testCompactProductionCreateClearsBlockingFiltersAndShowsTheCreatedID() async throws {
        executionTimeAllowance = 60
        print("Compact create regression: mounting the production library")
        let entries = Array(reviewEntries().prefix(2))
        let fixture = try makeNavigationStore(entries: entries)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        var interaction: JournalContentInteraction?
        let controller = UIHostingController(rootView: ContentView(
            store: fixture.store, interactionObserver: {
                print("Compact create regression: production onAppear actions installed")
                interaction = $0
            }
        )
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.calendar, Calendar(identifier: .gregorian)))
        print("Compact create regression: installing the host window")
        let (window, restoreWindow) = try makeWindow(
            controller: controller, size: CGSize(width: 390, height: 844)
        )
        print("Compact create regression: host mounted; awaiting its production rows")
        defer { restoreWindow() }
        try await waitForHost("Production ContentView must publish its installed actions") { interaction != nil }
        let actions = try XCTUnwrap(interaction)
        try await waitForHost("The production library must first render both journal rows") {
            guard let collection = self.collectionView(in: controller.view) else { return false }
            return collection.numberOfSections == 2 && collection.numberOfItems(inSection: 1) == 2
                && self.navigationController(in: controller)?.viewControllers.count == 1
        }
        print("Compact create regression: both rows rendered; applying blocking filters")
        let blockingSearch = "a search that matches no journal"
        actions.searchText.wrappedValue = blockingSearch
        actions.selectedCategory.wrappedValue = .travel
        try await waitForHost("Blocking filters must replace both journal rows with one empty-result row") {
            guard let collection = self.collectionView(in: controller.view) else { return false }
            return collection.numberOfSections == 2 && collection.numberOfItems(inSection: 1) == 1
        }
        print("Compact create regression: empty-result row rendered; search=\(actions.searchText.wrappedValue), category=\(String(describing: actions.selectedCategory.wrappedValue)), path=\(actions.compactPath.wrappedValue), navigationCount=\(self.navigationController(in: controller)?.viewControllers.count ?? 0)")
        XCTAssertEqual(actions.searchText.wrappedValue, blockingSearch)
        XCTAssertEqual(actions.selectedCategory.wrappedValue, .travel)
        let filteredCollection = try XCTUnwrap(collectionView(in: controller.view))
        _ = hasVisibleAccessibilityIdentifier(
            "journal.library.filtered-empty", in: filteredCollection, reportsDiagnostics: true
        )
        let visibleText = try await recognizeFilteredEmptyRegression(in: controller.view)
        XCTAssertTrue(
            visibleText.joined().contains("没有符合条件的日记"),
            "The rendered filtered empty result must show its title; recognized text: \(visibleText)"
        )
        XCTAssertTrue(actions.compactPath.wrappedValue.isEmpty, "Filtering must not push a detail")
        XCTAssertEqual(navigationController(in: controller)?.viewControllers.count, 1)

        print("Compact create regression: filtered empty result visible; invoking production create")
        actions.createEntry()
        print("Compact create regression: production create returned; waiting for its editor")
        try await waitForHost("The production create action must open a new journal") {
            fixture.store.entries.count == entries.count + 1
                && self.navigationController(in: controller)?.viewControllers.count == 2
        }
        let created = try XCTUnwrap(fixture.store.entries.first)
        try await waitForHost("The created destination must finish mounting its title and body inputs") {
            self.titleInput(in: controller.view, title: created.title) != nil
                && self.bodyInput(in: controller.view, text: created.body) != nil
        }
        XCTAssertFalse(entries.contains { $0.id == created.id })
        XCTAssertEqual(actions.compactPath.wrappedValue, [created.id])
        XCTAssertEqual(actions.searchText.wrappedValue, "")
        XCTAssertNil(actions.selectedCategory.wrappedValue)
        XCTAssertNotNil(titleInput(in: controller.view, title: created.title))
        XCTAssertNotNil(bodyInput(in: controller.view, text: created.body))
        print("Compact create regression: new editor visible; verifying persistence")
        await fixture.store.flushPendingSave()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let saved = try decoder.decode([JournalEntry].self, from: Data(contentsOf: fixture.storageURL))
        XCTAssertEqual(saved.first?.id, created.id)
        XCTAssertEqual(saved.count, entries.count + 1)
        print("Compact create regression: persistence verified; awaiting native navigation cleanup")
        let navigation = try XCTUnwrap(navigationController(in: controller))
        try await waitForSettledNavigation(navigation, in: window, viewport: controller.view)
        XCTAssertEqual(navigation.viewControllers.count, 2)
        XCTAssertNotNil(titleInput(in: controller.view, title: created.title))
        XCTAssertNotNil(bodyInput(in: controller.view, text: created.body))
        print("Compact create regression: cleanup complete; native push settled before root restoration")
    }

    @MainActor
    func testProductionNavigationRepairsFilteredAndDeletedSelectionsAcrossSizeClasses() async throws {
        executionTimeAllowance = 60
        let entries = Array(reviewEntries().prefix(2))
        let fixture = try makeNavigationStore(entries: entries)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let configuration = NavigationHostConfiguration()
        var interaction: JournalContentInteraction?
        let controller = UIHostingController(rootView: NavigationHostRoot(
            store: fixture.store, configuration: configuration, observer: { interaction = $0 }
        ).environment(\.calendar, Calendar(identifier: .gregorian)))
        if #available(iOS 16.4, *) {
            // The synthetic canvas is the available test area, independent of its parent viewport.
            controller.safeAreaRegions = []
        }
        let canvas = NavigationHostCanvasController(
            content: controller, size: CGSize(width: 390, height: 844)
        )
        let (window, restoreWindow) = try makeWindow(
            controller: canvas, size: CGSize(width: 390, height: 844), keepsSceneGeometry: true
        )
        defer { restoreWindow() }

        @MainActor
        func settleCompact(_ stage: String) async throws {
            traceCompactNavigation("size-class host \(stage): settled wait begin")
            let navigation = try XCTUnwrap(navigationController(in: controller))
            try await waitForSettledNavigation(navigation, in: window, viewport: controller.view)
            traceCompactNavigation("size-class host \(stage): settled complete")
        }

        try await waitForHost("Production navigation actions must be installed") { interaction != nil }
        let actions = try XCTUnwrap(interaction)
        try await waitForHost("The compact library must render both rows before selecting a journal") {
            guard let collection = self.collectionView(in: controller.view) else { return false }
            return collection.numberOfSections == 2 && collection.numberOfItems(inSection: 1) == 2
                && self.navigationController(in: controller)?.viewControllers.count == 1
        }
        try await settleCompact("initial library")
        print("Navigation regression: setting the initial compact destination")
        actions.compactPath.wrappedValue = [entries[0].id]
        print("Navigation regression: initial destination setter returned; awaiting the editor")
        try await waitForHost("A bound compact destination must show the real editor") {
            self.navigationController(in: controller)?.viewControllers.count == 2
                && self.bodyInput(in: controller.view, text: entries[0].body) != nil
        }
        try await settleCompact("initial compact push")
        print("Navigation regression: compact editor settled; setting regular configuration")

        configuration.sizeClass = .regular
        print("Navigation regression: regular configuration returned; setting UIKit traits")
        if #available(iOS 17.0, *) {
            controller.traitOverrides.horizontalSizeClass = .regular
        }
        print("Navigation regression: regular traits returned; resizing the contained canvas")
        canvas.updateContentSize(CGSize(width: 1360, height: 860))
        print("Navigation regression: window=\(window.frame), scene=\(String(describing: window.windowScene?.coordinateSpace.bounds)), canvas=\(controller.view.frame); scheduling regular layout")
        controller.view.setNeedsLayout()
        print("Navigation regression: regular layout scheduled; awaiting split controller")
        try await waitForHost("Regular ContentView must install its native split view controller") {
            self.splitController(in: controller) != nil
        }
        try await waitForHost("Regular ContentView must retain the current journal in its split view") {
            self.titleInput(in: controller.view, title: entries[0].title) != nil
        }
        XCTAssertEqual(controller.view.bounds.size, CGSize(width: 1360, height: 860))
        XCTAssertEqual(window.frame, try XCTUnwrap(window.windowScene).coordinateSpace.bounds)
        traceCompactNavigation("size-class host regular split: settled wait begin")
        let split = try XCTUnwrap(splitController(in: controller))
        try await waitForSettledSplit(split, in: window, viewport: controller.view)
        traceCompactNavigation("size-class host regular split: settled complete")
        print("Navigation regression: regular editor settled; setting compact configuration")
        configuration.sizeClass = .compact
        if #available(iOS 17.0, *) {
            controller.traitOverrides.horizontalSizeClass = .compact
        }
        canvas.updateContentSize(CGSize(width: 390, height: 844))
        print("Navigation regression: compact traits and canvas returned; scheduling compact layout")
        controller.view.setNeedsLayout()
        print("Navigation regression: compact layout scheduled; awaiting retained destination")
        try await waitForHost("Returning to compact width must retain the selected destination") {
            self.navigationController(in: controller)?.viewControllers.count == 2
                && self.titleInput(in: controller.view, title: entries[0].title) != nil
        }
        try await settleCompact("return to compact")
        XCTAssertEqual(controller.view.bounds.size, CGSize(width: 390, height: 844))
        XCTAssertEqual(fixture.store.revision, 0)

        actions.searchText.wrappedValue = "a search that matches no journal"
        try await waitForHost("An empty visible result must remove an invalid detail") {
            actions.compactPath.wrappedValue.isEmpty
                && self.navigationController(in: controller)?.viewControllers.count == 1
        }
        try await settleCompact("filtered result pop")
        actions.searchText.wrappedValue = ""
        try await waitForHost("Clearing the filter must render both journal rows without pushing") {
            guard let collection = self.collectionView(in: controller.view) else { return false }
            return collection.numberOfSections == 2 && collection.numberOfItems(inSection: 1) == 2
                && self.navigationController(in: controller)?.viewControllers.count == 1
        }
        try await settleCompact("cleared filter library")
        XCTAssertTrue(actions.compactPath.wrappedValue.isEmpty, "Selection repair must not push")
        actions.compactPath.wrappedValue = [entries[0].id]
        try await waitForHost("The original journal must be open before deletion") {
            self.navigationController(in: controller)?.viewControllers.count == 2
                && self.titleInput(in: controller.view, title: entries[0].title) != nil
        }
        try await settleCompact("reopened journal")
        fixture.store.delete(entries[0])
        try await waitForHost("Deleting the current journal must repair to a visible remaining journal") {
            actions.compactPath.wrappedValue == [entries[1].id]
                && self.navigationController(in: controller)?.viewControllers.count == 2
                && self.titleInput(in: controller.view, title: entries[1].title) != nil
        }
        try await settleCompact("deleted current journal")
        fixture.store.delete(entries[1])
        try await waitForHost("Deleting the last journal must return to an empty library") {
            actions.compactPath.wrappedValue.isEmpty
                && self.navigationController(in: controller)?.viewControllers.count == 1
        }
        await fixture.store.flushPendingSave()
        try await settleCompact("deleted last journal cleanup")
    }

    @MainActor
    func testProductionDoneAndWritingActionsCoordinateTitleAndBodyFirstResponders() async throws {
        executionTimeAllowance = 60
        let entry = reviewEntries()[0]
        var nextEntry = reviewEntries()[1]
        nextEntry.body = "### 切篇检查\n\n新的正文 📝"
        let state = EditorInteractionHostState(entries: [entry, nextEntry])
        var interaction: JournalEditorInteraction?
        let controller = UIHostingController(rootView: EditorInteractionHostRoot(
            state: state, observer: { interaction = $0 }
        ))
        let (_, restoreWindow) = try makeWindow(
            controller: controller, size: CGSize(width: 390, height: 844)
        )
        defer { restoreWindow() }
        try await waitForHost("The production title, body and keyboard actions must exist") {
            interaction != nil && self.titleInput(in: controller.view, title: entry.title) != nil
                && self.bodyInput(in: controller.view, text: entry.body) != nil
        }
        let actions = try XCTUnwrap(interaction)
        let title = try XCTUnwrap(titleInput(in: controller.view, title: entry.title))
        let body = try XCTUnwrap(bodyInput(in: controller.view, text: entry.body))
        actions.titleFocus.wrappedValue = true
        try await waitForHost("The production title FocusState must focus its native input") {
            actions.titleFocus.wrappedValue && title.isFirstResponder
        }
        XCTAssertTrue(title.isFirstResponder)
        actions.dismissKeyboard()
        try await waitForHost("The production Done action must dismiss the title keyboard") {
            !title.isFirstResponder && !body.isFirstResponder
        }
        XCTAssertFalse(actions.titleFocus.wrappedValue)
        actions.sceneActions.focusBody()
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

        actions.titleFocus.wrappedValue = true
        try await waitForHost("The title must receive focus again before transferring to writing") {
            actions.titleFocus.wrappedValue && title.isFirstResponder
        }
        actions.sceneActions.focusBody()
        try await waitForHost("Writing from a focused title must transfer focus to the body") {
            body.isFirstResponder && !title.isFirstResponder
        }
        actions.sceneActions.togglePreview()
        try await waitForHost("Preview must release both input responders") {
            !title.isFirstResponder && !body.isFirstResponder
        }
        try await waitForHost("Compact preview must remove the editing text view") {
            self.bodyInput(in: controller.view, text: entry.body) == nil
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
        assertSceneActionsUseCurrentBindingsAndReleaseTheirTarget(titleFocus: actions.titleFocus)

        let sceneActions = actions.sceneActions
        state.selectedEntryID = nextEntry.id
        let nextSelection = NSRange(location: nextEntry.body.utf16.count, length: 0)
        try await waitForHost("Changing the production binding must display the next journal without replacing its router") {
            self.titleInput(in: controller.view, title: nextEntry.title) != nil
                && self.bodyInput(in: controller.view, text: nextEntry.body)?.selectedRange == nextSelection
                && sceneActions.targetEntryID == nextEntry.id
        }
        XCTAssertTrue(try XCTUnwrap(interaction).sceneActions === sceneActions)
        XCTAssertEqual(sceneActions.targetEntryID, nextEntry.id)
        let expectedInsertion = MarkdownSnippetInsertion.apply(
            snippet: .heading, to: nextEntry.body, selectedRange: nextSelection
        )
        sceneActions.insertMarkdownSnippet(.heading)
        print("Editor command binding regression: firstUnchanged=\(state.entries[0] == entry), nextBody=\(String(reflecting: state.entries[1].body)), expected=\(String(reflecting: expectedInsertion.body))")
        try await waitForHost("A previously published command must mutate only the newly bound journal") {
            state.entries[1].body == expectedInsertion.body
                && self.bodyInput(in: controller.view, text: state.entries[1].body)?.selectedRange
                    == expectedInsertion.selectedRange
        }
        XCTAssertEqual(state.entries[0], entry, "A retained scene command must not edit the previous journal")
        XCTAssertEqual(state.entries[1].id, nextEntry.id)

        let nextEntryAfterInsertion = state.entries[1]
        actions.dismissKeyboard()
        state.selectedEntryID = entry.id
        let firstSelection = NSRange(location: entry.body.utf16.count, length: 0)
        try await waitForHost("Returning to the previous journal must update the same router's binding and selection") {
            self.titleInput(in: controller.view, title: entry.title) != nil
                && self.bodyInput(in: controller.view, text: entry.body)?.selectedRange == firstSelection
                && sceneActions.targetEntryID == entry.id
        }
        XCTAssertTrue(try XCTUnwrap(interaction).sceneActions === sceneActions)
        XCTAssertEqual(sceneActions.targetEntryID, entry.id)
        let expectedFirstInsertion = MarkdownSnippetInsertion.apply(
            snippet: .bold, to: entry.body, selectedRange: firstSelection
        )
        sceneActions.insertMarkdownSnippet(.bold)
        try await waitForHost("A retained command must follow the current journal when switching back") {
            state.entries[0].body == expectedFirstInsertion.body
                && self.bodyInput(in: controller.view, text: state.entries[0].body)?.selectedRange
                    == expectedFirstInsertion.selectedRange
        }
        XCTAssertEqual(state.entries[1], nextEntryAfterInsertion, "Switching back must not edit the journal just left")

        let activeEntryBeforeDetach = state.entries[0]
        state.showsEditor = false
        try await waitForHost("The production editor must leave the view hierarchy before detached commands are exercised") {
            self.bodyInput(in: controller.view, text: activeEntryBeforeDetach.body) == nil
                && self.titleInput(in: controller.view, title: activeEntryBeforeDetach.title) == nil
        }
        XCTAssertNil(sceneActions.targetEntryID)
        let beforeDetach = state.entries
        sceneActions.focusBody()
        sceneActions.focusWriting()
        sceneActions.togglePreview()
        sceneActions.insertMarkdownSnippet(.bold)
        sceneActions.applyIndentation(.indent)
        XCTAssertEqual(state.entries, beforeDetach, "Leaving the editor must clear the retained command target")
    }

    @MainActor
    func testProductionMarkedCompositionStaysWithItsJournalWhenBindingsChange() async throws {
        executionTimeAllowance = 60
        let entries = Array(reviewEntries().prefix(2))
        let state = EditorInteractionHostState(entries: entries)
        var interaction: JournalEditorInteraction?
        let controller = UIHostingController(rootView: EditorInteractionHostRoot(
            state: state, observer: { interaction = $0 }
        ))
        let (_, restoreWindow) = try makeWindow(
            controller: controller, size: CGSize(width: 390, height: 844)
        )
        defer { restoreWindow() }
        try await waitForHost("The production body and command target must be installed") {
            interaction?.sceneActions.targetEntryID == entries[0].id
                && self.bodyInput(in: controller.view, text: entries[0].body) != nil
        }
        let actions = try XCTUnwrap(interaction)
        let original = try XCTUnwrap(bodyInput(in: controller.view, text: entries[0].body))
        let originalCoordinator = try XCTUnwrap(original.delegate as? MarkdownBodyTextView.Coordinator)
        actions.sceneActions.focusBody()
        try await waitForHost("The first journal must own the active input session") { original.isFirstResponder }

        original.selectedRange = NSRange(location: entries[0].body.utf16.count, length: 0)
        let composition = "尚未结束的组合输入 📝"
        original.setMarkedText(composition, selectedRange: NSRange(location: composition.utf16.count, length: 0))
        XCTAssertNotNil(original.markedTextRange, "The regression requires a real UIKit marked-text session")
        let composedBody = try XCTUnwrap(original.text)
        XCTAssertTrue(composedBody.contains(composition))
        // Drive the production delegate boundary; this is not a physical keyboard/IME test.
        originalCoordinator.textViewDidChange(original)
        try await waitForHost("Marked edits must remain in their original journal") {
            state.entries[0].body == composedBody
        }
        XCTAssertNotNil(original.markedTextRange, "An update to the same journal must preserve its composition")
        let originalAfterComposition = state.entries[0]
        let composingFont = original.font
        state.writingPreferences = JournalWritingPreferences(font: .serif, size: .large, spacing: .relaxed)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNotNil(original.markedTextRange, "Changing writing preferences must defer until IME composition ends")
        XCTAssertEqual(original.text, composedBody)
        XCTAssertEqual(original.font, composingFont)

        state.selectedEntryID = entries[1].id
        try await waitForHost("A different journal must receive a separate native input and coordinator") {
            guard let current = self.bodyInput(in: controller.view, text: entries[1].body) else { return false }
            return current !== original && original.delegate == nil
                && self.titleInput(in: controller.view, title: entries[1].title) != nil
                && actions.sceneActions.targetEntryID == entries[1].id
        }
        let current = try XCTUnwrap(bodyInput(in: controller.view, text: entries[1].body))
        let currentCoordinator = try XCTUnwrap(current.delegate as? MarkdownBodyTextView.Coordinator)
        XCTAssertFalse(currentCoordinator === originalCoordinator)
        XCTAssertNil(current.markedTextRange)
        XCTAssertGreaterThan(try XCTUnwrap(current.font).pointSize, try XCTUnwrap(composingFont).pointSize)
        try await waitForHost("The new journal must retain the requested writing focus") { current.isFirstResponder }
        XCTAssertEqual(state.entries[0], originalAfterComposition)
        XCTAssertEqual(state.entries[1], entries[1], "Changing journals must not copy the old composition into the new body")

        let beforeDetachedCallbacks = state.entries
        original.text = "A late callback from the previous journal"
        originalCoordinator.textViewDidChange(original)
        originalCoordinator.textViewDidChangeSelection(original)
        originalCoordinator.textViewDidEndEditing(original)
        originalCoordinator.applyIndentation(.indent, to: original)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(state.entries, beforeDetachedCallbacks, "Detached callbacks must not modify either journal")
        XCTAssertTrue(current.isFirstResponder, "The detached input must not clear the active journal's focus")

        state.selectedEntryID = entries[0].id
        try await waitForHost("Returning to the first journal must restore its own composed text") {
            self.bodyInput(in: controller.view, text: originalAfterComposition.body) != nil
                && self.titleInput(in: controller.view, title: originalAfterComposition.title) != nil
        }
        XCTAssertEqual(state.entries[0], originalAfterComposition)
        XCTAssertEqual(state.entries[1], entries[1])
    }

    @MainActor
    private func assertSceneActionsUseCurrentBindingsAndReleaseTheirTarget(titleFocus: FocusState<Bool>.Binding) {
        var first = JournalEntry.starterEntry()
        var second = JournalEntry.starterEntry()
        second.body = "第二篇正文"
        let originalFirst = first
        var workspace = EntryEditorWorkspaceState()
        var details = true
        let workspaceBinding = Binding(get: { workspace }, set: { workspace = $0 })
        let detailsBinding = Binding(get: { details }, set: { details = $0 })
        var router: EntryEditorSceneActions? = EntryEditorSceneActions()
        weak var weakRouter = router
        let focus = router!.focusBody
        let writing = router!.focusWriting
        let preview = router!.togglePreview
        let insert = router!.insertMarkdownSnippet
        let indent = router!.applyIndentation
        router!.updateTarget(EntryEditorActionTarget(
            entry: Binding(get: { first }, set: { first = $0 }), workspace: workspaceBinding,
            titleFocus: titleFocus, showsDetails: detailsBinding,
            layout: EntryEditorLayoutContract(width: 390, dynamicTypeSize: .large)
        ))
        focus()
        XCTAssertTrue(workspace.editorFocused)
        let beforeInvalidation = (first, workspace, details)
        router!.invalidateTarget(unlessMatching: second.id)
        XCTAssertNil(router!.targetEntryID, "A document change must immediately invalidate the old command binding")
        insert(.bold)
        writing()
        XCTAssertEqual(first, beforeInvalidation.0)
        XCTAssertEqual(workspace, beforeInvalidation.1)
        XCTAssertEqual(details, beforeInvalidation.2)

        router!.updateTarget(EntryEditorActionTarget(
            entry: Binding(get: { second }, set: { second = $0 }), workspace: workspaceBinding,
            titleFocus: titleFocus, showsDetails: detailsBinding,
            layout: EntryEditorLayoutContract(width: 1440, dynamicTypeSize: .large)
        ))
        preview()
        XCTAssertTrue(workspace.usesSplitPreview, "Previously published commands must use the current layout")
        XCTAssertFalse(workspace.isPreviewColumnVisible)
        XCTAssertEqual(workspace.mode, .edit)
        insert(.heading)
        XCTAssertTrue(second.body.contains("### 小节标题"))
        let beforeIndent = second.body
        indent(.indent)
        XCTAssertNotEqual(second.body, beforeIndent)
        writing()
        XCTAssertFalse(details)
        XCTAssertTrue(workspace.editorFocused)
        XCTAssertEqual(first, originalFirst, "Old command handles must not edit the previous journal")

        router!.updateLayout(EntryEditorLayoutContract(width: 390, dynamicTypeSize: .large))
        let beforeLayoutInsertion = second.body
        insert(.italic)
        XCTAssertFalse(workspace.usesSplitPreview)
        XCTAssertEqual(router!.targetEntryID, second.id)
        XCTAssertNotEqual(second.body, beforeLayoutInsertion)
        XCTAssertEqual(first, originalFirst, "A layout-only callback must not restore the previous journal binding")

        router!.updateLayout(EntryEditorLayoutContract(width: 1440, dynamicTypeSize: .large))
        let currentBindingSnapshot = EntryEditorActionTarget(
            entry: Binding(get: { second }, set: { second = $0 }), workspace: workspaceBinding,
            titleFocus: titleFocus, showsDetails: detailsBinding,
            layout: EntryEditorLayoutContract(width: 0, dynamicTypeSize: .large)
        )
        XCTAssertTrue(router!.installCurrentBinding(currentBindingSnapshot, for: second.id))
        XCTAssertEqual(router!.targetEntryID, second.id)
        XCTAssertEqual(workspace.bodySelectedRange, NSRange(location: second.body.utf16.count, length: 0))
        XCTAssertEqual(router!.layout?.usesSplitPreview, true, "Installing the current binding must preserve newer geometry")
        focus()
        XCTAssertTrue(workspace.usesSplitPreview, "Commands must not revert to the captured zero-width layout")
        router!.invalidateTarget(unlessMatching: second.id)
        XCTAssertEqual(router!.targetEntryID, second.id, "A late change notification must not clear an already installed matching target")
        let mismatchedSnapshot = EntryEditorActionTarget(
            entry: Binding(get: { first }, set: { first = $0 }), workspace: workspaceBinding,
            titleFocus: titleFocus, showsDetails: detailsBinding,
            layout: EntryEditorLayoutContract(width: 390, dynamicTypeSize: .large)
        )
        XCTAssertFalse(router!.installCurrentBinding(mismatchedSnapshot, for: second.id))
        XCTAssertEqual(router!.targetEntryID, second.id, "A stale binding must not replace the newly installed target")
        XCTAssertEqual(first, originalFirst)

        let beforeDetach = (first, second, workspace, details)
        router!.clearTarget()
        focus()
        writing()
        preview()
        insert(.bold)
        indent(.outdent)
        XCTAssertEqual(first, beforeDetach.0)
        XCTAssertEqual(second, beforeDetach.1)
        XCTAssertEqual(workspace, beforeDetach.2)
        XCTAssertEqual(details, beforeDetach.3)
        router = nil
        XCTAssertNil(weakRouter, "Published command handles must not retain their editor router")
        focus()
        writing()
        preview()
        insert(.bold)
        indent(.outdent)
        XCTAssertEqual(second, beforeDetach.1)
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
    private func foregroundWindowScene() throws -> UIWindowScene {
        try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive },
            "Navigation and responder tests require the test host's foreground scene"
        )
    }

    @MainActor
    private func makeWindow(
        controller: UIViewController, size: CGSize, keepsSceneGeometry: Bool = false
    ) throws -> (window: UIWindow, restore: @MainActor () -> Void) {
        let scene = try foregroundWindowScene()
        let window = try XCTUnwrap(scene.windows.first { $0.isKeyWindow }, "A foreground key window must exist")
        let originalRoot = window.rootViewController
        let originalFrame = window.frame
        let originalBounds = window.bounds
        let originalStyle = window.overrideUserInterfaceStyle
        let wasHidden = window.isHidden
        let wasKeyWindow = window.isKeyWindow

        // Keep only one active SwiftUI root publishing focused values into the foreground scene.
        print("Interface host: detaching the original app root")
        window.rootViewController = nil
        let root = keepsSceneGeometry ? controller : NavigationHostCanvasController(content: controller, size: size)
        window.overrideUserInterfaceStyle = .light
        if #available(iOS 17.0, *) {
            controller.traitOverrides.horizontalSizeClass = .compact
        }
        print("Interface host: installing the fixture root")
        window.rootViewController = root
        print("Interface host: making the existing window key and visible")
        window.makeKeyAndVisible()
        root.view.frame = window.bounds
        root.view.setNeedsLayout()
        print("Interface host: laying out the fixture root")
        root.view.layoutIfNeeded()
        XCTAssertEqual(window.frame, scene.coordinateSpace.bounds, "Test canvases must preserve the real scene geometry")
        print("Interface host: fixture layout returned")

        return (window, {
            print("Interface host: restoring the original app root")
            root.dismiss(animated: false)
            window.endEditing(true)
            window.rootViewController = nil
            window.overrideUserInterfaceStyle = originalStyle
            window.frame = originalFrame
            window.bounds = originalBounds
            window.rootViewController = originalRoot
            window.isHidden = wasHidden
            if wasKeyWindow { window.makeKey() }
            window.layoutIfNeeded()
            originalRoot?.view.setNeedsLayout()
            originalRoot?.view.layoutIfNeeded()
            print("Interface host: original window restored")
        })
    }

    @MainActor
    private func waitForHost(_ message: String, condition: () -> Bool) async throws {
        for _ in 0..<80 {
            try await Task.sleep(for: .milliseconds(25))
            if condition() { return }
        }
        XCTFail(message)
        throw NSError(domain: "JournalInterfaceHost", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func traceCompactNavigation(_ stage: String) {
        FileHandle.standardOutput.write(Data("Compact navigation regression: \(stage)\n".utf8))
    }

    @MainActor
    private func waitForSettledNavigation(
        _ navigation: UINavigationController, in window: UIWindow, viewport: UIView? = nil
    ) async throws {
        var previous: NavigationLayoutSample?
        var stableSamples = 0
        var lastState = "The top controller is not yet attached"
        defer { print("Navigation transition regression: \(lastState), stableSamples=\(stableSamples)") }
        try await waitForHost("The native navigation transition must finish with a stable, full-width destination") {
            guard let sample = self.navigationLayoutSample(
                navigation, in: window, viewport: viewport, diagnostic: &lastState
            ) else {
                previous = nil
                stableSamples = 0
                return false
            }
            stableSamples = sample == previous ? stableSamples + 1 : 1
            previous = sample
            return stableSamples >= 3
        }
    }

    @MainActor
    private func navigationLayoutSample(
        _ navigation: UINavigationController, in window: UIWindow, viewport: UIView?, diagnostic: inout String
    ) -> NavigationLayoutSample? {
        if let viewport, viewport.window !== window {
            diagnostic = "The requested navigation viewport is not attached to the host window"
            return nil
        }
        guard navigation.transitionCoordinator == nil,
              let top = navigation.topViewController,
              top.transitionCoordinator == nil,
              navigation.visibleViewController === top,
              top.isViewLoaded,
              top.view.window === window,
              !top.view.isHidden,
              top.view.alpha > 0.99,
              let parent = top.view.superview
        else {
            diagnostic = "The native navigation transition is active or its top view is not visible"
            return nil
        }
        let viewportView: UIView = viewport ?? navigation.view
        let viewportFrame = viewportView.convert(viewportView.bounds, to: window)
        let frame = top.view.convert(top.view.bounds, to: window)
        let displayedFrame = top.view.layer.presentation().map {
            parent.convert($0.frame, to: window)
        } ?? frame
        diagnostic = "top=\(frame), displayed=\(displayedFrame), viewport=\(viewportFrame), window=\(window.bounds)"
        guard alignedWithViewport(frame, viewport: viewportFrame),
              alignedWithViewport(displayedFrame, viewport: viewportFrame) else { return nil }
        return NavigationLayoutSample(
            top: ObjectIdentifier(top), frame: frame, bounds: top.view.bounds,
            displayedFrame: displayedFrame, viewportFrame: viewportFrame
        )
    }

    private func alignedWithViewport(_ frame: CGRect, viewport: CGRect) -> Bool {
        let tolerance: CGFloat = 0.5
        return frame.intersects(viewport)
            && abs(frame.minX - viewport.minX) <= tolerance
            && abs(frame.width - viewport.width) <= tolerance
    }

    @MainActor
    private func waitForSettledSplit(
        _ split: UISplitViewController, in window: UIWindow, viewport: UIView
    ) async throws {
        var previous: SplitLayoutSample?
        var stableSamples = 0
        var lastState = "The regular split view is not yet attached"
        defer { print("Split transition regression: \(lastState), stableSamples=\(stableSamples)") }
        try await waitForHost("The regular split view and its navigation columns must finish their transitions and layout") {
            let navigations = self.navigationControllers(in: split)
            guard split.transitionCoordinator == nil, !split.isCollapsed,
                  split.isViewLoaded, split.view.window === window,
                  !split.view.isHidden, split.view.alpha > 0.99,
                  let parent = split.view.superview,
                  !navigations.isEmpty,
                  navigations.allSatisfy({
                      $0.transitionCoordinator == nil && $0.topViewController?.transitionCoordinator == nil
                  })
            else {
                previous = nil
                stableSamples = 0
                lastState = "The split view is collapsed, detached or still transitioning with its columns"
                return false
            }
            let viewportFrame = viewport.convert(viewport.bounds, to: window)
            let frame = split.view.convert(split.view.bounds, to: window)
            let displayedFrame = split.view.layer.presentation().map {
                parent.convert($0.frame, to: window)
            } ?? frame
            lastState = "split=\(frame), displayed=\(displayedFrame), viewport=\(viewportFrame)"
            guard self.alignedWithViewport(frame, viewport: viewportFrame),
                  self.alignedWithViewport(displayedFrame, viewport: viewportFrame) else {
                previous = nil
                stableSamples = 0
                return false
            }
            let visibleNavigations = navigations.filter {
                $0.isViewLoaded && $0.view.window === window && !$0.view.isHidden && $0.view.alpha > 0.99
                    && $0.view.convert($0.view.bounds, to: window).intersects(viewportFrame)
            }
            var columns: [NavigationLayoutSample] = []
            for navigation in visibleNavigations {
                var diagnostic = ""
                guard let column = self.navigationLayoutSample(
                    navigation, in: window, viewport: navigation.view, diagnostic: &diagnostic
                ) else {
                    previous = nil
                    stableSamples = 0
                    lastState += "; column=\(diagnostic)"
                    return false
                }
                columns.append(column)
            }
            guard !columns.isEmpty else {
                previous = nil
                stableSamples = 0
                lastState += "; no visible navigation columns"
                return false
            }
            lastState += "; columns=\(columns)"
            let sample = SplitLayoutSample(
                frame: frame, bounds: split.view.bounds, displayedFrame: displayedFrame,
                viewportFrame: viewportFrame, columns: columns
            )
            stableSamples = sample == previous ? stableSamples + 1 : 1
            previous = sample
            return stableSamples >= 3
        }
    }

    @MainActor
    private func navigationControllers(in controller: UIViewController) -> [UINavigationController] {
        let current = (controller as? UINavigationController).map { [$0] } ?? []
        return current + controller.children.flatMap { navigationControllers(in: $0) }
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
    private func nativePrivacyCover(in view: UIView) -> UIView? {
        if let identifier = view.accessibilityIdentifier,
           ["journal.privacy-cover", "journal.window-privacy-cover"].contains(identifier),
           !view.isHidden, view.alpha > 0.01, view.window != nil {
            return view
        }
        for child in view.subviews {
            if let cover = nativePrivacyCover(in: child) { return cover }
        }
        return nil
    }

    @MainActor
    private func hasVisibleAccessibilityIdentifier(
        _ identifier: String, in view: UIView, reportsDiagnostics: Bool = false
    ) -> Bool {
        guard let window = view.window else { return false }
        let visibleFrame = window.convert(window.bounds, to: nil)
        var visited: Set<ObjectIdentifier> = []
        var identifiers: [String] = []

        @MainActor
        func contains(_ object: NSObject) -> Bool {
            guard visited.count < 512, visited.insert(ObjectIdentifier(object)).inserted else { return false }
            if let childView = object as? UIView,
               childView.isHidden || childView.alpha <= 0.01 || childView.window == nil {
                return false
            }
            if let element = object as? UIAccessibilityIdentification,
               let value = element.accessibilityIdentifier {
                if reportsDiagnostics { identifiers.append("\(value):\(object.accessibilityFrame)") }
                if value == identifier, object.accessibilityFrame.intersects(visibleFrame) { return true }
            }
            if #available(iOS 17.0, *), let elements = object.automationElements {
                for case let element as NSObject in elements where contains(element) { return true }
            }
            if let elements = object.accessibilityElements {
                for case let element as NSObject in elements where contains(element) { return true }
            } else {
                let count = object.accessibilityElementCount()
                if count > 0 && count < 1_024 {
                    for index in 0..<count {
                        if let element = object.accessibilityElement(at: index) as? NSObject,
                           contains(element) { return true }
                    }
                }
            }
            if let childView = object as? UIView {
                for child in childView.subviews where contains(child) { return true }
            }
            return false
        }

        let found = contains(view)
        if reportsDiagnostics {
            print("Accessibility regression: target=\(identifier), visible=\(found), viewport=\(visibleFrame), visited=\(visited.count), identifiers=\(identifiers)")
        }
        return found
    }

    @MainActor
    private func activateFirstProductionEntry(in view: UIView) async throws {
        try await waitForHost("Production List must have a visible journal section") {
            guard let collection = self.collectionView(in: view) else { return false }
            return collection.numberOfSections > 1 && collection.numberOfItems(inSection: 1) > 0
        }
        let collection = try XCTUnwrap(collectionView(in: view))
        let indexPath = IndexPath(item: 0, section: 1)
        traceCompactNavigation("entry scroll begin")
        collection.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        traceCompactNavigation("entry scroll returned; collection layout begin")
        collection.layoutIfNeeded()
        traceCompactNavigation("collection layout returned")
        let delegate = try XCTUnwrap(collection.delegate)
        let navigation = view.window?.rootViewController.flatMap { navigationController(in: $0) }
        traceCompactNavigation("shouldSelect begin; navigationCount=\(navigation?.viewControllers.count ?? 0)")
        let shouldSelect = delegate.collectionView?(collection, shouldSelectItemAt: indexPath) ?? true
        traceCompactNavigation("shouldSelect returned \(shouldSelect); selectItem begin")
        XCTAssertTrue(shouldSelect, "The production journal row must allow selection")
        guard shouldSelect else { return }
        collection.selectItem(at: indexPath, animated: false, scrollPosition: [])
        traceCompactNavigation("selectItem returned; didSelect begin; navigationCount=\(navigation?.viewControllers.count ?? 0)")
        let didSelect = #selector(UICollectionViewDelegate.collectionView(_:didSelectItemAt:))
        XCTAssertTrue(delegate.responds(to: didSelect), "A production list row must handle selection")
        delegate.collectionView?(collection, didSelectItemAt: indexPath)
        traceCompactNavigation("didSelect returned; primaryAction begin; navigationCount=\(navigation?.viewControllers.count ?? 0), transitioning=\(navigation?.transitionCoordinator != nil)")
        let primaryAction = #selector(UICollectionViewDelegate.collectionView(_:performPrimaryActionForItemAt:))
        XCTAssertTrue(delegate.responds(to: primaryAction), "A production list row must expose its primary action")
        delegate.collectionView?(collection, performPrimaryActionForItemAt: indexPath)
        traceCompactNavigation("primaryAction returned; navigationCount=\(navigation?.viewControllers.count ?? 0), transitioning=\(navigation?.transitionCoordinator != nil)")
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

    @MainActor
    private func attachNativeAppStoreImage(
        _ window: UIWindow, name: String, pointSize: CGSize, pixelSize: CGSize
    ) throws {
        let scene = try XCTUnwrap(window.windowScene)
        XCTAssertEqual(window.frame, scene.coordinateSpace.bounds, "Capture must use the native scene frame")
        XCTAssertEqual(window.bounds.size, pointSize)
        XCTAssertEqual(window.screen.scale, 3)
        XCTAssertEqual(window.bounds.width * window.screen.scale, pixelSize.width)
        XCTAssertEqual(window.bounds.height * window.screen.scale, pixelSize.height)
        guard window.frame == scene.coordinateSpace.bounds,
              window.bounds.size == pointSize, window.screen.scale == 3 else { return }
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: window.bounds.size, format: format)
        var didDraw = false
        let image = renderer.image { _ in
            didDraw = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        XCTAssertTrue(didDraw, "Unable to render the native window for \(name)")
        let pixels = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(image.size, pointSize)
        XCTAssertEqual(pixels.width, Int(pixelSize.width))
        XCTAssertEqual(pixels.height, Int(pixelSize.height))
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func recognizeFilteredEmptyRegression(in view: UIView) async throws -> [String] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(2, view.window?.screen.scale ?? UIScreen.main.scale)
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size, format: format)
        var didDraw = false
        let image = renderer.image { _ in
            didDraw = view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        XCTAssertTrue(didDraw, "The filtered library must render its real hierarchy")
        let attachment = XCTAttachment(image: image)
        attachment.name = "regression-compact-filtered-empty"
        attachment.lifetime = .keepAlways
        add(attachment)
        let data = try XCTUnwrap(image.pngData())
        // SwiftUI's virtual accessibility elements need not be materialized in a unit-test host.
        let text = try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            try VNImageRequestHandler(data: data, options: [:]).perform([request])
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        }.value
        print("Compact create regression: visible filtered title OCR=\(text)")
        return text
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
                for name in ["JournalPaper", "JournalInset"] {
                    let surface = try XCTUnwrap(UIColor(named: name)).resolvedColor(with: traits)
                    let surfaceLuminance = luminance(surface)
                    let textRatio = (max(backgroundLuminance, surfaceLuminance) + 0.05)
                        / (min(backgroundLuminance, surfaceLuminance) + 0.05)
                    XCTAssertGreaterThanOrEqual(textRatio, 4.5, "Small metadata labels: \(name), \(style), \(contrast)")
                }
                for category in JournalEntry.Category.allCases {
                    let hue = UIColor(category.tint).resolvedColor(with: traits)
                    let paper = try XCTUnwrap(UIColor(named: "JournalPaper")).resolvedColor(with: traits)
                    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                    var pr: CGFloat = 0, pg: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
                    XCTAssertTrue(hue.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
                    XCTAssertTrue(paper.getRed(&pr, green: &pg, blue: &pb, alpha: &pa))
                    let chip = UIColor(red: red * 0.14 + pr * 0.86, green: green * 0.14 + pg * 0.86,
                                       blue: blue * 0.14 + pb * 0.86, alpha: 1)
                    let chipLuminance = luminance(chip)
                    let chipRatio = (max(backgroundLuminance, chipLuminance) + 0.05)
                        / (min(backgroundLuminance, chipLuminance) + 0.05)
                    XCTAssertGreaterThanOrEqual(chipRatio, 4.5, "Category picker text: \(category), \(style), \(contrast)")
                }
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
        let writingSuite = "mdjournal-writing-review-\(UUID().uuidString)"
        let writingDefaults = try XCTUnwrap(UserDefaults(suiteName: writingSuite))
        defer { writingDefaults.removePersistentDomain(forName: writingSuite) }
        let writingSettings = NavigationStack { JournalWritingSettingsView() }.defaultAppStorage(writingDefaults)
        try await render(writingSettings, name: "writing-390x844-light", size: CGSize(width: 390, height: 844))
        try await render(
            writingSettings, name: "writing-390x844-light-accessibility3", size: CGSize(width: 390, height: 844),
            typeSize: .accessibility3
        )
        try await render(
            EntryEditorView(entry: .constant(entry), bodyPresentation: JournalEntryBodyPresentation(body: entry.body))
                .environment(\.journalWritingPreferences, JournalWritingPreferences(font: .serif, size: .large, spacing: .relaxed)),
            name: "editor-390x720-light-relaxed", size: CGSize(width: 390, height: 720)
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
        // This is a complete production-view canvas, not a screenshot from an iPad device.
        try await render(
            ContentView(store: store).environment(\.horizontalSizeClass, .regular),
            name: "ipad-library-1366x1024", size: CGSize(width: 1366, height: 1024),
            scale: 2, opaque: true, attachmentName: "appstore-ipad-library-2732x2048"
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
        dark: Bool = false, typeSize: DynamicTypeSize = .large, scrollToBottom: Bool = false,
        scale: CGFloat = 1, opaque: Bool = false, attachmentName: String? = nil
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
        XCTAssertEqual(window.bounds.size, size, "The render window must retain the complete canvas")
        XCTAssertEqual(controller.view.bounds.size, size, "The production host must fill the complete canvas")
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = opaque
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        var didDraw = false
        let image = renderer.image { _ in
            didDraw = controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        XCTAssertTrue(didDraw, "Unable to render \(name)")
        XCTAssertEqual(image.size, size)
        let pixels = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(pixels.width, Int(size.width * scale))
        XCTAssertEqual(pixels.height, Int(size.height * scale))
        let attachment = XCTAttachment(image: image)
        attachment.name = attachmentName ?? "review-\(name)"
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
private final class EditorInteractionHostState: ObservableObject {
    @Published var entries: [JournalEntry]
    @Published var selectedEntryID: JournalEntry.ID
    @Published var showsEditor = true
    @Published var writingPreferences = JournalWritingPreferences()

    init(entries: [JournalEntry]) {
        self.entries = entries
        selectedEntryID = entries[0].id
    }

    func binding(for entryID: JournalEntry.ID) -> Binding<JournalEntry> {
        Binding(
            get: { self.entries.first { $0.id == entryID }! },
            set: { updated in
                guard let index = self.entries.firstIndex(where: { $0.id == entryID }) else { return }
                self.entries[index] = updated
            }
        )
    }
}

@MainActor
private struct EditorInteractionHostRoot: View {
    @ObservedObject var state: EditorInteractionHostState
    let observer: (JournalEditorInteraction) -> Void

    var body: some View {
        if state.showsEditor, let entry = state.entries.first(where: { $0.id == state.selectedEntryID }) {
            EntryEditorView(
                entry: state.binding(for: entry.id),
                bodyPresentation: JournalEntryBodyPresentation(body: entry.body),
                interactionObserver: observer
            )
            .environment(\.journalWritingPreferences, state.writingPreferences)
        } else {
            Color.clear
        }
    }
}

@MainActor
private struct NavigationPrivacyHostRoot: View {
    @State private var scenePhase: ScenePhase
    let store: JournalStore
    let appLock: JournalAppLockStore
    let subscriptions: JournalSubscriptionStore
    let scene: UIWindowScene
    let observeScenePhase: (ScenePhase) -> Void

    init(
        store: JournalStore, appLock: JournalAppLockStore, subscriptions: JournalSubscriptionStore,
        scene: UIWindowScene, observeScenePhase: @escaping (ScenePhase) -> Void
    ) {
        self.store = store
        self.appLock = appLock
        self.subscriptions = subscriptions
        self.scene = scene
        self.observeScenePhase = observeScenePhase
        _scenePhase = State(initialValue: Self.phase(for: scene.activationState))
    }

    var body: some View {
        JournalPrivacyGate {
            ContentView(store: store)
        }
        // A replacement UIHostingController is outside App's scene environment propagation.
        .environment(\.scenePhase, scenePhase)
        .environmentObject(appLock)
        .environmentObject(subscriptions)
        .onAppear {
            scenePhase = Self.phase(for: scene.activationState)
            observeScenePhase(scenePhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.didActivateNotification, object: scene)) { _ in
            scenePhase = Self.phase(for: scene.activationState)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.willDeactivateNotification, object: scene)) { _ in
            scenePhase = .inactive
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.didEnterBackgroundNotification, object: scene)) { _ in
            scenePhase = .background
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification, object: scene)) { _ in
            scenePhase = .inactive
        }
        .onChange(of: scenePhase) { observeScenePhase($0) }
    }

    private static func phase(for state: UIScene.ActivationState) -> ScenePhase {
        switch state {
        case .foregroundActive: return .active
        case .foregroundInactive: return .inactive
        case .background, .unattached: return .background
        @unknown default: return .background
        }
    }
}

private struct NavigationLayoutSample: Equatable {
    let top: ObjectIdentifier
    let frame: CGRect
    let bounds: CGRect
    let displayedFrame: CGRect
    let viewportFrame: CGRect
}

private struct SplitLayoutSample: Equatable {
    let frame: CGRect
    let bounds: CGRect
    let displayedFrame: CGRect
    let viewportFrame: CGRect
    let columns: [NavigationLayoutSample]
}

@MainActor
private final class NavigationHostCanvasController: UIViewController {
    private let content: UIViewController
    private var contentSize: CGSize

    init(content: UIViewController, size: CGSize) {
        self.content = content
        contentSize = size
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
        addChild(content)
        view.addSubview(content.view)
        content.didMove(toParent: self)
        updateContentSize(contentSize)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateContentSize(contentSize)
    }

    func updateContentSize(_ size: CGSize) {
        contentSize = size
        guard isViewLoaded else { return }
        // Exercise wide layouts without resizing an iPhone scene's native window.
        let frame = CGRect(origin: .zero, size: size)
        if content.view.frame != frame {
            content.view.frame = frame
            content.view.setNeedsLayout()
        }
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
