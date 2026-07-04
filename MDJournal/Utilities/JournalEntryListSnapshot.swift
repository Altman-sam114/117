import Foundation

struct JournalEntryListSnapshot: Equatable {
    let filteredEntries: [JournalEntry]
    let totalCount: Int
    let categoryCounts: [JournalEntry.Category: Int]
    let searchQuery: String
    let selectedCategory: JournalEntry.Category?

    init(
        entries: [JournalEntry],
        searchText: String,
        selectedCategory: JournalEntry.Category?
    ) {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var counts = Dictionary(uniqueKeysWithValues: JournalEntry.Category.allCases.map { ($0, 0) })
        var filtered: [JournalEntry] = []
        filtered.reserveCapacity(entries.count)

        for entry in entries {
            counts[entry.category, default: 0] += 1

            guard selectedCategory == nil || entry.category == selectedCategory else {
                continue
            }

            guard trimmedSearch.isEmpty || entry.matchesListSearch(trimmedSearch) else {
                continue
            }

            filtered.append(entry)
        }

        self.filteredEntries = filtered
        self.totalCount = entries.count
        self.categoryCounts = counts
        self.searchQuery = trimmedSearch
        self.selectedCategory = selectedCategory
    }

    var sectionTitle: String {
        if let selectedCategory {
            return "\(selectedCategory.rawValue) · \(filteredEntries.count) 篇"
        }

        return "最近记录 · \(filteredEntries.count) 篇"
    }

    func count(for category: JournalEntry.Category) -> Int {
        categoryCounts[category, default: 0]
    }
}

private extension JournalEntry {
    func matchesListSearch(_ searchQuery: String) -> Bool {
        displayTitle.localizedCaseInsensitiveContains(searchQuery)
            || body.localizedCaseInsensitiveContains(searchQuery)
            || category.rawValue.localizedCaseInsensitiveContains(searchQuery)
            || mood.rawValue.localizedCaseInsensitiveContains(searchQuery)
    }
}
