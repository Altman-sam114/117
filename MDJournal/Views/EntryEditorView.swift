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
    static let regularWideStatisticsWidth: CGFloat = 270
    static let sectionCardBaseWidth: CGFloat = 156

    let isWideEditorLayout: Bool
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

struct EntryEditorView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case edit = "编辑"
        case preview = "预览"

        var id: String { rawValue }
    }

    @Binding var entry: JournalEntry
    @State private var mode: Mode = .edit
    @State private var isPreviewColumnVisible = true
    @State private var isWideLayoutActive = false
    @State private var editorFocused = false
    @State private var bodySelectedRange = NSRange(location: NSNotFound, length: 0)
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let focusedWritingMaxWidth: CGFloat = 920

    var body: some View {
        GeometryReader { proxy in
            let layout = EntryEditorLayoutContract(
                width: proxy.size.width,
                dynamicTypeSize: dynamicTypeSize
            )
            let bodyMetrics = entry.bodyMetrics

            VStack(spacing: 0) {
                header(layout: layout, bodyMetrics: bodyMetrics)

                if layout.isWideEditorLayout {
                    wideEditor
                } else {
                    compactEditor
                }
            }
            .onAppear {
                isWideLayoutActive = layout.isWideEditorLayout
            }
            .onChange(of: layout.isWideEditorLayout) { isWideLayoutActive in
                self.isWideLayoutActive = isWideLayoutActive
            }
        }
        .navigationTitle(entry.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            #if targetEnvironment(macCatalyst)
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: focusBody) {
                    Label(EditorWritingCommand.focusBody.title, systemImage: EditorWritingCommand.focusBody.systemImage)
                }
                .help(EditorWritingCommand.focusBody.helpText)
                .accessibilityLabel(EditorWritingCommand.focusBody.title)

                Button(action: focusWriting) {
                    Label(
                        EditorWritingCommand.focusWriting.title,
                        systemImage: EditorWritingCommand.focusWriting.systemImage
                    )
                }
                .help(EditorWritingCommand.focusWriting.helpText)
                .accessibilityLabel(EditorWritingCommand.focusWriting.title)

                Button {
                    applyIndentation(.outdent)
                } label: {
                    Label(
                        EditorWritingCommand.outdentLines.title,
                        systemImage: EditorWritingCommand.outdentLines.systemImage
                    )
                }
                .help(EditorWritingCommand.outdentLines.helpText)
                .accessibilityLabel(EditorWritingCommand.outdentLines.title)

                Button {
                    applyIndentation(.indent)
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
                            insertSnippet(snippet)
                        } label: {
                            Label(snippet.title, systemImage: snippet.systemImage)
                        }
                    }
                } label: {
                    Label("插入", systemImage: "plus.rectangle.on.rectangle")
                }
                .help(EditorWritingCommand.insertMarkdownAccessibilityLabel)
                .accessibilityLabel(EditorWritingCommand.insertMarkdownAccessibilityLabel)

                Button(action: togglePreviewVisibility) {
                    Label(
                        previewToggleTitle,
                        systemImage: EditorWritingCommand.togglePreview.systemImage
                    )
                }
                .help(EditorWritingCommand.togglePreview.helpText(title: previewToggleTitle))
                .accessibilityLabel(previewToggleTitle)
            }
            #endif

            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: entry.markdownDocument, subject: Text(entry.displayTitle)) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Button("完成") {
                    editorFocused = false
                }
            }
        }
        .background(Color(.systemBackground))
        .focusedSceneValue(\.insertMarkdownSnippetAction, insertSnippet)
        .focusedSceneValue(\.focusEditorBodyAction, focusBody)
        .focusedSceneValue(\.focusEditorWritingAction, focusWriting)
        .focusedSceneValue(\.toggleEditorPreviewAction, togglePreviewVisibility)
        .focusedSceneValue(\.applyEditorIndentationAction, applyIndentation)
        .onChange(of: entry.id) { _ in
            resetBodySelectionToEnd()
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

    private func editor(limitsWritingWidth: Bool = false) -> some View {
        VStack(spacing: 0) {
            MarkdownToolbar(accent: entry.category.tint, onInsert: insertSnippet)
            Divider()

            Group {
                if limitsWritingWidth {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        bodyEditorArea
                            .frame(maxWidth: focusedWritingMaxWidth)
                        Spacer(minLength: 0)
                    }
                } else {
                    bodyEditorArea
                        .frame(maxWidth: .infinity)
                }
            }
            .background(Color(.systemBackground))
        }
    }

    private var bodyEditorArea: some View {
        ZStack(alignment: .topLeading) {
            if !bodyContainsVisibleContent {
                Text("用 ### 小节组织今天的记录。")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
            }

            MarkdownBodyTextView(
                text: $entry.body,
                selectedRange: $bodySelectedRange,
                isFocused: $editorFocused
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var compactEditor: some View {
        VStack(spacing: 0) {
            Picker("模式", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if mode == .edit {
                editor()
            } else {
                MarkdownPreviewView(markdown: entry.body, accent: entry.category.tint)
            }
        }
    }

    private var wideEditor: some View {
        HStack(spacing: 0) {
            editorColumn(limitsWritingWidth: !isPreviewColumnVisible)
                .frame(maxWidth: .infinity)

            if isPreviewColumnVisible {
                Divider()

                VStack(spacing: 0) {
                    WorkspacePaneHeader(title: "预览", systemImage: "doc.richtext", tint: entry.category.tint)
                    MarkdownPreviewView(markdown: entry.body, accent: entry.category.tint, maxContentWidth: 560)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func editorColumn(limitsWritingWidth: Bool) -> some View {
        VStack(spacing: 0) {
            WorkspacePaneHeader(title: "编辑", systemImage: "square.and.pencil", tint: entry.category.tint)
            editor(limitsWritingWidth: limitsWritingWidth)
        }
    }

    private var previewToggleTitle: String {
        EditorWritingCommand.previewToggleTitle(
            isWideLayoutActive: isWideLayoutActive,
            isPreviewColumnVisible: isPreviewColumnVisible,
            isPreviewModeActive: mode == .preview
        )
    }

    private func focusBody() {
        mode = .edit
        editorFocused = true
    }

    private func focusWriting() {
        mode = .edit

        if isWideLayoutActive {
            isPreviewColumnVisible = false
        }

        editorFocused = true
    }

    private func resetBodySelectionToEnd() {
        bodySelectedRange = NSRange(location: entry.body.utf16.count, length: 0)
    }

    private func togglePreviewVisibility() {
        if isWideLayoutActive {
            isPreviewColumnVisible.toggle()
        } else {
            mode = mode == .preview ? .edit : .preview
        }
    }

    private func applyIndentation(_ direction: MarkdownLineIndentation.Direction) {
        focusBody()

        guard let result = MarkdownLineIndentation.apply(
            to: entry.body,
            selectedRange: bodySelectedRange,
            direction: direction
        ) else {
            return
        }

        entry.body = result.body
        bodySelectedRange = result.selectedRange
    }

    private func insertSnippet(_ snippet: MarkdownSnippet) {
        focusBody()
        let result = MarkdownSnippetInsertion.apply(
            snippet: snippet,
            to: entry.body,
            selectedRange: bodySelectedRange
        )

        entry.body = result.body
        bodySelectedRange = result.selectedRange
    }

    private var bodyContainsVisibleContent: Bool {
        entry.body.contains { !$0.isWhitespace }
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
