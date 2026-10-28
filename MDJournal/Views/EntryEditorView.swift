import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct JournalMarkdownShareItem: Transferable {
    let entry: JournalEntry

    func markdownData() -> Data {
        Data(entry.markdownDocument.utf8)
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .utf8PlainText) { item in
            item.markdownData()
        }
        .suggestedFileName("Journal.md")
    }
}

#if DEBUG
struct JournalEditorInteraction {
    let sceneActions: EntryEditorSceneActions
    let titleFocus: FocusState<Bool>.Binding
    let dismissKeyboard: () -> Void
    let focusBody: () -> Void
    let enterPreview: () -> Void
    let returnToEdit: () -> Void
}
#endif

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
        titleLineLimit = isAccessibilitySize ? nil : (isWideEditorLayout ? 2 : 3)
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

@MainActor
struct EntryEditorActionTarget {
    let entry: Binding<JournalEntry>
    let workspace: Binding<EntryEditorWorkspaceState>
    let titleFocus: FocusState<Bool>.Binding
    let showsDetails: Binding<Bool>
    var layout: EntryEditorLayoutContract

    func perform(_ action: EntryEditorWorkspaceState.Action) {
        if case .focusWriting = action { showsDetails.wrappedValue = false }
        var updatedWorkspace = workspace.wrappedValue
        updatedWorkspace.perform(action, layout: layout)
        if updatedWorkspace.editorFocused || !updatedWorkspace.showsEditor {
            titleFocus.wrappedValue = false
        }
        workspace.wrappedValue = updatedWorkspace
    }

    func applyIndentation(_ direction: MarkdownLineIndentation.Direction) {
        perform(.focusBody)
        guard let result = MarkdownLineIndentation.apply(
            to: entry.wrappedValue.body,
            selectedRange: workspace.wrappedValue.bodySelectedRange,
            direction: direction
        ) else { return }

        entry.wrappedValue.body = result.body
        workspace.wrappedValue.bodySelectedRange = result.selectedRange
    }

    func insertSnippet(_ snippet: MarkdownSnippet) {
        perform(.focusBody)
        let result = MarkdownSnippetInsertion.apply(
            snippet: snippet,
            to: entry.wrappedValue.body,
            selectedRange: workspace.wrappedValue.bodySelectedRange
        )
        entry.wrappedValue.body = result.body
        workspace.wrappedValue.bodySelectedRange = result.selectedRange
    }
}

/// The scene publishes this object's identity; commands resolve its current editor bindings.
@MainActor
final class EntryEditorSceneActions: ObservableObject {
    private var target: EntryEditorActionTarget?
    private(set) var layout: EntryEditorLayoutContract?

    #if DEBUG
    var targetEntryID: JournalEntry.ID? { target?.entry.wrappedValue.id }
    #endif

    private(set) lazy var insertMarkdownSnippet: (MarkdownSnippet) -> Void = { [weak self] snippet in
        self?.target?.insertSnippet(snippet)
    }
    private(set) lazy var focusBody: () -> Void = { [weak self] in
        self?.target?.perform(.focusBody)
    }
    private(set) lazy var focusWriting: () -> Void = { [weak self] in
        self?.target?.perform(.focusWriting)
    }
    private(set) lazy var togglePreview: () -> Void = { [weak self] in
        self?.target?.perform(.togglePreview)
    }
    private(set) lazy var applyIndentation: (MarkdownLineIndentation.Direction) -> Void = { [weak self] direction in
        self?.target?.applyIndentation(direction)
    }

    func updateTarget(_ target: EntryEditorActionTarget) {
        self.target = target
        layout = target.layout
    }

    func updateLayout(_ layout: EntryEditorLayoutContract) {
        // A retained geometry callback must never restore an earlier journal binding.
        self.layout = layout
        target?.layout = layout
    }

    func perform(_ action: EntryEditorWorkspaceState.Action) {
        target?.perform(action)
    }

    func clearTarget() {
        target = nil
    }
}

@MainActor
struct EntryEditorView: View {
    typealias Mode = EntryEditorWorkspaceState.Mode

    @Binding var entry: JournalEntry
    let bodyPresentation: JournalEntryBodyPresentation
    @State private var workspaceState = EntryEditorWorkspaceState()
    @StateObject private var sceneActions = EntryEditorSceneActions()
    @State private var showsDetails = false
    @State private var headerContentHeight: CGFloat = 0
    @FocusState private var titleFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if DEBUG
    var interactionObserver: ((JournalEditorInteraction) -> Void)? = nil
    #endif

    private let focusedWritingMaxWidth = JournalTheme.readableWidth

    var body: some View {
        let currentEntry = $entry

        GeometryReader { proxy in
            let layout = EntryEditorLayoutContract(
                width: proxy.size.width,
                dynamicTypeSize: dynamicTypeSize
            )
            let bodyMetrics = bodyPresentation
            let workspace = workspaceState.resolved(for: layout)
            let canvas = EntryEditorCanvasLayout(
                width: proxy.size.width, height: proxy.size.height,
                dynamicTypeSize: dynamicTypeSize, usesSplitPreview: layout.usesSplitPreview
            )
            let compactHeight = EntryEditorChromeLayout.isCompactHeight(canvas.paperHeight)
            let inlineTools = EntryEditorChromeLayout.usesInlineTools(
                availableWidth: canvas.paperWidth, availableHeight: canvas.paperHeight,
                dynamicTypeSize: dynamicTypeSize
            )
            let headerBudget = EntryEditorChromeLayout.headerHeight(
                availableHeight: canvas.paperHeight,
                showsDetails: showsDetails, dynamicTypeSize: dynamicTypeSize
            )

            VStack(spacing: 0) {
                ScrollView(.vertical) {
                    header(layout: layout, bodyMetrics: bodyMetrics, compactHeight: compactHeight)
                        .background {
                            GeometryReader { headerProxy in
                                Color.clear.preference(key: EditorHeaderHeightKey.self, value: headerProxy.size.height)
                            }
                        }
                }
                .frame(height: min(headerContentHeight > 0 ? headerContentHeight : headerBudget, headerBudget))
                .onPreferenceChange(EditorHeaderHeightKey.self) { height in
                    if abs(headerContentHeight - height) > 0.5 { headerContentHeight = height }
                }
                Divider()
                editorWorkspace(
                    layout: layout,
                    workspace: workspace,
                    width: canvas.paperWidth,
                    bodyMetrics: bodyMetrics,
                    inlineTools: inlineTools
                )
                if !compactHeight { writingStatus(bodyMetrics) }
            }
            .frame(width: canvas.paperWidth, height: canvas.paperHeight)
            .background(JournalTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: canvas.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: canvas.cornerRadius)
                    .strokeBorder(JournalTheme.separator, lineWidth: canvas.cornerRadius > 0 ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { JournalBackdrop() }
            .onAppear {
                workspaceState.updateLayout(layout)
                sceneActions.updateLayout(layout)
                #if DEBUG
                interactionObserver?(JournalEditorInteraction(
                    sceneActions: sceneActions,
                    titleFocus: $titleFocused,
                    dismissKeyboard: dismissKeyboard,
                    focusBody: { perform(.focusBody) },
                    enterPreview: { perform(.selectMode(.preview)) },
                    returnToEdit: { perform(.selectMode(.edit)) }
                ))
                #endif
            }
            .onChange(of: layout) { updatedLayout in
                workspaceState.updateLayout(updatedLayout)
                sceneActions.updateLayout(updatedLayout)
            }
            .toolbar { editorToolbar(workspace: workspace) }
        }
        .focusedSceneObject(sceneActions)
        .navigationTitle(entry.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(JournalTheme.canvas)
        .onAppear {
            sceneActions.updateTarget(actionTarget(entry: currentEntry))
        }
        .onChange(of: entry.id) { entryID in
            guard currentEntry.wrappedValue.id == entryID else {
                sceneActions.clearTarget()
                assertionFailure("Editor commands rejected a stale journal binding")
                return
            }
            sceneActions.updateTarget(actionTarget(entry: currentEntry))
            #if DEBUG
            assert(sceneActions.targetEntryID == entryID, "Editor commands must target the current journal binding")
            #endif
            resetBodySelectionToEnd()
        }
        .onChange(of: titleFocused) { isFocused in
            if isFocused { workspaceState.editorFocused = false }
        }
        .onChange(of: workspaceState.editorFocused) { isFocused in
            if isFocused { titleFocused = false }
        }
        .onDisappear {
            sceneActions.clearTarget()
            dismissKeyboard()
        }
    }

    @ToolbarContentBuilder
    private func editorToolbar(workspace: EntryEditorWorkspaceState) -> some ToolbarContent {
        #if targetEnvironment(macCatalyst)
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                perform(.focusWriting)
            } label: {
                Label(EditorWritingCommand.focusWriting.title, systemImage: EditorWritingCommand.focusWriting.systemImage)
            }
            .help(EditorWritingCommand.focusWriting.helpText)

            Menu {
                Button { perform(.focusBody) } label: {
                    Label(EditorWritingCommand.focusBody.title, systemImage: EditorWritingCommand.focusBody.systemImage)
                }
                Button { applyIndentation(.indent) } label: {
                    Label(EditorWritingCommand.indentLines.title, systemImage: EditorWritingCommand.indentLines.systemImage)
                }
                Button { applyIndentation(.outdent) } label: {
                    Label(EditorWritingCommand.outdentLines.title, systemImage: EditorWritingCommand.outdentLines.systemImage)
                }
                Divider()
                ForEach(MarkdownSnippet.allCases) { snippet in
                    Button { insertSnippet(snippet) } label: {
                        Label(snippet.title, systemImage: snippet.systemImage)
                    }
                }
            } label: {
                Label("写作工具", systemImage: "textformat")
            }
            .help("Markdown、缩进与正文焦点")

            Button { perform(.togglePreview) } label: {
                Label(workspace.previewToggleTitle, systemImage: EditorWritingCommand.togglePreview.systemImage)
            }
            .help(EditorWritingCommand.togglePreview.helpText(title: workspace.previewToggleTitle))
        }
        #endif

        #if !targetEnvironment(macCatalyst)
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { perform(.focusWriting) } label: {
                    Label(EditorWritingCommand.focusWriting.title, systemImage: EditorWritingCommand.focusWriting.systemImage)
                }
                Button { perform(.togglePreview) } label: {
                    Label(workspace.previewToggleTitle, systemImage: EditorWritingCommand.togglePreview.systemImage)
                }
                Button { showsDetails.toggle() } label: {
                    Label(showsDetails ? "收起详情" : "日记详情", systemImage: "slider.horizontal.3")
                }
            } label: {
                Label("写作选项", systemImage: "ellipsis.circle")
            }
        }
        #endif

        ToolbarItem(placement: .primaryAction) {
            ShareLink(
                item: JournalMarkdownShareItem(entry: entry),
                subject: Text(entry.displayTitle), preview: SharePreview(entry.displayTitle)
            ) {
                Label("分享", systemImage: "square.and.arrow.up")
            }
        }

        ToolbarItemGroup(placement: .keyboard) {
            Button("完成", action: dismissKeyboard)
                .accessibilityIdentifier("journal.keyboard.done")
        }
    }

    private func header(
        layout: EntryEditorLayoutContract, bodyMetrics: JournalEntryBodyPresentation, compactHeight: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // The title stays at the same structural position when the keyboard changes height.
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                titleField(layout: layout, compact: compactHeight)
                if compactHeight { detailsButton }
            }

            if !compactHeight {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(entry.createdAt.journalTitleText, systemImage: "calendar")
                            .font(.caption)
                        if !showsDetails {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 12) {
                                    Label(entry.category.rawValue, systemImage: entry.category.systemImage)
                                    Label(entry.mood.rawValue, systemImage: entry.mood.systemImage)
                                }
                                Text("\(entry.category.rawValue) · \(entry.mood.rawValue)")
                            }
                            .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    detailsButton
                }
            }

            if showsDetails {
                Divider().padding(.vertical, 4)
                metadata(layout: layout)
                JournalSectionOverview(
                    sections: bodyMetrics.sections,
                    accent: JournalTheme.accent,
                    titleLineLimit: layout.sectionTitleLineLimit,
                    excerptLineLimit: layout.sectionExcerptLineLimit
                )
                Text("最近编辑：\(entry.updatedAt.journalRelativeUpdateText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, JournalTheme.pageInset)
        .padding(.vertical, compactHeight ? 0 : 12)
        .frame(maxWidth: JournalTheme.readableWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var detailsButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                showsDetails.toggle()
            }
        } label: {
            Label(showsDetails ? "收起详情" : "日记详情",
                  systemImage: showsDetails ? "chevron.up" : "slider.horizontal.3")
                .labelStyle(.iconOnly)
                .font(.subheadline)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(JournalTheme.accent)
        .accessibilityValue(showsDetails ? "已展开" : "已收起")
        .help(showsDetails ? "收起日期、分类、心情与小节目录" : "编辑日期、分类、心情与查看小节目录")
    }

    private func titleField(layout: EntryEditorLayoutContract, compact: Bool) -> some View {
        TextField("今天，想记下什么？", text: $entry.title, axis: .vertical)
            .font(compact ? .headline : .system(.title, design: .serif).weight(.medium))
            .textFieldStyle(.plain)
            .focused($titleFocused)
            .lineLimit(compact ? 1 : layout.titleLineLimit)
            .accessibilityLabel("日记标题")
    }

    private func writingStatus(_ metrics: JournalEntryBodyPresentation) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                Text("\(metrics.wordCount) 词 · \(metrics.sectionCount) 小节")
                Spacer(minLength: 12)
                Label("仅在本机", systemImage: "internaldrive")
            }
            Text("\(metrics.wordCount) 词 · \(metrics.sectionCount) 小节")
        }
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .padding(.horizontal, JournalTheme.pageInset)
        .padding(.vertical, 8)
        .frame(maxWidth: JournalTheme.readableWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Rectangle().fill(JournalTheme.separator).frame(height: 0.5)
        }
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
                .frame(minHeight: 44)
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
                .frame(minHeight: 44)
                .foregroundStyle(.secondary)
                .background(JournalTheme.inset, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func editor(
        layout: EntryEditorLayoutContract,
        bodyMetrics: JournalEntryBodyPresentation,
        limitsWritingWidth: Bool = false
    ) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            bodyEditorArea(bodyMetrics: bodyMetrics)
                .frame(maxWidth: limitsWritingWidth ? focusedWritingMaxWidth : .infinity)
            Spacer(minLength: 0)
        }
        .background(JournalTheme.paper)
    }

    private func bodyEditorArea(bodyMetrics: JournalEntryBodyPresentation) -> some View {
        ZStack(alignment: .topLeading) {
            if !bodyMetrics.hasVisibleContent {
                Text("用 ### 小节组织今天的记录。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, JournalTheme.pageInset)
                    .padding(.top, MarkdownBodyTextView.writingInsets.top)
                    .allowsHitTesting(false)
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
        bodyMetrics: JournalEntryBodyPresentation,
        inlineTools: Bool
    ) -> some View {
        let showsBoth = workspace.showsEditor && workspace.showsPreview
        let columnWidth: CGFloat? = showsBoth ? max(0, (width - 1) / 2) : nil

        return VStack(spacing: 0) {
            commandBand(
                layout: layout, workspace: workspace, columnWidth: columnWidth, inlineTools: inlineTools
            )
            Divider()

            // Keep the editor at one structural position across split and width changes.
            HStack(spacing: 0) {
                if workspace.showsEditor {
                    VStack(spacing: 0) {
                        editor(
                            layout: layout,
                            bodyMetrics: bodyMetrics,
                            limitsWritingWidth: !workspace.showsPreview
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
                        MarkdownPreviewView(
                            entryID: entry.id,
                            markdown: entry.body,
                            accent: JournalTheme.accent,
                            maxContentWidth: workspace.usesSplitPreview ? 560 : 720
                        )
                    }
                    .frame(width: columnWidth)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(JournalTheme.paper)
        }
    }

    private func commandBand(
        layout: EntryEditorLayoutContract,
        workspace: EntryEditorWorkspaceState,
        columnWidth: CGFloat?,
        inlineTools: Bool
    ) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                if workspace.usesSplitPreview {
                    Label("Markdown 原文", systemImage: "square.and.pencil")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Picker("写作模式", selection: compactModeSelection(layout: layout)) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                    .accessibilityValue(workspace.mode.rawValue)
                    .help("切换正文编辑与阅读预览")
                }
                Spacer(minLength: 0)
                MarkdownToolbar(showsCommonActions: !inlineTools && workspace.showsEditor) {
                    insertSnippet($0)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .frame(width: columnWidth)
            .frame(maxWidth: .infinity)

            if workspace.showsEditor && workspace.showsPreview {
                Divider().frame(width: 1)
                HStack {
                    Label("阅读预览", systemImage: "doc.richtext")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .frame(width: columnWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(JournalTheme.inset.opacity(0.35))
    }

    private func compactModeSelection(layout: EntryEditorLayoutContract) -> Binding<Mode> {
        Binding(
            get: { workspaceState.resolved(for: layout).mode },
            set: { perform(.selectMode($0)) }
        )
    }

    private func perform(_ action: EntryEditorWorkspaceState.Action) {
        sceneActions.perform(action)
    }

    private func actionTarget(entry: Binding<JournalEntry>) -> EntryEditorActionTarget {
        EntryEditorActionTarget(
            entry: entry, workspace: $workspaceState, titleFocus: $titleFocused,
            showsDetails: $showsDetails,
            layout: sceneActions.layout ?? EntryEditorLayoutContract(width: 0, dynamicTypeSize: dynamicTypeSize)
        )
    }

    private func dismissKeyboard() {
        titleFocused = false
        workspaceState.editorFocused = false
    }

    private func resetBodySelectionToEnd() {
        workspaceState.bodySelectedRange = NSRange(location: entry.body.utf16.count, length: 0)
    }

    private func applyIndentation(_ direction: MarkdownLineIndentation.Direction) {
        sceneActions.applyIndentation(direction)
    }

    private func insertSnippet(_ snippet: MarkdownSnippet) {
        sceneActions.insertMarkdownSnippet(snippet)
    }

}

private struct EditorHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct JournalSectionOverview: View {
    let sections: [JournalEntryBodyPresentation.Section]
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
                    .background(JournalTheme.inset, in: RoundedRectangle(cornerRadius: 8))
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
                            .background(JournalTheme.inset, in: RoundedRectangle(cornerRadius: 8))
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
