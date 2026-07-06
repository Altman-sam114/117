import SwiftUI

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

    var body: some View {
        GeometryReader { proxy in
            let isWideLayout = proxy.size.width >= 820
            let bodyMetrics = entry.bodyMetrics

            VStack(spacing: 0) {
                header(isWideLayout: isWideLayout, bodyMetrics: bodyMetrics)

                if isWideLayout {
                    wideEditor
                } else {
                    compactEditor
                }
            }
            .onAppear {
                isWideLayoutActive = isWideLayout
            }
            .onChange(of: isWideLayout) { isWideLayoutActive in
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
                .help(EditorWritingCommand.focusBody.title)

                Button(action: focusWriting) {
                    Label(
                        EditorWritingCommand.focusWriting.title,
                        systemImage: EditorWritingCommand.focusWriting.systemImage
                    )
                }
                .help(EditorWritingCommand.focusWriting.title)

                Button {
                    applyIndentation(.outdent)
                } label: {
                    Label(
                        EditorWritingCommand.outdentLines.title,
                        systemImage: EditorWritingCommand.outdentLines.systemImage
                    )
                }
                .help(EditorWritingCommand.outdentLines.title)

                Button {
                    applyIndentation(.indent)
                } label: {
                    Label(
                        EditorWritingCommand.indentLines.title,
                        systemImage: EditorWritingCommand.indentLines.systemImage
                    )
                }
                .help(EditorWritingCommand.indentLines.title)

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
                .help("插入 Markdown")

                Button(action: togglePreviewVisibility) {
                    Label(
                        previewToggleTitle,
                        systemImage: EditorWritingCommand.togglePreview.systemImage
                    )
                }
                .help(EditorWritingCommand.togglePreview.title)
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

    private func header(isWideLayout: Bool, bodyMetrics: JournalEntryBodyMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                categoryPicker
                moodPicker

                Spacer(minLength: 8)

                DatePicker("", selection: $entry.createdAt, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }

            TextField("今天的标题", text: $entry.title, axis: .vertical)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
                .lineLimit(2)

            if isWideLayout {
                HStack(alignment: .top, spacing: 12) {
                    statPills(bodyMetrics)
                        .frame(width: 270, alignment: .leading)

                    JournalSectionOverview(sections: bodyMetrics.sections, accent: entry.category.tint)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    statPills(bodyMetrics)
                    JournalSectionOverview(sections: bodyMetrics.sections, accent: entry.category.tint)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(headerBackground)
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

    private func statPills(_ bodyMetrics: JournalEntryBodyMetrics) -> some View {
        HStack(spacing: 8) {
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

    private var editor: some View {
        VStack(spacing: 0) {
            MarkdownToolbar(accent: entry.category.tint, onInsert: insertSnippet)
            Divider()

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
            .background(Color(.systemBackground))
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
                editor
            } else {
                MarkdownPreviewView(markdown: entry.body, accent: entry.category.tint)
            }
        }
    }

    private var wideEditor: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                WorkspacePaneHeader(title: "编辑", systemImage: "square.and.pencil", tint: entry.category.tint)
                editor
            }
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

    private var previewToggleTitle: String {
        if isWideLayoutActive {
            return isPreviewColumnVisible ? "隐藏预览" : "显示预览"
        }

        return mode == .preview ? "回到编辑" : "显示预览"
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
        body.contains { !$0.isWhitespace }
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
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct JournalSectionOverview: View {
    let sections: [JournalSection]
    let accent: Color

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
                                    .lineLimit(1)

                                Text(section.excerpt)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .frame(width: 132, alignment: .leading)
                            }
                            .padding(10)
                            .frame(width: 156, alignment: .leading)
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
