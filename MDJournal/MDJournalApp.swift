import SwiftUI

@main
struct MDJournalApp: App {
    @StateObject private var store = JournalStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .commands {
            JournalCommands()
        }

        #if targetEnvironment(macCatalyst)
        WindowGroup("统计", id: JournalSceneID.statistics) {
            StatisticsDashboardView(entries: store.entries, showsCloseButton: false)
                .frame(minWidth: 720, idealWidth: 980, minHeight: 560, idealHeight: 720)
        }
        #endif
    }
}

enum JournalSceneID {
    static let statistics = "journal-statistics"
}

private struct JournalCommands: Commands {
    @FocusedValue(\.createJournalEntryAction) private var createJournalEntryAction
    @FocusedValue(\.showJournalStatisticsAction) private var showJournalStatisticsAction
    @FocusedValue(\.insertMarkdownSnippetAction) private var insertMarkdownSnippetAction
    @FocusedValue(\.focusEditorBodyAction) private var focusEditorBodyAction
    @FocusedValue(\.toggleEditorPreviewAction) private var toggleEditorPreviewAction
    @FocusedValue(\.applyEditorIndentationAction) private var applyEditorIndentationAction

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
                    insertMarkdownSnippetAction?(snippet)
                }
                .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
                .disabled(insertMarkdownSnippetAction == nil)
            }
        }
    }

    private func action(for command: EditorWritingCommand) -> (() -> Void)? {
        switch command {
        case .focusBody:
            return focusEditorBodyAction
        case .indentLines, .outdentLines:
            guard let indentationDirection = command.indentationDirection,
                  let applyEditorIndentationAction
            else {
                return nil
            }
            return {
                applyEditorIndentationAction(indentationDirection)
            }
        case .togglePreview:
            return toggleEditorPreviewAction
        }
    }
}

private struct CreateJournalEntryActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct ShowJournalStatisticsActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct InsertMarkdownSnippetActionKey: FocusedValueKey {
    typealias Value = (MarkdownSnippet) -> Void
}

private struct FocusEditorBodyActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct ToggleEditorPreviewActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct ApplyEditorIndentationActionKey: FocusedValueKey {
    typealias Value = (MarkdownLineIndentation.Direction) -> Void
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

    var insertMarkdownSnippetAction: ((MarkdownSnippet) -> Void)? {
        get { self[InsertMarkdownSnippetActionKey.self] }
        set { self[InsertMarkdownSnippetActionKey.self] = newValue }
    }

    var focusEditorBodyAction: (() -> Void)? {
        get { self[FocusEditorBodyActionKey.self] }
        set { self[FocusEditorBodyActionKey.self] = newValue }
    }

    var toggleEditorPreviewAction: (() -> Void)? {
        get { self[ToggleEditorPreviewActionKey.self] }
        set { self[ToggleEditorPreviewActionKey.self] = newValue }
    }

    var applyEditorIndentationAction: ((MarkdownLineIndentation.Direction) -> Void)? {
        get { self[ApplyEditorIndentationActionKey.self] }
        set { self[ApplyEditorIndentationActionKey.self] = newValue }
    }
}
