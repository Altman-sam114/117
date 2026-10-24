import SwiftUI

struct JournalDeletionConfirmationState {
    private(set) var target: JournalEntry?

    var isPresented: Bool {
        target != nil
    }

    mutating func request(_ entry: JournalEntry) {
        target = entry
    }

    mutating func dismiss() {
        target = nil
    }

    mutating func consumeConfirmedTarget() -> JournalEntry? {
        defer { target = nil }
        return target
    }

    static func dialogTitle(for entry: JournalEntry) -> String {
        "删除“\(entry.displayTitle)”？"
    }
}

struct EntryListView: View {
    let overviewSnapshot: JournalListOverviewSnapshot
    let snapshot: JournalEntryListSnapshot
    let bodyPresentations: [JournalEntry.ID: JournalEntryBodyPresentation]
    @Binding var selection: JournalEntry.ID?
    @Binding var searchText: String
    @Binding var selectedCategory: JournalEntry.Category?
    let onCreate: () -> Void
    let onDelete: (JournalEntry) -> Void
    let onShowStatistics: () -> Void
    var onShowSettings: () -> Void = {}
    var canCreate = true
    var readFailureMessage: String? = nil
    var usesNativeSelection = true

    @State private var deletionConfirmation = JournalDeletionConfirmationState()
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let timeline = JournalEntryTimelineSnapshot(
            entries: snapshot.filteredEntries, calendar: calendar, locale: locale
        )

        // Compact stacks own navigation through their path, without a second list selection driver.
        List(selection: usesNativeSelection ? $selection : nil) {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    overviewCard(overviewSnapshot)
                    if let readFailureMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("原始日记文件已保护", systemImage: "lock.shield")
                                .font(.subheadline.weight(.medium))
                            Text(readFailureMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("打开设置恢复", action: onShowSettings)
                                .frame(minHeight: 44)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(JournalTheme.inset, in: RoundedRectangle(cornerRadius: 10))
                    }
                    createButton
                    categoryFilter(snapshot)
                }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if snapshot.filteredEntries.isEmpty {
                Section {
                    listEmptyState(snapshot)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(timeline.months) { month in
                    Section {
                        ForEach(month.entries) { entry in
                            NavigationLink(value: entry.id) {
                                EntryRowView(
                                    entry: entry, bodyPresentation: presentation(for: entry.id),
                                    isSelected: selection == entry.id
                                )
                                .equatable()
                            }
                                .buttonStyle(.plain)
                                .tag(entry.id)
                                .accessibilityIdentifier("journal.entry.\(entry.id.uuidString)")
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 1, leading: 12, bottom: 1, trailing: 12))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        requestDeletion(of: entry)
                                    } label: {
                                        Label("删除日记", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        requestDeletion(of: entry)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Text(month.title)
                            Spacer(minLength: 4)
                            Text("\(month.entries.count) 篇").monospacedDigit()
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(listBackground)
        .navigationTitle("日记")
        .searchable(text: $searchText, prompt: "搜索标题、正文、分类或心情")
        .confirmationDialog(
            deletionDialogTitle,
            isPresented: deletionConfirmationPresentation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive, action: confirmDeletion)
            Button("取消", role: .cancel) {
                deletionConfirmation.dismiss()
            }
        } message: {
            Text("此操作无法撤销。")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onShowSettings) {
                    Label("设置", systemImage: "gearshape")
                }
                .accessibilityIdentifier("journal.settings")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onShowStatistics) {
                    Label("统计", systemImage: "chart.bar.xaxis")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: onCreate) {
                    Label("新建", systemImage: "square.and.pencil")
                }
                .accessibilityIdentifier("journal.create.toolbar")
                .disabled(!canCreate)
            }
        }
    }

    private var listBackground: some View {
        JournalBackdrop().ignoresSafeArea()
    }

    private func overviewCard(_ overview: JournalListOverviewSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("我的资料库", systemImage: "book.closed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(JournalTheme.accent)
                Spacer(minLength: 4)
            }
            Text("日常，值得记下。")
                .font(.system(.title2, design: .serif).weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            let metricsLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(spacing: 10))
            metricsLayout {
                Text("\(overview.totalEntries) 篇 · \(overview.totalWords) 词")
                    .foregroundStyle(.secondary)
                if overview.recentStreak > 0 {
                    Label("连续 \(overview.recentStreak) 天", systemImage: "leaf")
                        .foregroundStyle(JournalTheme.accent)
                }
            }
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var createButton: some View {
        Button(action: onCreate) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .accessibilityHidden(true)
                Text("写一篇日记")
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                #if targetEnvironment(macCatalyst)
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("⌘N").font(.caption).accessibilityHidden(true)
                }
                #endif
            }
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.leading)
            .foregroundStyle(JournalTheme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .tint(JournalTheme.accent)
        .accessibilityIdentifier("journal.create")
        .disabled(!canCreate)
        .help("新建日记（⌘N）")
    }

    private func categoryFilter(_ listSnapshot: JournalEntryListSnapshot) -> some View {
        Menu {
            Picker("分类", selection: $selectedCategory) {
                Label("全部 · \(listSnapshot.totalCount)", systemImage: "tray.full")
                    .tag(nil as JournalEntry.Category?)
                ForEach(JournalEntry.Category.allCases) { category in
                    Label("\(category.rawValue) · \(listSnapshot.count(for: category))", systemImage: category.systemImage)
                        .tag(Optional(category))
                }
            }
        } label: {
            let menuLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            menuLayout {
                Label(selectedCategory?.rawValue ?? "全部日记", systemImage: selectedCategory?.systemImage ?? "tray.full")
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
                HStack(spacing: 8) {
                    Text("\(listSnapshot.filteredEntries.count)").monospacedDigit()
                    if dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .frame(minHeight: CategoryFilterChipContract.minimumInteractiveHeight)
            .background(JournalTheme.inset, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .foregroundStyle(JournalTheme.accent)
        .accessibilityLabel("筛选分类")
        .accessibilityValue(CategoryFilterChipContract.accessibilityLabel(
            title: selectedCategory?.rawValue ?? "全部", count: listSnapshot.filteredEntries.count
        ))
        .help("按分类浏览日记")
    }

    private func listEmptyState(_ listSnapshot: JournalEntryListSnapshot) -> some View {
        VStack(spacing: 12) {
            Image(systemName: listSnapshot.isCollectionEmpty ? "book.closed" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(JournalTheme.accent)

            Text(listSnapshot.isCollectionEmpty ? "还没有日记" : "没有符合条件的日记")
                .font(.headline)
                .accessibilityIdentifier(
                    listSnapshot.isCollectionEmpty ? "journal.library.empty" : "journal.library.filtered-empty"
                )

            if listSnapshot.isCollectionEmpty {
                Button(action: onCreate) {
                    Label("写一篇", systemImage: "square.and.pencil")
                        .foregroundStyle(JournalTheme.onAccent)
                }
                .buttonStyle(.borderedProminent)
                .tint(JournalTheme.accent)
                .disabled(!canCreate)
            } else {
                Button(action: clearFilters) {
                    Label("清除筛选", systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(28)
        .journalSurface()
    }

    private func clearFilters() {
        searchText = ""
        selectedCategory = nil
    }

    private func presentation(for id: JournalEntry.ID) -> JournalEntryBodyPresentation {
        guard let presentation = bodyPresentations[id] else {
            preconditionFailure("Missing body presentation for visible entry")
        }
        return presentation
    }

    private var deletionDialogTitle: String {
        guard let target = deletionConfirmation.target else {
            return "删除日记？"
        }

        return JournalDeletionConfirmationState.dialogTitle(for: target)
    }

    private var deletionConfirmationPresentation: Binding<Bool> {
        Binding(
            get: { deletionConfirmation.isPresented },
            set: { isPresented in
                if !isPresented {
                    deletionConfirmation.dismiss()
                }
            }
        )
    }

    private func requestDeletion(of entry: JournalEntry) {
        deletionConfirmation.request(entry)
    }

    private func confirmDeletion() {
        guard let target = deletionConfirmation.consumeConfirmedTarget() else {
            return
        }

        onDelete(target)
    }
}

enum CategoryFilterChipContract {
    static let minimumInteractiveHeight: CGFloat = 44

    static func accessibilityLabel(title: String, count: Int) -> String {
        "\(title)，\(count) 篇"
    }
}
