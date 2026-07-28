import Combine
import Foundation

@MainActor
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []
    @Published private(set) var errorMessage: String?

    private enum ErrorSource: Equatable {
        case read
        case write(revision: UInt64)
    }

    private struct PendingSave {
        let id: UUID
        let scheduledSave: JournalScheduledSave
    }

    private let storageURL: URL
    private let saveDebounceDelay: Duration
    private let persistenceWriter: any JournalPersistenceWriting
    private let saveScheduler: any JournalSaveScheduling
    private var pendingSave: PendingSave?
    private var errorSource: ErrorSource?

    private(set) var revision: UInt64 = 0
    private(set) var durableRevision: UInt64?

    init(
        fileManager: FileManager = .default,
        storageURL: URL? = nil,
        saveDebounceNanoseconds: UInt64 = 450_000_000,
        persistenceWriter: (any JournalPersistenceWriting)? = nil,
        saveScheduler: any JournalSaveScheduling = TaskJournalSaveScheduler()
    ) {
        let resolvedStorageURL: URL
        if let storageURL {
            resolvedStorageURL = storageURL
        } else {
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            resolvedStorageURL = documentsURL.appendingPathComponent("md-journal-entries.json")
        }

        let boundedNanoseconds = min(saveDebounceNanoseconds, UInt64(Int64.max))
        self.storageURL = resolvedStorageURL
        saveDebounceDelay = .nanoseconds(Int64(boundedNanoseconds))
        self.persistenceWriter = persistenceWriter
            ?? JSONJournalPersistenceWriter(storageURL: resolvedStorageURL)
        self.saveScheduler = saveScheduler
        load()
    }

    func entry(with id: JournalEntry.ID) -> JournalEntry? {
        entries.first { $0.id == id }
    }

    @discardableResult
    func createEntry() -> JournalEntry.ID {
        cancelPendingSave()
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
        recordMutation()
        submitImmediately(currentSnapshot())
        return entry.id
    }

    func update(_ entry: JournalEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        cancelPendingSave()
        let shouldSortEntries = entries[index].createdAt != entry.createdAt
        var updatedEntry = entry
        updatedEntry.updatedAt = Date()
        entries[index] = updatedEntry
        if shouldSortEntries {
            sortEntries()
        }
        recordMutation()
        scheduleSave()
    }

    func delete(_ entry: JournalEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        cancelPendingSave()
        entries.remove(at: index)
        recordMutation()
        submitImmediately(currentSnapshot())
    }

    @discardableResult
    func flushPendingSave() async -> JournalPersistenceResult? {
        cancelPendingSave()
        guard revision > 0 else { return nil }

        while true {
            let snapshot = currentSnapshot()
            let result = await persistenceWriter.persist(snapshot)
            receivePersistenceResult(result)

            guard revision != snapshot.revision else {
                return result
            }

            cancelPendingSave()
        }
    }

    func dismissError() {
        errorMessage = nil
        errorSource = nil
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            entries = [JournalEntry.starterEntry()]
            recordMutation()
            submitImmediately(currentSnapshot())
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([JournalEntry].self, from: data)
            sortEntries()
        } catch {
            publishError("读取本地日记失败：\(error.localizedDescription)", source: .read)
            entries = []
        }
    }

    private func recordMutation() {
        revision += 1
        clearSupersededWriteError()
    }

    private func currentSnapshot() -> JournalPersistenceSnapshot {
        JournalPersistenceSnapshot(revision: revision, entries: entries)
    }

    private func scheduleSave() {
        cancelPendingSave()

        let pendingID = UUID()
        let scheduledSave = saveScheduler.schedule(after: saveDebounceDelay) { [weak self, persistenceWriter] in
            guard let snapshot = self?.scheduledSaveSnapshot(id: pendingID) else { return }
            let result = await persistenceWriter.persist(snapshot)
            self?.receivePersistenceResult(result)
        }
        pendingSave = PendingSave(id: pendingID, scheduledSave: scheduledSave)
    }

    private func scheduledSaveSnapshot(id: UUID) -> JournalPersistenceSnapshot? {
        guard pendingSave?.id == id else { return nil }
        pendingSave = nil
        return currentSnapshot()
    }

    private func submitImmediately(_ snapshot: JournalPersistenceSnapshot) {
        cancelPendingSave()

        Task { [weak self, persistenceWriter] in
            let result = await persistenceWriter.persist(snapshot)
            self?.receivePersistenceResult(result)
        }
    }

    private func cancelPendingSave() {
        pendingSave?.scheduledSave.cancel()
        pendingSave = nil
    }

    private func receivePersistenceResult(_ result: JournalPersistenceResult) {
        guard result.revision == revision else { return }

        switch result {
        case let .written(resultRevision), let .alreadyDurable(resultRevision):
            durableRevision = max(durableRevision ?? resultRevision, resultRevision)
            clearWriteError(through: resultRevision)
        case let .failed(resultRevision, message):
            guard durableRevision.map({ resultRevision > $0 }) ?? true else { return }
            publishError("写入本地日记失败：\(message)", source: .write(revision: resultRevision))
        case .rejectedStale:
            break
        }
    }

    private func clearSupersededWriteError() {
        guard case .write = errorSource else { return }
        errorMessage = nil
        errorSource = nil
    }

    private func clearWriteError(through revision: UInt64) {
        guard case let .write(errorRevision) = errorSource, errorRevision <= revision else { return }
        errorMessage = nil
        errorSource = nil
    }

    private func publishError(_ message: String, source: ErrorSource) {
        errorMessage = message
        errorSource = source
    }

    private func sortEntries() {
        entries.sort { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
    }

}
