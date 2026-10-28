import SwiftUI

@main
struct MDJournalApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = JournalStore()
    @StateObject private var subscriptions = JournalSubscriptionStore(
        startsAutomatically: !JournalApplicationRuntime.isUnitTestHost
    )
    @StateObject private var appLock = JournalAppLockStore()

    var body: some Scene {
        WindowGroup {
            windowContent {
                JournalPrivacyGate {
                    ContentView(store: store)
                    #if targetEnvironment(macCatalyst)
                    .frame(
                        minWidth: MacWindowLayoutContract.minimumWindowWidth,
                        idealWidth: MacWindowLayoutContract.idealWindowWidth,
                        minHeight: MacWindowLayoutContract.minimumWindowHeight,
                        idealHeight: MacWindowLayoutContract.idealWindowHeight
                    )
                    #endif
                }
                .environmentObject(subscriptions)
                .environmentObject(appLock)
                .onChange(of: scenePhase) { phase in
                    if phase == .active && !JournalApplicationRuntime.isUnitTestHost {
                        Task { await subscriptions.refreshEntitlements() }
                    }
                }
            }
        }
        .commands {
            JournalCommands(appLock: appLock)
        }

        #if targetEnvironment(macCatalyst)
        WindowGroup("统计", id: JournalSceneID.statistics) {
            windowContent {
                JournalPrivacyGate {
                    StatisticsDashboardView(
                        entries: store.entries, bodyPresentations: store.bodyPresentations, showsCloseButton: false
                    )
                        .frame(minWidth: 720, idealWidth: 980, minHeight: 560, idealHeight: 720)
                }
                .environmentObject(subscriptions)
                .environmentObject(appLock)
            }
        }
        #endif
    }

    @ViewBuilder
    private func windowContent<Content: View>(@ViewBuilder productionContent: () -> Content) -> some View {
        #if DEBUG
        if JournalApplicationRuntime.isUnitTestHost {
            // Tests install their own production views; retain no second app view graph in the scene.
            Color.clear
        } else {
            productionContent()
        }
        #else
        productionContent()
        #endif
    }
}

private enum JournalApplicationRuntime {
    static let isUnitTestHost: Bool = {
        #if DEBUG
        // Integration tests own their production view roots and StoreKit sessions.
        let isHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
        if isHost { print("Unit-test app host: empty scene root; automatic subscription queries disabled") }
        return isHost
        #else
        return false
        #endif
    }()
}

enum JournalSceneID {
    static let statistics = "journal-statistics"
}

internal enum MacWindowLayoutContract {
    static let minimumWindowWidth: CGFloat = 1120
    static let minimumWindowHeight: CGFloat = 720
    static let idealWindowWidth: CGFloat = 1360
    static let idealWindowHeight: CGFloat = 860
    static let sidebarMinimumWidth: CGFloat = 260
    static let sidebarIdealWidth: CGFloat = 300
    static let sidebarMaximumWidth: CGFloat = 360
}

private struct JournalCommands: Commands {
    @ObservedObject var appLock: JournalAppLockStore
    @FocusedObject private var journalActions: JournalContentSceneActions?
    @FocusedObject private var editorActions: EntryEditorSceneActions?

    private var allowsJournalAccess: Bool {
        !appLock.isEnabled || appLock.state == .unlocked
    }

    var body: some Commands {
        CommandMenu("日记") {
            Button("新建日记") {
                guard allowsJournalAccess else { return }
                journalActions?.createEntry()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(!allowsJournalAccess || journalActions?.availability.canCreate != true)

            Divider()

            ForEach(JournalEntryNavigationDirection.allCases) { direction in
                let shortcut = JournalEntryNavigationShortcut(direction: direction)

                Button(direction.title) {
                    guard allowsJournalAccess else { return }
                    journalActions?.select(direction)
                }
                .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
                .disabled(!allowsJournalAccess || journalActions?.canSelect(direction) != true)
            }

            Divider()

            Button("显示统计") {
                guard allowsJournalAccess else { return }
                journalActions?.showStatistics()
            }
                .disabled(!allowsJournalAccess || journalActions?.availability.hasTarget != true)
        }

        CommandMenu("写作") {
            ForEach(EditorWritingCommand.allCases) { command in
                let shortcut = EditorWritingCommandShortcut(command: command)

                Button(command.title) {
                    action(for: command)?()
                }
                .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
                .disabled(action(for: command) == nil)
            }
        }

        CommandMenu("插入 Markdown") {
            ForEach(MarkdownSnippet.allCases) { snippet in
                let shortcut = MarkdownSnippetCommandShortcut(snippet: snippet)

                Button("插入\(snippet.title)") {
                    guard allowsJournalAccess else { return }
                    editorActions?.insertMarkdownSnippet(snippet)
                }
                .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
                .disabled(!allowsJournalAccess || editorActions == nil)
            }
        }
    }

    private func action(for command: EditorWritingCommand) -> (() -> Void)? {
        guard allowsJournalAccess, let editorActions else { return nil }
        switch command {
        case .focusBody:
            return editorActions.focusBody
        case .focusWriting:
            return editorActions.focusWriting
        case .indentLines, .outdentLines:
            guard let indentationDirection = command.indentationDirection else {
                return nil
            }
            return {
                editorActions.applyIndentation(indentationDirection)
            }
        case .togglePreview:
            return editorActions.togglePreview
        }
    }
}
