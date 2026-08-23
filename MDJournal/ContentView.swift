import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    #if targetEnvironment(macCatalyst)
    @Environment(\.openWindow) private var openWindow
    #endif

    @ObservedObject var store: JournalStore
    @State private var selectedEntryID: JournalEntry.ID?
    @State private var searchText = ""
    @State private var selectedCategory: JournalEntry.Category?
    @State private var isShowingStatistics = false

    var body: some View {
        let listSnapshot = makeListSnapshot()

        NavigationSplitView {
            EntryListView(
                overviewSnapshot: overviewSnapshot,
                snapshot: listSnapshot,
                selection: $selectedEntryID,
                searchText: $searchText,
                selectedCategory: $selectedCategory,
                onCreate: createEntry,
                onDelete: deleteEntry,
                onShowStatistics: showStatistics
            )
            #if targetEnvironment(macCatalyst)
            .navigationSplitViewColumnWidth(
                min: MacWindowLayoutContract.sidebarMinimumWidth,
                ideal: MacWindowLayoutContract.sidebarIdealWidth,
                max: MacWindowLayoutContract.sidebarMaximumWidth
            )
            #endif
        } detail: {
            if let entryBinding = selectedEntryBinding(using: listSnapshot) {
                EntryEditorView(entry: entryBinding)
            } else {
                EmptyStateView(onCreate: createEntry)
            }
        }
        .tint(.teal)
        .onAppear(perform: selectInitialEntry)
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
        .sheet(isPresented: $isShowingStatistics) {
            StatisticsDashboardView(entries: store.entries)
        }
        .focusedSceneValue(\.createJournalEntryAction, createEntry)
        .focusedSceneValue(\.showJournalStatisticsAction, showStatistics)
        .focusedSceneValue(
            \.journalEntryNavigationActions,
            journalEntryNavigationActions(using: listSnapshot)
        )
        .alert("无法保存日记", isPresented: errorAlertBinding) {
            Button("好", role: .cancel) {
                store.dismissError()
            }
        } message: {
            Text(store.errorMessage ?? "")
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
        JournalListOverviewSnapshot(entries: store.entries)
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
        let createdID = store.createEntry()
        selectedEntryID = JournalEntrySelectionPolicy.repairedSelection(
            currentSelection: createdID,
            visibleEntries: makeListSnapshot().filteredEntries
        )
    }

    private func showStatistics() {
        #if targetEnvironment(macCatalyst)
        openWindow(id: JournalSceneID.statistics)
        #else
        isShowingStatistics = true
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
    }
}
