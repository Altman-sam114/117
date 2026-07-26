import XCTest
@testable import MDJournal

@MainActor
final class JournalStoreTests: XCTestCase {
    func testProductionWriterPreservesJSONByteStrategy() async throws {
        let fixture = try makeDirectoryFixture()
        defer { fixture.cleanup() }
        let storageURL = fixture.directoryURL.appendingPathComponent("entries.json")
        let entries = [makeEntry(title: "固定日记", createdAt: Date(timeIntervalSince1970: 123))]
        let writer = JSONJournalPersistenceWriter(storageURL: storageURL)

        let result = await writer.persist(.init(revision: 1, entries: entries))

        XCTAssertEqual(result, .written(revision: 1))
        XCTAssertEqual(try Data(contentsOf: storageURL), try referenceJSONData(for: entries))
        XCTAssertEqual(try decodeEntries(from: storageURL), entries)
    }

    func testProductionWriterRejectsOlderRevisionAfterNewerRevision() async throws {
        let fixture = try makeDirectoryFixture()
        defer { fixture.cleanup() }
        let storageURL = fixture.directoryURL.appendingPathComponent("entries.json")
        let newerEntries = [makeEntry(title: "较新快照", createdAt: Date(timeIntervalSince1970: 200))]
        let olderEntries = [makeEntry(title: "较旧快照", createdAt: Date(timeIntervalSince1970: 100))]
        let writer = JSONJournalPersistenceWriter(storageURL: storageURL)

        let newerResult = await writer.persist(.init(revision: 2, entries: newerEntries))
        let olderResult = await writer.persist(.init(revision: 1, entries: olderEntries))

        XCTAssertEqual(newerResult, .written(revision: 2))
        XCTAssertEqual(
            olderResult,
            .rejectedStale(revision: 1, highestAcceptedRevision: 2)
        )
        XCTAssertEqual(try decodeEntries(from: storageURL), newerEntries)
    }

    func testProductionWriterSkipsSecondWriteForDurableRevision() async throws {
        let fixture = try makeDirectoryFixture()
        defer { fixture.cleanup() }
        let storageURL = fixture.directoryURL.appendingPathComponent("entries.json")
        let countURL = fixture.directoryURL.appendingPathComponent("write-count")
        let entries = [makeEntry(title: "幂等", createdAt: Date(timeIntervalSince1970: 100))]
        let writer = JSONJournalPersistenceWriter(storageURL: storageURL) {
            var countData = (try? Data(contentsOf: countURL)) ?? Data()
            countData.append(1)
            try? countData.write(to: countURL, options: [.atomic])
        }
        let snapshot = JournalPersistenceSnapshot(revision: 3, entries: entries)

        let firstResult = await writer.persist(snapshot)
        let secondResult = await writer.persist(snapshot)

        XCTAssertEqual(firstResult, .written(revision: 3))
        XCTAssertEqual(secondResult, .alreadyDurable(revision: 3))
        XCTAssertEqual(try Data(contentsOf: countURL), Data([1]))
    }

    func testProductionWriterRetriesFailedRevisionAndStillRejectsOlderRevision() async throws {
        let fixture = try makeDirectoryFixture()
        defer { fixture.cleanup() }
        let parentURL = fixture.directoryURL.appendingPathComponent("missing", isDirectory: true)
        let storageURL = parentURL.appendingPathComponent("entries.json")
        let currentEntries = [makeEntry(title: "重试", createdAt: Date(timeIntervalSince1970: 200))]
        let olderEntries = [makeEntry(title: "不得回退", createdAt: Date(timeIntervalSince1970: 100))]
        let writer = JSONJournalPersistenceWriter(storageURL: storageURL)

        let failedResult = await writer.persist(.init(revision: 2, entries: currentEntries))
        try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
        let retryResult = await writer.persist(.init(revision: 2, entries: currentEntries))
        let staleResult = await writer.persist(.init(revision: 1, entries: olderEntries))

        guard case .failed(revision: 2, message: let message) = failedResult else {
            return XCTFail("预期首次写入失败，实际为 \(failedResult)")
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertEqual(retryResult, .written(revision: 2))
        XCTAssertEqual(staleResult, .rejectedStale(revision: 1, highestAcceptedRevision: 2))
        XCTAssertEqual(try decodeEntries(from: storageURL), currentEntries)
    }

    func testStarterEntryUsesPersistenceWriter() async throws {
        let fixture = try makeDirectoryFixture()
        defer { fixture.cleanup() }
        let storageURL = fixture.directoryURL.appendingPathComponent("entries.json")
        let writer = GatePersistenceWriter()

        let store = JournalStore(storageURL: storageURL, persistenceWriter: writer)
        let snapshot = await writer.nextRequest()

        XCTAssertEqual(store.revision, 1)
        XCTAssertEqual(snapshot.revision, 1)
        XCTAssertEqual(snapshot.entries, store.entries)
        XCTAssertEqual(snapshot.entries.count, 1)
        await writer.complete(revision: 1, with: .written(revision: 1))
    }

    func testPersistenceWaitDoesNotBlockMainActor() async throws {
        let writer = GatePersistenceWriter()
        let scheduler = ManualSaveScheduler()
        let fixture = try makeStoreFixture(writer: writer, scheduler: scheduler)
        defer { fixture.cleanup() }
        var existingEntry = try XCTUnwrap(fixture.store.entries.first)
        existingEntry.body = "in flight"
        fixture.store.update(existingEntry)
        let oldWriteTask = try XCTUnwrap(scheduler.fireNext())
        let oldSnapshot = await writer.nextRequest()

        let entryID = fixture.store.createEntry()
        let latestSnapshot = await writer.nextRequest()
        var mainActorMarker = false

        mainActorMarker = fixture.store.entry(with: entryID) != nil

        XCTAssertTrue(mainActorMarker)
        XCTAssertEqual(oldSnapshot.revision, 1)
        XCTAssertEqual(latestSnapshot.revision, 2)
        XCTAssertTrue(latestSnapshot.entries.contains { $0.id == entryID })
        XCTAssertEqual(scheduler.pendingCount, 0)

        await writer.complete(revision: 1, with: .failed(revision: 1, message: "stale failure"))
        await writer.complete(revision: 2, with: .written(revision: 2))
        await oldWriteTask.value
        XCTAssertNil(fixture.store.errorMessage)
    }

    func testUpdateDebounceUsesManualSchedulerAndOnlySubmitsLatestSnapshot() async throws {
        let writer = GatePersistenceWriter()
        let scheduler = ManualSaveScheduler()
        let fixture = try makeStoreFixture(writer: writer, scheduler: scheduler)
        defer { fixture.cleanup() }
        let entry = try XCTUnwrap(fixture.store.entries.first)

        var firstUpdate = entry
        firstUpdate.body = "first"
        fixture.store.update(firstUpdate)
        var secondUpdate = try XCTUnwrap(fixture.store.entry(with: entry.id))
        secondUpdate.body = "second"
        fixture.store.update(secondUpdate)

        XCTAssertEqual(fixture.store.entry(with: entry.id)?.body, "second")
        XCTAssertEqual(scheduler.pendingCount, 1)
        let requestCountBeforeFire = await writer.requestCount()
        XCTAssertEqual(requestCountBeforeFire, 0)

        let scheduledTask = try XCTUnwrap(scheduler.fireNext())
        let snapshot = await writer.nextRequest()
        XCTAssertEqual(snapshot.revision, 2)
        XCTAssertEqual(snapshot.entries.first?.body, "second")
        await writer.complete(revision: 2, with: .written(revision: 2))
        await scheduledTask.value
    }

    func testFlushCancelsDebounceAndWaitsForWriter() async throws {
        let writer = GatePersistenceWriter()
        let scheduler = ManualSaveScheduler()
        let fixture = try makeStoreFixture(writer: writer, scheduler: scheduler)
        defer { fixture.cleanup() }
        var entry = try XCTUnwrap(fixture.store.entries.first)
        entry.body = "flush target"
        fixture.store.update(entry)
        let recorder = PersistenceResultRecorder()

        let flushTask = Task { @MainActor in
            let result = await fixture.store.flushPendingSave()
            await recorder.record(result)
        }
        let snapshot = await writer.nextRequest()

        XCTAssertEqual(snapshot.revision, 1)
        XCTAssertEqual(snapshot.entries.first?.body, "flush target")
        XCTAssertEqual(scheduler.pendingCount, 0)
        let resultBeforeRelease = await recorder.result()
        XCTAssertNil(resultBeforeRelease)

        await writer.complete(revision: 1, with: .written(revision: 1))
        await flushTask.value
        let recordedResult = await recorder.result()
        XCTAssertEqual(recordedResult, .written(revision: 1))
    }

    func testFlushChasesMutationThatOccursWhileWriterIsWaiting() async throws {
        let writer = GatePersistenceWriter()
        let scheduler = ManualSaveScheduler()
        let fixture = try makeStoreFixture(writer: writer, scheduler: scheduler)
        defer { fixture.cleanup() }
        var entry = try XCTUnwrap(fixture.store.entries.first)
        entry.body = "revision one"
        fixture.store.update(entry)

        let flushTask = Task { @MainActor in
            await fixture.store.flushPendingSave()
        }
        let firstSnapshot = await writer.nextRequest()
        var latestEntry = try XCTUnwrap(fixture.store.entry(with: entry.id))
        latestEntry.body = "revision two"
        fixture.store.update(latestEntry)

        XCTAssertEqual(fixture.store.entry(with: entry.id)?.body, "revision two")
        await writer.complete(revision: 1, with: .written(revision: 1))

        let secondSnapshot = await writer.nextRequest()
        XCTAssertEqual(firstSnapshot.revision, 1)
        XCTAssertEqual(secondSnapshot.revision, 2)
        XCTAssertEqual(secondSnapshot.entries.first?.body, "revision two")
        XCTAssertEqual(scheduler.pendingCount, 0)
        await writer.complete(revision: 2, with: .written(revision: 2))
        let result = await flushTask.value
        XCTAssertEqual(result, .written(revision: 2))
    }

    func testCreateIsImmediatelyReadableAndFlushMakesItDurable() async throws {
        let scheduler = ManualSaveScheduler()
        let fixture = try makeProductionStoreFixture(scheduler: scheduler)
        defer { fixture.cleanup() }

        let entryID = fixture.store.createEntry()

        XCTAssertNotNil(fixture.store.entry(with: entryID))
        let result = await fixture.store.flushPendingSave()
        XCTAssertTrue(result?.isSuccessful == true)
        XCTAssertTrue(try decodeEntries(from: fixture.storageURL).contains { $0.id == entryID })
    }

    func testDeleteIsImmediatelyVisibleAndInvalidDeleteDoesNotMutateRevision() async throws {
        let scheduler = ManualSaveScheduler()
        let originalEntry = makeEntry(title: "待删除", createdAt: Date(timeIntervalSince1970: 100))
        let fixture = try makeProductionStoreFixture(entries: [originalEntry], scheduler: scheduler)
        defer { fixture.cleanup() }

        fixture.store.delete(originalEntry)
        let revisionAfterDelete = fixture.store.revision
        fixture.store.delete(originalEntry)

        XCTAssertNil(fixture.store.entry(with: originalEntry.id))
        XCTAssertEqual(fixture.store.revision, revisionAfterDelete)
        let result = await fixture.store.flushPendingSave()
        XCTAssertTrue(result?.isSuccessful == true)
        XCTAssertFalse(try decodeEntries(from: fixture.storageURL).contains { $0.id == originalEntry.id })
    }

    func testOldFailureDoesNotPublishAfterNewerRevisionExists() async throws {
        let writer = GatePersistenceWriter()
        let scheduler = ManualSaveScheduler()
        let fixture = try makeStoreFixture(writer: writer, scheduler: scheduler)
        defer { fixture.cleanup() }
        var entry = try XCTUnwrap(fixture.store.entries.first)
        entry.body = "old"
        fixture.store.update(entry)
        let oldTask = try XCTUnwrap(scheduler.fireNext())
        _ = await writer.nextRequest()

        var latestEntry = try XCTUnwrap(fixture.store.entry(with: entry.id))
        latestEntry.body = "latest"
        fixture.store.update(latestEntry)
        await writer.complete(revision: 1, with: .failed(revision: 1, message: "old failure"))
        await oldTask.value

        XCTAssertNil(fixture.store.errorMessage)

        let flushTask = Task { @MainActor in await fixture.store.flushPendingSave() }
        _ = await writer.nextRequest()
        await writer.complete(revision: 2, with: .written(revision: 2))
        _ = await flushTask.value
    }

    func testLatestFailureRetriesSameRevisionAndReadErrorSurvivesSuccess() async throws {
        let writer = GatePersistenceWriter()
        let scheduler = ManualSaveScheduler()
        let fixture = try makeStoreFixture(writer: writer, scheduler: scheduler)
        defer { fixture.cleanup() }
        var entry = try XCTUnwrap(fixture.store.entries.first)
        entry.body = "failure target"
        fixture.store.update(entry)

        let firstFlush = Task { @MainActor in await fixture.store.flushPendingSave() }
        _ = await writer.nextRequest()
        await writer.complete(revision: 1, with: .failed(revision: 1, message: "disk full"))
        let firstResult = await firstFlush.value
        XCTAssertEqual(firstResult, .failed(revision: 1, message: "disk full"))
        XCTAssertEqual(fixture.store.errorMessage, "写入本地日记失败：disk full")

        let retryFlush = Task { @MainActor in await fixture.store.flushPendingSave() }
        let retrySnapshot = await writer.nextRequest()
        XCTAssertEqual(retrySnapshot.revision, 1)
        await writer.complete(revision: 1, with: .written(revision: 1))
        let retryResult = await retryFlush.value
        XCTAssertEqual(retryResult, .written(revision: 1))
        XCTAssertNil(fixture.store.errorMessage)

        let corruptFixture = try makeCorruptStoreFixture(writer: writer, scheduler: scheduler)
        defer { corruptFixture.cleanup() }
        XCTAssertTrue(corruptFixture.store.errorMessage?.hasPrefix("读取本地日记失败：") == true)
        let readError = corruptFixture.store.errorMessage
        let readFlush = Task { @MainActor in await corruptFixture.store.flushPendingSave() }
        _ = await writer.nextRequest()
        await writer.complete(revision: 0, with: .written(revision: 0))
        _ = await readFlush.value
        XCTAssertEqual(corruptFixture.store.errorMessage, readError)
        corruptFixture.store.dismissError()
        XCTAssertNil(corruptFixture.store.errorMessage)
    }

    func testBodyUpdateKeepsExistingCreatedAtOrder() throws {
        let olderEntry = makeEntry(title: "较早", createdAt: Date(timeIntervalSince1970: 100))
        let newerEntry = makeEntry(title: "较新", createdAt: Date(timeIntervalSince1970: 200))
        let scheduler = ManualSaveScheduler()
        let fixture = try makeStoreFixture(entries: [newerEntry, olderEntry], scheduler: scheduler)
        defer { fixture.cleanup() }

        var updatedOlderEntry = olderEntry
        updatedOlderEntry.body = "只修改正文"
        fixture.store.update(updatedOlderEntry)

        XCTAssertEqual(fixture.store.entries.map(\.id), [newerEntry.id, olderEntry.id])
        XCTAssertEqual(fixture.store.entry(with: olderEntry.id)?.body, "只修改正文")
    }

    func testCreatedAtUpdateReordersEntries() throws {
        let olderEntry = makeEntry(title: "较早", createdAt: Date(timeIntervalSince1970: 100))
        let newerEntry = makeEntry(title: "较新", createdAt: Date(timeIntervalSince1970: 200))
        let scheduler = ManualSaveScheduler()
        let fixture = try makeStoreFixture(entries: [newerEntry, olderEntry], scheduler: scheduler)
        defer { fixture.cleanup() }

        var updatedOlderEntry = olderEntry
        updatedOlderEntry.createdAt = Date(timeIntervalSince1970: 300)
        fixture.store.update(updatedOlderEntry)

        XCTAssertEqual(fixture.store.entries.map(\.id), [olderEntry.id, newerEntry.id])
        XCTAssertEqual(fixture.store.entry(with: olderEntry.id)?.createdAt, updatedOlderEntry.createdAt)
    }

    private func makeDirectoryFixture() throws -> DirectoryFixture {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mdjournal-store-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return DirectoryFixture(directoryURL: directoryURL)
    }

    private func makeStoreFixture(
        entries: [JournalEntry]? = nil,
        writer: GatePersistenceWriter = GatePersistenceWriter(),
        scheduler: ManualSaveScheduler
    ) throws -> StoreFixture {
        let directoryFixture = try makeDirectoryFixture()
        let storageURL = directoryFixture.directoryURL.appendingPathComponent("entries.json")
        try encode(entries: entries ?? [makeEntry(title: "种子", createdAt: Date(timeIntervalSince1970: 100))], to: storageURL)
        let store = JournalStore(
            storageURL: storageURL,
            persistenceWriter: writer,
            saveScheduler: scheduler
        )
        return StoreFixture(store: store, directoryURL: directoryFixture.directoryURL, storageURL: storageURL)
    }

    private func makeProductionStoreFixture(
        entries: [JournalEntry] = [],
        scheduler: ManualSaveScheduler
    ) throws -> StoreFixture {
        let directoryFixture = try makeDirectoryFixture()
        let storageURL = directoryFixture.directoryURL.appendingPathComponent("entries.json")
        try encode(entries: entries, to: storageURL)
        let store = JournalStore(storageURL: storageURL, saveScheduler: scheduler)
        return StoreFixture(store: store, directoryURL: directoryFixture.directoryURL, storageURL: storageURL)
    }

    private func makeCorruptStoreFixture(
        writer: GatePersistenceWriter,
        scheduler: ManualSaveScheduler
    ) throws -> StoreFixture {
        let directoryFixture = try makeDirectoryFixture()
        let storageURL = directoryFixture.directoryURL.appendingPathComponent("entries.json")
        try Data("not json".utf8).write(to: storageURL)
        let store = JournalStore(
            storageURL: storageURL,
            persistenceWriter: writer,
            saveScheduler: scheduler
        )
        return StoreFixture(store: store, directoryURL: directoryFixture.directoryURL, storageURL: storageURL)
    }

    private func decodeEntries(from storageURL: URL) throws -> [JournalEntry] {
        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([JournalEntry].self, from: data)
    }

    private func encode(entries: [JournalEntry], to storageURL: URL) throws {
        try referenceJSONData(for: entries).write(to: storageURL)
    }

    private func referenceJSONData(for entries: [JournalEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries)
    }

    private func makeEntry(title: String, createdAt: Date) -> JournalEntry {
        JournalEntry(
            title: title,
            body: "### 小节\n\n正文",
            createdAt: createdAt,
            updatedAt: createdAt,
            category: .daily,
            mood: .calm
        )
    }
}

private actor GatePersistenceWriter: JournalPersistenceWriting {
    private struct PendingRequest {
        let snapshot: JournalPersistenceSnapshot
        let continuation: CheckedContinuation<JournalPersistenceResult, Never>
    }

    private var pendingRequests: [PendingRequest] = []
    private var unobservedSnapshots: [JournalPersistenceSnapshot] = []
    private var snapshotWaiters: [CheckedContinuation<JournalPersistenceSnapshot, Never>] = []
    private var totalRequestCount = 0

    func persist(_ snapshot: JournalPersistenceSnapshot) async -> JournalPersistenceResult {
        totalRequestCount += 1
        return await withCheckedContinuation { continuation in
            pendingRequests.append(PendingRequest(snapshot: snapshot, continuation: continuation))
            if snapshotWaiters.isEmpty {
                unobservedSnapshots.append(snapshot)
            } else {
                snapshotWaiters.removeFirst().resume(returning: snapshot)
            }
        }
    }

    func nextRequest() async -> JournalPersistenceSnapshot {
        if !unobservedSnapshots.isEmpty {
            return unobservedSnapshots.removeFirst()
        }

        return await withCheckedContinuation { continuation in
            snapshotWaiters.append(continuation)
        }
    }

    func complete(revision: UInt64, with result: JournalPersistenceResult) {
        guard let index = pendingRequests.firstIndex(where: { $0.snapshot.revision == revision }) else {
            preconditionFailure("没有 revision \(revision) 的待完成写入")
        }

        pendingRequests.remove(at: index).continuation.resume(returning: result)
    }

    func requestCount() -> Int {
        totalRequestCount
    }
}

@MainActor
private final class ManualSaveScheduler: JournalSaveScheduling {
    private struct PendingOperation {
        let id: UUID
        let operation: @MainActor @Sendable () async -> Void
    }

    private var pendingOperations: [PendingOperation] = []

    var pendingCount: Int {
        pendingOperations.count
    }

    func schedule(
        after delay: Duration,
        operation: @escaping @MainActor @Sendable () async -> Void
    ) -> JournalScheduledSave {
        enqueue(operation)
    }

    func fireNext() -> Task<Void, Never>? {
        guard !pendingOperations.isEmpty else { return nil }
        let operation = pendingOperations.removeFirst().operation
        return Task { @MainActor in
            await operation()
        }
    }

    private func enqueue(
        _ operation: @escaping @MainActor @Sendable () async -> Void
    ) -> JournalScheduledSave {
        let id = UUID()
        pendingOperations.append(PendingOperation(id: id, operation: operation))
        return JournalScheduledSave { [weak self] in
            self?.pendingOperations.removeAll { $0.id == id }
        }
    }
}

private actor PersistenceResultRecorder {
    private var recordedResult: JournalPersistenceResult?

    func record(_ result: JournalPersistenceResult?) {
        recordedResult = result
    }

    func result() -> JournalPersistenceResult? {
        recordedResult
    }
}

private struct DirectoryFixture {
    let directoryURL: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private struct StoreFixture {
    let store: JournalStore
    let directoryURL: URL
    let storageURL: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private extension JournalPersistenceResult {
    var isSuccessful: Bool {
        switch self {
        case .written, .alreadyDurable:
            true
        case .rejectedStale, .failed:
            false
        }
    }
}
