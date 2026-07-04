import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    #if targetEnvironment(macCatalyst)
    @Environment(\.openWindow) private var openWindow
    #endif

    @ObservedObject var store: JournalStore
    @State private var selectedEntryID: JournalEntry.ID?
    @State private var isShowingStatistics = false

    var body: some View {
        NavigationSplitView {
            EntryListView(
                entries: store.entries,
                selection: $selectedEntryID,
                onCreate: createEntry,
                onDelete: deleteEntry,
                onShowStatistics: showStatistics
            )
        } detail: {
            if let entryBinding = selectedEntryBinding {
                EntryEditorView(entry: entryBinding)
            } else {
                EmptyStateView(onCreate: createEntry)
            }
        }
        .tint(.teal)
        .onAppear(perform: selectInitialEntry)
        .onChange(of: store.entries) { entries in
            repairSelection(with: entries)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                store.flushPendingSave()
            }
        }
        .sheet(isPresented: $isShowingStatistics) {
            StatisticsDashboardView(entries: store.entries)
        }
        .focusedSceneValue(\.createJournalEntryAction, createEntry)
        .focusedSceneValue(\.showJournalStatisticsAction, showStatistics)
        .alert("无法保存日记", isPresented: errorAlertBinding) {
            Button("好", role: .cancel) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var selectedEntryBinding: Binding<JournalEntry>? {
        guard let selectedEntryID, store.entry(with: selectedEntryID) != nil else {
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
                    store.errorMessage = nil
                }
            }
        )
    }

    private func createEntry() {
        selectedEntryID = store.createEntry()
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
        repairSelection(with: store.entries)
    }

    private func selectInitialEntry() {
        guard selectedEntryID == nil else { return }
        selectedEntryID = store.entries.first?.id
    }

    private func repairSelection(with entries: [JournalEntry]) {
        if let selectedEntryID, entries.contains(where: { $0.id == selectedEntryID }) {
            return
        }

        selectedEntryID = entries.first?.id
    }
}
