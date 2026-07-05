import SwiftUI

struct EntryListView: View {
    let entries: [JournalEntry]
    @Binding var selection: JournalEntry.ID?
    let onCreate: () -> Void
    let onDelete: (JournalEntry) -> Void
    let onShowStatistics: () -> Void

    @State private var searchText = ""
    @State private var selectedCategory: JournalEntry.Category?

    var body: some View {
        let overviewSnapshot = JournalListOverviewSnapshot(entries: entries)
        let listSnapshot = JournalEntryListSnapshot(
            entries: entries,
            searchText: searchText,
            selectedCategory: selectedCategory
        )

        List(selection: $selection) {
            Section {
                overviewCard(overviewSnapshot)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))

                categoryFilter(listSnapshot)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16))
            }

            Section {
                if listSnapshot.filteredEntries.isEmpty {
                    listEmptyState
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(listSnapshot.filteredEntries) { entry in
                        EntryRowView(entry: entry, isSelected: selection == entry.id)
                            .tag(entry.id)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDelete(entry)
                                } label: {
                                    Label("删除日记", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onDelete(entry)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                }
            } header: {
                Text(listSnapshot.sectionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(listBackground)
        .navigationTitle("日记")
        .searchable(text: $searchText, prompt: "搜索标题、正文、分类或心情")
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
        LinearGradient(
            colors: [
                Color.teal.opacity(0.12),
                Color(.systemGroupedBackground),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func overviewCard(_ overviewSnapshot: JournalListOverviewSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("记录册")
                        .font(.title3.weight(.bold))

                    Text(overviewSnapshot.insightText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Image(systemName: "text.book.closed")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.teal)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 10)], spacing: 10) {
                SummaryBadge(title: "日记", value: "\(overviewSnapshot.totalEntries)", systemImage: "doc.text")
                SummaryBadge(title: "连续", value: "\(overviewSnapshot.recentStreak) 天", systemImage: "flame")
                SummaryBadge(title: "词数", value: "\(overviewSnapshot.totalWords)", systemImage: "text.word.spacing")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }

    private func categoryFilter(_ listSnapshot: JournalEntryListSnapshot) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryFilterChip(
                    title: "全部",
                    count: listSnapshot.totalCount,
                    systemImage: "tray.full",
                    tint: .teal,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(JournalEntry.Category.allCases) { category in
                    CategoryFilterChip(
                        title: category.rawValue,
                        count: listSnapshot.count(for: category),
                        systemImage: category.systemImage,
                        tint: category.tint,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var listEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "book.closed" : "magnifyingglass")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.teal)

            Text(searchText.isEmpty ? "还没有日记" : "没有找到日记")
                .font(.headline)

            if searchText.isEmpty {
                Button(action: onCreate) {
                    Label("写一篇", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

}

private struct SummaryBadge: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CategoryFilterChip: View {
    let title: String
    let count: Int
    let systemImage: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text("\(title) \(count)")
                    .font(.footnote.weight(.semibold))
            } icon: {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? tint.opacity(0.18) : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? tint.opacity(0.55) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? tint : .secondary)
    }
}
