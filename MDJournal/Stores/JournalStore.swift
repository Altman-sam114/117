import Combine
import Foundation

@MainActor
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []
    @Published var errorMessage: String?

    private let storageURL: URL
    private let saveDebounceNanoseconds: UInt64
    private var pendingSaveTask: Task<Void, Never>?

    init(
        fileManager: FileManager = .default,
        storageURL: URL? = nil,
        saveDebounceNanoseconds: UInt64 = 450_000_000
    ) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.storageURL = documentsURL.appendingPathComponent("md-journal-entries.json")
        }

        self.saveDebounceNanoseconds = saveDebounceNanoseconds
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
        saveImmediately()
        return entry.id
    }

    func update(_ entry: JournalEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        let shouldSortEntries = entries[index].createdAt != entry.createdAt
        var updatedEntry = entry
        updatedEntry.updatedAt = Date()
        entries[index] = updatedEntry
        if shouldSortEntries {
            sortEntries()
        }
        scheduleSave()
    }

    func delete(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        saveImmediately()
    }

    func flushPendingSave() {
        guard pendingSaveTask != nil else { return }

        pendingSaveTask?.cancel()
        pendingSaveTask = nil
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

    private func scheduleSave() {
        pendingSaveTask?.cancel()

        let delay = Duration.nanoseconds(Int64(saveDebounceNanoseconds))
        pendingSaveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self?.saveScheduledChanges()
        }
    }

    private func saveScheduledChanges() {
        pendingSaveTask = nil
        save()
    }

    private func saveImmediately() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        save()
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

    deinit {
        pendingSaveTask?.cancel()
    }
}
