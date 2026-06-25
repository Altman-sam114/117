import Combine
import Foundation

@MainActor
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []
    @Published var errorMessage: String?

    private let storageURL: URL

    init(fileManager: FileManager = .default) {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        storageURL = documentsURL.appendingPathComponent("md-journal-entries.json")
        load()
    }

    func entry(with id: JournalEntry.ID) -> JournalEntry? {
        entries.first { $0.id == id }
    }

    @discardableResult
    func createEntry() -> JournalEntry.ID {
        let entry = JournalEntry(
            title: Date().journalTitleText,
            body: """
            ### 今天发生了什么


            ### 我的感受


            ### 明天可以做的小事

            """,
            category: .daily,
            mood: .calm
        )

        entries.insert(entry, at: 0)
        save()
        return entry.id
    }

    func update(_ entry: JournalEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        var updatedEntry = entry
        updatedEntry.updatedAt = Date()
        entries[index] = updatedEntry
        sortEntries()
        save()
    }

    func delete(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            entries = [JournalEntry.starterEntry()]
            save()
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([JournalEntry].self, from: data)
            sortEntries()
        } catch {
            errorMessage = "读取本地日记失败：\(error.localizedDescription)"
            entries = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(entries)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            errorMessage = "写入本地日记失败：\(error.localizedDescription)"
        }
    }

    private func sortEntries() {
        entries.sort { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
    }
}
