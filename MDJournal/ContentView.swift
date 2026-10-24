import SwiftUI

#if DEBUG
struct JournalContentInteraction {
    let compactPath: Binding<[JournalEntry.ID]>
    let searchText: Binding<String>
    let selectedCategory: Binding<JournalEntry.Category?>
    let createEntry: () -> Void
}
#endif

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
    @State private var selectedEntryID: JournalEntry.ID?
    @State private var searchText = ""
    @State private var selectedCategory: JournalEntry.Category?
    @State private var presentedSheet: Sheet?
    @State private var isCompactDetailPresented = false
    #if DEBUG
    var interactionObserver: ((JournalContentInteraction) -> Void)? = nil
    #endif

    var body: some View {
        let listSnapshot = makeListSnapshot()

        Group {
            if usesCompactNavigation {
                NavigationStack(path: compactPath) {
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
            #if DEBUG
            interactionObserver?(JournalContentInteraction(
                compactPath: compactPath, searchText: $searchText,
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
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                Task {
                    await store.flushPendingSave()
                }
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
        .focusedSceneValue(\.createJournalEntryAction, createEntry)
        .focusedSceneValue(\.showJournalStatisticsAction, showStatistics)
        .focusedSceneValue(
            \.journalEntryNavigationActions,
            journalEntryNavigationActions(using: listSnapshot)
        )
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

    private var compactPath: Binding<[JournalEntry.ID]> {
        Binding(
            get: {
                guard isCompactDetailPresented, let selectedEntryID else { return [] }
                return [selectedEntryID]
            },
            set: { path in
                guard let entryID = path.last else {
                    isCompactDetailPresented = false
                    return
                }
                guard makeListSnapshot().filteredEntries.contains(where: { $0.id == entryID }) else {
                    repairSelection()
                    return
                }
                selectedEntryID = entryID
                isCompactDetailPresented = true
            }
        )
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
            readFailureMessage: store.readFailureMessage
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

    private func journalEntryNavigationActions(
        using listSnapshot: JournalEntryListSnapshot
    ) -> JournalEntryNavigationActions {
        let newerID = JournalEntryNavigation.destinationID(
            in: listSnapshot.filteredEntries,
            selection: selectedEntryID,
            direction: .newer
        )
        let olderID = JournalEntryNavigation.destinationID(
            in: listSnapshot.filteredEntries,
            selection: selectedEntryID,
            direction: .older
        )

        return JournalEntryNavigationActions(
            selectNewer: newerID.map { destinationID in
                { selectedEntryID = destinationID }
            },
            selectOlder: olderID.map { destinationID in
                { selectedEntryID = destinationID }
            }
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
        guard let createdID = store.createEntry() else { return }
        searchText = ""
        selectedCategory = nil
        selectedEntryID = createdID
        isCompactDetailPresented = true
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
        selectedEntryID = JournalEntrySelectionPolicy.repairedSelection(
            currentSelection: selectedEntryID,
            visibleEntries: makeListSnapshot().filteredEntries
        )
        if selectedEntryID == nil {
            isCompactDetailPresented = false
        }
    }
}
