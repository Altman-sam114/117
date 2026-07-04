import SwiftUI

@main
struct MDJournalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            JournalCommands()
        }
    }
}

private struct JournalCommands: Commands {
    @FocusedValue(\.createJournalEntryAction) private var createJournalEntryAction
    @FocusedValue(\.showJournalStatisticsAction) private var showJournalStatisticsAction

    var body: some Commands {
        CommandMenu("日记") {
            Button("新建日记") {
                createJournalEntryAction?()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(createJournalEntryAction == nil)

            Button("显示统计") {
                showJournalStatisticsAction?()
            }
            .disabled(showJournalStatisticsAction == nil)
        }
    }
}

private struct CreateJournalEntryActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct ShowJournalStatisticsActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var createJournalEntryAction: (() -> Void)? {
        get { self[CreateJournalEntryActionKey.self] }
        set { self[CreateJournalEntryActionKey.self] = newValue }
    }

    var showJournalStatisticsAction: (() -> Void)? {
        get { self[ShowJournalStatisticsActionKey.self] }
        set { self[ShowJournalStatisticsActionKey.self] = newValue }
    }
}
