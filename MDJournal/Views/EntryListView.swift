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
    @Binding var selection: JournalEntry.ID?
    @Binding var searchText: String
    @Binding var selectedCategory: JournalEntry.Category?
    let onCreate: () -> Void
    let onDelete: (JournalEntry) -> Void
    let onShowStatistics: () -> Void

    @State private var deletionConfirmation = JournalDeletionConfirmationState()

    var body: some View {
        List(selection: $selection) {
            Section {
                overviewCard(overviewSnapshot)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))

                categoryFilter(snapshot)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16))
            }

            Section {
                if snapshot.filteredEntries.isEmpty {
                    listEmptyState(snapshot)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(snapshot.filteredEntries) { entry in
                        EntryRowView(entry: entry, isSelected: selection == entry.id)
                            .tag(entry.id)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
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
                }
            } header: {
                Text(snapshot.sectionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
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
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onShowStatistics) {
                    Label("统计", systemImage: "chart.bar.xaxis")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: onCreate) {
                    Label("新建", systemImage: "square.and.pencil")
                }
            }
        }
    }

    private var listBackground: some View {
        JournalTheme.canvas.ignoresSafeArea()
    }

    private func overviewCard(_ overview: JournalListOverviewSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("MD JOURNAL", systemImage: "book.closed")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(JournalTheme.accent)

            Text("留住每一天。")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            Text("\(overview.totalEntries) 篇记录 · \(overview.totalWords) 词")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if overview.recentStreak > 0 {
                Label("最近连续记录 \(overview.recentStreak) 天", systemImage: "leaf")
                    .font(.footnote)
                    .foregroundStyle(JournalTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
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
            HStack(spacing: 8) {
                Label(selectedCategory?.rawValue ?? "全部日记", systemImage: selectedCategory?.systemImage ?? "tray.full")
                Spacer(minLength: 4)
                Text("\(listSnapshot.filteredEntries.count)").monospacedDigit()
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
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

            if listSnapshot.isCollectionEmpty {
                Button(action: onCreate) {
                    Label("写一篇", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
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
