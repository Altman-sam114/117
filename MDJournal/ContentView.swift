import SwiftUI

#if DEBUG
struct JournalContentInteraction {
    let compactPath: Binding<[JournalEntry.ID]>
    let searchText: Binding<String>
    let selectedCategory: Binding<JournalEntry.Category?>
    let createEntry: () -> Void
}
#endif

@MainActor
final class JournalContentSceneActions: ObservableObject {
    struct Target {
        let store: JournalStore
        let selection: Binding<JournalEntry.ID?>
        let searchText: Binding<String>
        let category: Binding<JournalEntry.Category?>
        let compactPath: Binding<[JournalEntry.ID]>
        let showStatistics: () -> Void
    }

    struct Availability: Equatable {
        var hasTarget = false
        var canCreate = false
        var canSelectNewer = false
        var canSelectOlder = false
    }

    @Published private(set) var availability = Availability()
    private var target: Target?

    func updateTarget(_ target: Target) {
        self.target = target
        refreshAvailability()
    }

    func clearTarget() {
        target = nil
        refreshAvailability()
    }

    func refreshAvailability() {
        var updated = Availability()
        if let target {
            let entries = visibleEntries(in: target)
            let selection = target.selection.wrappedValue
            updated.hasTarget = true
            updated.canCreate = target.store.canMutate
            updated.canSelectNewer = JournalEntryNavigation.destinationID(
                in: entries, selection: selection, direction: .newer
            ) != nil
            updated.canSelectOlder = JournalEntryNavigation.destinationID(
                in: entries, selection: selection, direction: .older
            ) != nil
        }
        if availability != updated { availability = updated }
    }

    func createEntry() {
        guard let target, let entryID = target.store.createEntry() else { return }
        target.searchText.wrappedValue = ""
        target.category.wrappedValue = nil
        target.selection.wrappedValue = entryID
        target.compactPath.wrappedValue = [entryID]
        refreshAvailability()
    }

    func showStatistics() {
        target?.showStatistics()
    }

    func canSelect(_ direction: JournalEntryNavigationDirection) -> Bool {
        switch direction {
        case .newer: return availability.canSelectNewer
        case .older: return availability.canSelectOlder
        }
    }

    func select(_ direction: JournalEntryNavigationDirection) {
        guard let target, let entryID = destination(in: target, direction: direction) else { return }
        target.selection.wrappedValue = entryID
        if !target.compactPath.wrappedValue.isEmpty { target.compactPath.wrappedValue = [entryID] }
        refreshAvailability()
    }

    private func destination(in target: Target, direction: JournalEntryNavigationDirection) -> JournalEntry.ID? {
        JournalEntryNavigation.destinationID(
            in: visibleEntries(in: target), selection: target.selection.wrappedValue, direction: direction
        )
    }

    private func visibleEntries(in target: Target) -> [JournalEntry] {
        JournalEntryListSnapshot(
            entries: target.store.entries,
            searchText: target.searchText.wrappedValue,
            selectedCategory: target.category.wrappedValue
        ).filteredEntries
    }
}

@MainActor
struct ContentView: View {
    private enum Sheet: String, Identifiable {
        case statistics
        case settings

        var id: String { rawValue }
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #if targetEnvironment(macCatalyst)
    @Environment(\.openWindow) private var openWindow
    #endif

    @ObservedObject var store: JournalStore
    @StateObject private var sceneActions = JournalContentSceneActions()
    @State private var selectedEntryID: JournalEntry.ID?
    @State private var searchText = ""
    @State private var selectedCategory: JournalEntry.Category?
    @State private var presentedSheet: Sheet?
    @State private var compactEntryPath: [JournalEntry.ID] = []
    #if DEBUG
    var interactionObserver: ((JournalContentInteraction) -> Void)? = nil
    #endif

    var body: some View {
        let listSnapshot = makeListSnapshot()

        Group {
            if usesCompactNavigation {
                NavigationStack(path: $compactEntryPath) {
                    entryList(using: listSnapshot)
                        .navigationDestination(for: JournalEntry.ID.self) { entryID in
                            detail(for: entryID, using: listSnapshot)
                        }
                }
            } else {
                NavigationSplitView {
                    entryList(using: listSnapshot)
                        #if targetEnvironment(macCatalyst)
                        .navigationSplitViewColumnWidth(
                            min: MacWindowLayoutContract.sidebarMinimumWidth,
                            ideal: MacWindowLayoutContract.sidebarIdealWidth,
                            max: MacWindowLayoutContract.sidebarMaximumWidth
                        )
                        #endif
                } detail: {
                    detail(for: selectedEntryID, using: listSnapshot)
                }
            }
        }
        .tint(JournalTheme.accent)
        #if targetEnvironment(macCatalyst)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Label("\(listSnapshot.filteredEntries.count) 篇", systemImage: "book.closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("当前筛选结果")
                    .accessibilityValue("\(listSnapshot.filteredEntries.count) 篇")
            }
        }
        #endif
        .onAppear {
            selectInitialEntry()
            sceneActions.updateTarget(sceneActionTarget())
            #if DEBUG
            interactionObserver?(JournalContentInteraction(
                compactPath: $compactEntryPath, searchText: $searchText,
                selectedCategory: $selectedCategory, createEntry: createEntry
            ))
            #endif
        }
        .onChange(of: store.entries) { _ in
            repairSelection()
        }
        .onChange(of: searchText) { _ in
            repairSelection()
        }
        .onChange(of: selectedCategory) { _ in
            repairSelection()
        }
        .onChange(of: compactEntryPath) { path in
            guard usesCompactNavigation, path == compactEntryPath, let entryID = path.last else { return }
            guard makeListSnapshot().filteredEntries.contains(where: { $0.id == entryID }) else {
                repairSelection()
                return
            }
            if selectedEntryID != entryID { selectedEntryID = entryID }
            sceneActions.refreshAvailability()
        }
        .onChange(of: selectedEntryID) { entryID in
            sceneActions.refreshAvailability()
            guard !usesCompactNavigation, entryID == selectedEntryID else { return }
            synchronizePresentedEntry(with: entryID)
        }
        .onChange(of: store.canMutate) { _ in sceneActions.refreshAvailability() }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                store.flushForBackground()
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .statistics:
                StatisticsDashboardView(entries: store.entries, bodyPresentations: store.bodyPresentations)
            case .settings:
                JournalSettingsView(store: store)
            }
        }
        // Function-valued focus entries can feed back into navigation layout on modern iOS.
        .focusedSceneObject(sceneActions)
        .onDisappear { sceneActions.clearTarget() }
        .alert(store.canMutate ? "无法保存日记" : "无法读取日记", isPresented: errorAlertBinding) {
            Button("好", role: .cancel) {
                store.dismissError()
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var usesCompactNavigation: Bool {
        #if targetEnvironment(macCatalyst)
        false
        #else
        horizontalSizeClass == .compact
        #endif
    }

    private func entryList(using snapshot: JournalEntryListSnapshot) -> some View {
        EntryListView(
            overviewSnapshot: overviewSnapshot,
            snapshot: snapshot,
            bodyPresentations: store.bodyPresentations,
            selection: $selectedEntryID,
            searchText: $searchText,
            selectedCategory: $selectedCategory,
            onCreate: createEntry,
            onDelete: deleteEntry,
            onShowStatistics: showStatistics,
            onShowSettings: { presentedSheet = .settings },
            canCreate: store.canMutate,
            readFailureMessage: store.readFailureMessage,
            usesNativeSelection: !usesCompactNavigation
        )
    }

    @ViewBuilder
    private func detail(for entryID: JournalEntry.ID?, using snapshot: JournalEntryListSnapshot) -> some View {
        if let entryBinding = selectedEntryBinding(for: entryID, using: snapshot),
           let presentation = store.bodyPresentations[entryBinding.wrappedValue.id] {
            EntryEditorView(entry: entryBinding, bodyPresentation: presentation)
        } else {
            EmptyStateView(onCreate: createEntry)
                .disabled(!store.canMutate)
        }
    }

    private func makeListSnapshot() -> JournalEntryListSnapshot {
        JournalEntryListSnapshot(
            entries: store.entries,
            searchText: searchText,
            selectedCategory: selectedCategory
        )
    }

    private var overviewSnapshot: JournalListOverviewSnapshot {
        JournalListOverviewSnapshot(entries: store.entries, bodyPresentations: store.bodyPresentations)
    }

    private func sceneActionTarget() -> JournalContentSceneActions.Target {
        #if targetEnvironment(macCatalyst)
        let presentStatistics = { [openWindow] in openWindow(id: JournalSceneID.statistics) }
        #else
        let presentStatistics = { [sheet = $presentedSheet] in sheet.wrappedValue = .statistics }
        #endif
        return JournalContentSceneActions.Target(
            store: store, selection: $selectedEntryID, searchText: $searchText,
            category: $selectedCategory, compactPath: $compactEntryPath,
            showStatistics: presentStatistics
        )
    }

    private func selectedEntryBinding(
        for selectedEntryID: JournalEntry.ID?,
        using listSnapshot: JournalEntryListSnapshot
    ) -> Binding<JournalEntry>? {
        guard let selectedEntryID,
              JournalEntrySelectionPolicy.repairedSelection(
                  currentSelection: selectedEntryID,
                  visibleEntries: listSnapshot.filteredEntries
              ) == selectedEntryID,
              store.entry(with: selectedEntryID) != nil
        else {
            return nil
        }

        return Binding(
            get: {
                store.entry(with: selectedEntryID) ?? JournalEntry.emptyFallback
            },
            set: { updatedEntry in
                store.update(updatedEntry)
            }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    store.dismissError()
                }
            }
        )
    }

    private func createEntry() {
        sceneActions.createEntry()
    }

    private func showStatistics() {
        #if targetEnvironment(macCatalyst)
        openWindow(id: JournalSceneID.statistics)
        #else
        presentedSheet = .statistics
        #endif
    }

    private func deleteEntry(_ entry: JournalEntry) {
        store.delete(entry)
        repairSelection()
    }

    private func selectInitialEntry() {
        repairSelection()
    }

    private func repairSelection() {
        let currentSelection = usesCompactNavigation ? (compactEntryPath.last ?? selectedEntryID) : selectedEntryID
        selectedEntryID = JournalEntrySelectionPolicy.repairedSelection(
            currentSelection: currentSelection,
            visibleEntries: makeListSnapshot().filteredEntries
        )
        synchronizePresentedEntry(with: selectedEntryID)
        sceneActions.refreshAvailability()
    }

    private func synchronizePresentedEntry(with entryID: JournalEntry.ID?) {
        guard !compactEntryPath.isEmpty else { return }
        let path = entryID.map { [$0] } ?? []
        if compactEntryPath != path { compactEntryPath = path }
    }
}
