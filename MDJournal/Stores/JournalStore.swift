import Combine
import Foundation
#if os(iOS) && !targetEnvironment(macCatalyst)
import UIKit
#endif

enum JournalSaveState: Equatable {
    case saved
    case saving
    case failed
    case readProtected

    var title: String {
        switch self {
        case .saved: return "已存到本机"
        case .saving: return "正在保存"
        case .failed: return "保存失败"
        case .readProtected: return "原文件已保护"
        }
    }

    var systemImage: String {
        switch self {
        case .saved: return "checkmark.circle"
        case .saving: return "arrow.triangle.2.circlepath"
        case .failed: return "exclamationmark.arrow.triangle.2.circlepath"
        case .readProtected: return "lock.shield"
        }
    }
}

@MainActor
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var readFailureMessage: String?
    @Published private(set) var saveState: JournalSaveState = .saved
    private(set) var bodyPresentations: [JournalEntry.ID: JournalEntryBodyPresentation] = [:]

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
    private let backgroundTaskManager: any JournalBackgroundTaskManaging
    private let makeBodyPresentation: (JournalEntry) -> JournalEntryBodyPresentation
    private var pendingSave: PendingSave?
    private var backgroundFlushTask: Task<Void, Never>?
    private var errorSource: ErrorSource?

    private(set) var revision: UInt64 = 0
    private(set) var durableRevision: UInt64?

    var canMutate: Bool { readFailureMessage == nil }

    init(
        fileManager: FileManager = .default,
        storageURL: URL? = nil,
        saveDebounceNanoseconds: UInt64 = 450_000_000,
        persistenceWriter: (any JournalPersistenceWriting)? = nil,
        saveScheduler: any JournalSaveScheduling = TaskJournalSaveScheduler(),
        backgroundTaskManager: (any JournalBackgroundTaskManaging)? = nil,
        makeBodyPresentation: @escaping (JournalEntry) -> JournalEntryBodyPresentation = {
            JournalEntryBodyPresentation(body: $0.body)
        }
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
        self.backgroundTaskManager = backgroundTaskManager ?? SystemJournalBackgroundTaskManager()
        self.makeBodyPresentation = makeBodyPresentation
        load()
    }

    func entry(with id: JournalEntry.ID) -> JournalEntry? {
        entries.first { $0.id == id }
    }

    @discardableResult
    func createEntry() -> JournalEntry.ID? {
        guard allowMutation() else { return nil }
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

        bodyPresentations[entry.id] = makeBodyPresentation(entry)
        entries.insert(entry, at: 0)
        recordMutation()
        submitImmediately(currentSnapshot())
        return entry.id
    }

    func update(_ entry: JournalEntry) {
        guard allowMutation() else { return }
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        let original = entries[index]
        let bodyChanged = original.body != entry.body
        guard bodyChanged || original.title != entry.title || original.createdAt != entry.createdAt
                || original.category != entry.category || original.mood != entry.mood else { return }

        cancelPendingSave()
        let shouldSortEntries = original.createdAt != entry.createdAt
        if bodyChanged {
            bodyPresentations[entry.id] = makeBodyPresentation(entry)
        }
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
        guard allowMutation() else { return }
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        cancelPendingSave()
        bodyPresentations.removeValue(forKey: entry.id)
        entries.remove(at: index)
        recordMutation()
        submitImmediately(currentSnapshot())
    }

    @discardableResult
    func flushPendingSave() async -> JournalPersistenceResult? {
        cancelPendingSave()
        guard canMutate else { return nil }
        guard revision > 0 else { return nil }
        if durableRevision != revision && saveState != .saving { saveState = .saving }

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

    @discardableResult
    func flushForBackground() -> Task<Void, Never> {
        if let backgroundFlushTask { return backgroundFlushTask }
        let lease = JournalBackgroundSaveLease(manager: backgroundTaskManager)
        // Request finite execution time before yielding to the asynchronous writer.
        lease.begin()
        let task = Task { [weak self, lease] in
            defer {
                lease.finish()
                self?.backgroundFlushTask = nil
            }
            _ = await self?.flushPendingSave()
        }
        backgroundFlushTask = task
        return task
    }

    func dismissError() {
        errorMessage = nil
        errorSource = nil
    }

    @discardableResult
    func retryReadingProtectedFile() -> Bool {
        guard !canMutate else { return true }
        load(createsStarterIfMissing: false)
        return canMutate
    }

    func exportBackupData() async throws -> Data {
        guard canMutate else { throw JournalBackupError.readProtected }
        let snapshot = entries
        return try await Task.detached(priority: .userInitiated) {
            try JournalBackupCodec.encode(snapshot)
        }.value
    }

    func exportOriginalDataForRecovery() async throws -> Data {
        let url = storageURL
        return try await Task.detached(priority: .userInitiated) {
            // Import limits must never prevent preserving a larger original file.
            try Data(contentsOf: url, options: .mappedIfSafe)
        }.value
    }

    func prepareImport(_ incoming: [JournalEntry]) throws -> JournalBackupImportPreview {
        guard canMutate else { throw JournalBackupError.readProtected }
        guard incoming.count <= JournalBackupCodec.maximumEntries else { throw JournalBackupError.tooManyEntries }
        try JournalBackupCodec.validateIdentifiers(incoming)
        let existingIDs = Set(entries.map(\.id))
        let existingCount = incoming.reduce(0) { $0 + (existingIDs.contains($1.id) ? 1 : 0) }
        return JournalBackupImportPreview(
            entries: incoming, newEntryCount: incoming.count - existingCount,
            existingEntryCount: existingCount, basedOnRevision: revision
        )
    }

    @discardableResult
    func confirmImport(_ preview: JournalBackupImportPreview) throws -> Int {
        guard allowMutation() else { throw JournalBackupError.readProtected }
        guard preview.basedOnRevision == revision else { throw JournalBackupError.stalePreview }
        try JournalBackupCodec.validateIdentifiers(preview.entries)
        let existingIDs = Set(entries.map(\.id))
        let additions = preview.entries.filter { !existingIDs.contains($0.id) }
        guard !additions.isEmpty else { return 0 }
        cancelPendingSave()
        for entry in additions {
            bodyPresentations[entry.id] = makeBodyPresentation(entry)
        }
        entries = (entries + additions).sorted { $0.createdAt > $1.createdAt }
        recordMutation()
        submitImmediately(currentSnapshot())
        return additions.count
    }

    private func allowMutation() -> Bool {
        guard let readFailureMessage else { return true }
        publishError(readFailureMessage, source: .read)
        return false
    }

    private func load(createsStarterIfMissing: Bool = true) {
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedEntries = try decoder.decode([JournalEntry].self, from: data)
            try JournalBackupCodec.validateIdentifiers(loadedEntries)
            bodyPresentations.removeAll(keepingCapacity: true)
            for entry in loadedEntries {
                bodyPresentations[entry.id] = makeBodyPresentation(entry)
            }
            entries = loadedEntries
            sortEntries()
            readFailureMessage = nil
            saveState = .saved
            if case .read = errorSource {
                errorMessage = nil
                errorSource = nil
            }
        } catch {
            let readError = error as NSError
            if createsStarterIfMissing,
               readError.domain == NSCocoaErrorDomain,
               readError.code == NSFileReadNoSuchFileError {
                let starter = JournalEntry.starterEntry()
                bodyPresentations[starter.id] = makeBodyPresentation(starter)
                entries = [starter]
                recordMutation()
                submitImmediately(currentSnapshot())
                return
            }
            let message = "读取本地日记失败：\(error.localizedDescription)"
            readFailureMessage = message
            saveState = .readProtected
            publishError(message, source: .read)
            bodyPresentations.removeAll()
            entries = []
        }
    }

    private func recordMutation() {
        revision += 1
        if saveState != .saving { saveState = .saving }
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
            if saveState != .saved { saveState = .saved }
            clearWriteError(through: resultRevision)
        case let .failed(resultRevision, message):
            guard durableRevision.map({ resultRevision > $0 }) ?? true else { return }
            saveState = .failed
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

@MainActor
protocol JournalBackgroundTaskManaging {
    func begin(expirationHandler: @escaping @MainActor @Sendable () -> Void) -> Int?
    func end(_ identifier: Int)
}

@MainActor
private struct SystemJournalBackgroundTaskManager: JournalBackgroundTaskManaging {
    func begin(expirationHandler: @escaping @MainActor @Sendable () -> Void) -> Int? {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let identifier = UIApplication.shared.beginBackgroundTask(withName: "JournalSave") {
            Task { @MainActor in expirationHandler() }
        }
        return identifier == .invalid ? nil : identifier.rawValue
        #else
        return nil
        #endif
    }

    func end(_ identifier: Int) {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: identifier))
        #endif
    }
}

@MainActor
private final class JournalBackgroundSaveLease {
    private let manager: any JournalBackgroundTaskManaging
    private var identifier: Int?
    private var isFinished = false

    init(manager: any JournalBackgroundTaskManaging) {
        self.manager = manager
    }

    func begin() {
        let identifier = manager.begin { [weak self] in self?.finish() }
        if isFinished {
            // An expiry delivered during begin still owns the returned identifier.
            if let identifier { manager.end(identifier) }
        } else {
            self.identifier = identifier
        }
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        if let identifier {
            self.identifier = nil
            manager.end(identifier)
        }
    }
}
