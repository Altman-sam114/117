import SwiftUI

enum EntryEditorAccessibilityContract {
    static let journalDateLabel = "日记日期"
}

internal enum EntryEditorLayoutAxis: Equatable {
    case horizontal
    case vertical
}

internal struct EntryEditorLayoutContract: Equatable {
    static let wideLayoutMinimumWidth: CGFloat = 820
    static let splitPreviewMinimumWidth: CGFloat = 1120
    static let regularWideStatisticsWidth: CGFloat = 270
    static let sectionCardBaseWidth: CGFloat = 156

    let isWideEditorLayout: Bool
    let usesSplitPreview: Bool
    let usesCompactHeaderLayout: Bool
    let metadataAxis: EntryEditorLayoutAxis
    let summaryAxis: EntryEditorLayoutAxis
    let statisticsPillAxis: EntryEditorLayoutAxis
    let statisticsWidth: CGFloat?
    let titleLineLimit: Int?
    let sectionTitleLineLimit: Int
    let sectionExcerptLineLimit: Int

    init(width: CGFloat, dynamicTypeSize: DynamicTypeSize) {
        let isAccessibilitySize = dynamicTypeSize.isAccessibilitySize
        let isWideEditorLayout = width >= Self.wideLayoutMinimumWidth
        let usesCompactHeaderLayout = isWideEditorLayout && !isAccessibilitySize

        self.isWideEditorLayout = isWideEditorLayout
        usesSplitPreview = width >= Self.splitPreviewMinimumWidth && !isAccessibilitySize
        self.usesCompactHeaderLayout = usesCompactHeaderLayout
        metadataAxis = usesCompactHeaderLayout ? .horizontal : .vertical
        summaryAxis = usesCompactHeaderLayout ? .horizontal : .vertical
        statisticsPillAxis = isAccessibilitySize ? .vertical : .horizontal
        statisticsWidth = usesCompactHeaderLayout ? Self.regularWideStatisticsWidth : nil
        titleLineLimit = isAccessibilitySize ? nil : 2
        sectionTitleLineLimit = isAccessibilitySize ? 2 : 1
        sectionExcerptLineLimit = isAccessibilitySize ? 3 : 2
    }
}

internal enum EntryEditorFocusPolicy {
    enum Transition: Equatable {
        case enterPreview
        case returnToEditFromPreviewCommand
        case selectEditModeFromPicker
    }

    enum Action: Equatable {
        case resign
        case focus
        case preserve
    }

    static func action(for transition: Transition) -> Action {
        switch transition {
        case .enterPreview:
            return .resign
        case .returnToEditFromPreviewCommand:
            return .focus
        case .selectEditModeFromPicker:
            return .preserve
        }
    }
}

internal struct EntryEditorWorkspaceState: Equatable {
    enum Mode: String, CaseIterable, Identifiable {
        case edit = "编辑"
        case preview = "预览"

        var id: String { rawValue }
    }

    enum Action {
        case selectMode(Mode)
        case togglePreview
        case focusBody
        case focusWriting
    }

    private(set) var mode: Mode = .edit
    private(set) var isPreviewColumnVisible = true
    private(set) var usesSplitPreview = false
    var editorFocused = false
    var bodySelectedRange = NSRange(location: NSNotFound, length: 0)

    var showsEditor: Bool { usesSplitPreview || mode == .edit }
    var showsPreview: Bool { usesSplitPreview ? isPreviewColumnVisible : mode == .preview }

    var previewToggleTitle: String {
        EditorWritingCommand.previewToggleTitle(
            isWideLayoutActive: usesSplitPreview,
            isPreviewColumnVisible: isPreviewColumnVisible,
            isPreviewModeActive: mode == .preview
        )
    }

    func resolved(for layout: EntryEditorLayoutContract) -> Self {
        var result = self
        result.updateLayout(layout)
        return result
    }

    mutating func updateLayout(_ layout: EntryEditorLayoutContract) {
        guard usesSplitPreview != layout.usesSplitPreview else { return }

        if layout.usesSplitPreview {
            if mode == .preview {
                isPreviewColumnVisible = true
            }
            mode = .edit
        } else {
            mode = !editorFocused && isPreviewColumnVisible ? .preview : .edit
        }
        usesSplitPreview = layout.usesSplitPreview
    }

    mutating func perform(_ action: Action, layout: EntryEditorLayoutContract) {
        updateLayout(layout)
        switch action {
        case let .selectMode(newMode):
            guard !usesSplitPreview, newMode != mode else { return }
            mode = newMode
            applyFocusPolicy(newMode == .preview ? .enterPreview : .selectEditModeFromPicker)
        case .togglePreview:
            if usesSplitPreview {
                mode = .edit
                isPreviewColumnVisible.toggle()
            } else if mode == .preview {
                mode = .edit
                applyFocusPolicy(.returnToEditFromPreviewCommand)
            } else {
                mode = .preview
                applyFocusPolicy(.enterPreview)
            }
        case .focusBody:
            mode = .edit
            editorFocused = true
        case .focusWriting:
            mode = .edit
            isPreviewColumnVisible = false
            editorFocused = true
        }
    }

    private mutating func applyFocusPolicy(_ transition: EntryEditorFocusPolicy.Transition) {
        switch EntryEditorFocusPolicy.action(for: transition) {
        case .resign:
            editorFocused = false
        case .focus:
            editorFocused = true
        case .preserve:
            break
        }
    }
}

struct EntryEditorView: View {
    typealias Mode = EntryEditorWorkspaceState.Mode

    @Binding var entry: JournalEntry
    @State private var workspaceState = EntryEditorWorkspaceState()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let focusedWritingMaxWidth: CGFloat = 920

    var body: some View {
        GeometryReader { proxy in
            let layout = EntryEditorLayoutContract(
                width: proxy.size.width,
                dynamicTypeSize: dynamicTypeSize
            )
            let bodyMetrics = entry.bodyMetrics
            let workspace = workspaceState.resolved(for: layout)

            VStack(spacing: 0) {
                header(layout: layout, bodyMetrics: bodyMetrics)
                editorWorkspace(
                    layout: layout,
                    workspace: workspace,
                    width: proxy.size.width,
                    bodyMetrics: bodyMetrics
                )
            }
            .onAppear {
                workspaceState.updateLayout(layout)
            }
            .onChange(of: layout.usesSplitPreview) { _ in
                workspaceState.updateLayout(layout)
            }
            .toolbar { editorToolbar(layout: layout, workspace: workspace) }
            .focusedSceneValue(\.insertMarkdownSnippetAction, { insertSnippet($0, layout: layout) })
            .focusedSceneValue(\.focusEditorBodyAction, { perform(.focusBody, layout: layout) })
            .focusedSceneValue(\.focusEditorWritingAction, { perform(.focusWriting, layout: layout) })
            .focusedSceneValue(\.toggleEditorPreviewAction, { perform(.togglePreview, layout: layout) })
            .focusedSceneValue(\.applyEditorIndentationAction, { applyIndentation($0, layout: layout) })
        }
        .navigationTitle(entry.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onChange(of: entry.id) { _ in
            resetBodySelectionToEnd()
        }
    }

    @ToolbarContentBuilder
    private func editorToolbar(
        layout: EntryEditorLayoutContract,
        workspace: EntryEditorWorkspaceState
    ) -> some ToolbarContent {
        #if targetEnvironment(macCatalyst)
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                perform(.focusBody, layout: layout)
            } label: {
                Label(EditorWritingCommand.focusBody.title, systemImage: EditorWritingCommand.focusBody.systemImage)
            }
            .help(EditorWritingCommand.focusBody.helpText)
            .accessibilityLabel(EditorWritingCommand.focusBody.title)

            Button {
                perform(.focusWriting, layout: layout)
            } label: {
                Label(
                    EditorWritingCommand.focusWriting.title,
                    systemImage: EditorWritingCommand.focusWriting.systemImage
                )
            }
            .help(EditorWritingCommand.focusWriting.helpText)
            .accessibilityLabel(EditorWritingCommand.focusWriting.title)

            Button {
                applyIndentation(.outdent, layout: layout)
            } label: {
                Label(
                    EditorWritingCommand.outdentLines.title,
                    systemImage: EditorWritingCommand.outdentLines.systemImage
                )
            }
            .help(EditorWritingCommand.outdentLines.helpText)
            .accessibilityLabel(EditorWritingCommand.outdentLines.title)

            Button {
                applyIndentation(.indent, layout: layout)
            } label: {
                Label(
                    EditorWritingCommand.indentLines.title,
                    systemImage: EditorWritingCommand.indentLines.systemImage
                )
            }
            .help(EditorWritingCommand.indentLines.helpText)
            .accessibilityLabel(EditorWritingCommand.indentLines.title)

            Menu {
                ForEach(MarkdownSnippet.allCases) { snippet in
                    Button {
                        insertSnippet(snippet, layout: layout)
                    } label: {
                        Label(snippet.title, systemImage: snippet.systemImage)
                    }
                }
            } label: {
                Label("插入", systemImage: "plus.rectangle.on.rectangle")
            }
            .help(EditorWritingCommand.insertMarkdownAccessibilityLabel)
            .accessibilityLabel(EditorWritingCommand.insertMarkdownAccessibilityLabel)

            Button {
                perform(.togglePreview, layout: layout)
            } label: {
                Label(
                    workspace.previewToggleTitle,
                    systemImage: EditorWritingCommand.togglePreview.systemImage
                )
            }
            .help(EditorWritingCommand.togglePreview.helpText(title: workspace.previewToggleTitle))
            .accessibilityLabel(workspace.previewToggleTitle)
        }
        #endif

        ToolbarItem(placement: .primaryAction) {
            ShareLink(item: entry.markdownDocument, subject: Text(entry.displayTitle)) {
                Label("分享", systemImage: "square.and.arrow.up")
            }
        }

        ToolbarItemGroup(placement: .keyboard) {
            Button("完成") {
                workspaceState.editorFocused = false
            }
        }
    }

    private func header(layout: EntryEditorLayoutContract, bodyMetrics: JournalEntryBodyMetrics) -> some View {
        let summaryLayout = layout.summaryAxis == .horizontal
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))

        return VStack(alignment: .leading, spacing: 14) {
            metadata(layout: layout)

            TextField("今天的标题", text: $entry.title, axis: .vertical)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
                .lineLimit(layout.titleLineLimit)

            summaryLayout {
                statPills(bodyMetrics, axis: layout.statisticsPillAxis)
                    .frame(width: layout.statisticsWidth, alignment: .leading)

                JournalSectionOverview(
                    sections: bodyMetrics.sections,
                    accent: entry.category.tint,
                    titleLineLimit: layout.sectionTitleLineLimit,
                    excerptLineLimit: layout.sectionExcerptLineLimit
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(headerBackground)
    }

    private func metadata(layout: EntryEditorLayoutContract) -> some View {
        let metadataLayout = layout.metadataAxis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        let dateAlignment: Alignment = layout.metadataAxis == .horizontal ? .trailing : .leading

        return metadataLayout {
            categoryPicker
            moodPicker
            DatePicker(
                EntryEditorAccessibilityContract.journalDateLabel,
                selection: $entry.createdAt,
                displayedComponents: .date
            )
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(
                    maxWidth: layout.metadataAxis == .horizontal ? .infinity : nil,
                    alignment: dateAlignment
                )
        }
    }

    private var headerBackground: some View {
        LinearGradient(
            colors: [
                entry.category.tint.opacity(0.16),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func statPills(
        _ bodyMetrics: JournalEntryBodyMetrics,
        axis: EntryEditorLayoutAxis
    ) -> some View {
        let pillLayout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))

        return pillLayout {
            EditorStatPill(value: "\(bodyMetrics.wordCount)", title: "词", systemImage: "text.word.spacing")
            EditorStatPill(value: "\(bodyMetrics.sectionCount)", title: "小节", systemImage: "list.bullet.rectangle")
            EditorStatPill(value: entry.updatedAt.journalRelativeUpdateText, title: "更新", systemImage: "clock")
        }
    }

    private var categoryPicker: some View {
        Menu {
            ForEach(JournalEntry.Category.allCases) { category in
                Button {
                    entry.category = category
                } label: {
                    Label(category.rawValue, systemImage: category.systemImage)
                }
            }
        } label: {
            Label(entry.category.rawValue, systemImage: entry.category.systemImage)
                .font(.footnote.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .foregroundStyle(entry.category.tint)
                .background(entry.category.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var moodPicker: some View {
        Menu {
            ForEach(JournalEntry.Mood.allCases) { mood in
                Button {
                    entry.mood = mood
                } label: {
                    Label(mood.rawValue, systemImage: mood.systemImage)
                }
            }
        } label: {
            Label(entry.mood.rawValue, systemImage: entry.mood.systemImage)
                .font(.footnote.weight(.medium))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .foregroundStyle(.secondary)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func editor(
        layout: EntryEditorLayoutContract,
        bodyMetrics: JournalEntryBodyMetrics,
        limitsWritingWidth: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            MarkdownToolbar(accent: entry.category.tint) { insertSnippet($0, layout: layout) }
            Divider()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                bodyEditorArea(bodyMetrics: bodyMetrics)
                    .frame(maxWidth: limitsWritingWidth ? focusedWritingMaxWidth : .infinity)
                Spacer(minLength: 0)
            }
            .background(Color(.systemBackground))
        }
    }

    private func bodyEditorArea(bodyMetrics: JournalEntryBodyMetrics) -> some View {
        ZStack(alignment: .topLeading) {
            if !bodyMetrics.hasVisibleContent {
                Text("用 ### 小节组织今天的记录。")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
            }

            MarkdownBodyTextView(
                text: $entry.body,
                selectedRange: $workspaceState.bodySelectedRange,
                isFocused: $workspaceState.editorFocused
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func editorWorkspace(
        layout: EntryEditorLayoutContract,
        workspace: EntryEditorWorkspaceState,
        width: CGFloat,
        bodyMetrics: JournalEntryBodyMetrics
    ) -> some View {
        let showsBoth = workspace.showsEditor && workspace.showsPreview
        let columnWidth: CGFloat? = showsBoth ? max(0, (width - 1) / 2) : nil

        return VStack(spacing: 0) {
            if !workspace.usesSplitPreview {
                Picker("模式", selection: compactModeSelection(layout: layout)) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            // Keep the editor at one structural position across split and width changes.
            HStack(spacing: 0) {
                if workspace.showsEditor {
                    VStack(spacing: 0) {
                        if workspace.usesSplitPreview {
                            WorkspacePaneHeader(title: "编辑", systemImage: "square.and.pencil", tint: entry.category.tint)
                        }
                        editor(
                            layout: layout,
                            bodyMetrics: bodyMetrics,
                            limitsWritingWidth: workspace.usesSplitPreview && !workspace.showsPreview
                        )
                    }
                    .frame(width: columnWidth)
                    .frame(maxWidth: .infinity)
                }

                if showsBoth {
                    Divider().frame(width: 1)
                }

                if workspace.showsPreview {
                    VStack(spacing: 0) {
                        if workspace.usesSplitPreview {
                            WorkspacePaneHeader(title: "预览", systemImage: "doc.richtext", tint: entry.category.tint)
                        }
                        MarkdownPreviewView(
                            entryID: entry.id,
                            markdown: entry.body,
                            accent: entry.category.tint,
                            maxContentWidth: workspace.usesSplitPreview ? 560 : 720
                        )
                    }
                    .frame(width: columnWidth)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
        }
    }

    private func compactModeSelection(layout: EntryEditorLayoutContract) -> Binding<Mode> {
        Binding(
            get: { workspaceState.resolved(for: layout).mode },
            set: { perform(.selectMode($0), layout: layout) }
        )
    }

    private func perform(_ action: EntryEditorWorkspaceState.Action, layout: EntryEditorLayoutContract) {
        workspaceState.perform(action, layout: layout)
    }

    private func resetBodySelectionToEnd() {
        workspaceState.bodySelectedRange = NSRange(location: entry.body.utf16.count, length: 0)
    }

    private func applyIndentation(_ direction: MarkdownLineIndentation.Direction, layout: EntryEditorLayoutContract) {
        perform(.focusBody, layout: layout)

        guard let result = MarkdownLineIndentation.apply(
            to: entry.body,
            selectedRange: workspaceState.bodySelectedRange,
            direction: direction
        ) else {
            return
        }

        entry.body = result.body
        workspaceState.bodySelectedRange = result.selectedRange
    }

    private func insertSnippet(_ snippet: MarkdownSnippet, layout: EntryEditorLayoutContract) {
        perform(.focusBody, layout: layout)
        let result = MarkdownSnippetInsertion.apply(
            snippet: snippet,
            to: entry.body,
            selectedRange: workspaceState.bodySelectedRange
        )

        entry.body = result.body
        workspaceState.bodySelectedRange = result.selectedRange
    }

}

private struct WorkspacePaneHeader: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(.systemBackground))
    }
}

private struct EditorStatPill: View {
    let value: String
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            HStack(spacing: 3) {
                Text(value)
                    .fontWeight(.semibold)
                Text(title)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct JournalSectionOverview: View {
    let sections: [JournalSection]
    let accent: Color
    let titleLineLimit: Int
    let excerptLineLimit: Int

    @ScaledMetric(relativeTo: .caption)
    private var sectionCardWidth = EntryEditorLayoutContract.sectionCardBaseWidth

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("### 小节", systemImage: "number")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(sections.isEmpty ? "建议添加" : "\(sections.count) 个")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if sections.isEmpty {
                Text("用 `### 今天发生了什么` 这样的标题，把日记拆成可回看的段落。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(section.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(accent)
                                    .lineLimit(titleLineLimit)

                                Text(section.excerpt)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(excerptLineLimit)
                            }
                            .padding(10)
                            .frame(width: sectionCardWidth, alignment: .leading)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(accent.opacity(0.18), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }
}
