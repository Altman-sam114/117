import XCTest
@testable import MDJournal

@MainActor
final class JournalStoreTests: XCTestCase {
    func testCreateEntryPersistsImmediatelyToInjectedStorage() throws {
        let fixture = try makeStoreFixture()
        defer { fixture.cleanup() }

        let entryID = fixture.store.createEntry()
        let savedEntries = try decodeEntries(from: fixture.storageURL)

        XCTAssertTrue(savedEntries.contains { $0.id == entryID })
    }

    func testUpdateDebouncesDiskWriteButKeepsMemoryCurrent() async throws {
        let fixture = try makeStoreFixture(saveDebounceNanoseconds: 120_000_000)
        defer { fixture.cleanup() }

        let entryID = fixture.store.createEntry()
        var entry = try XCTUnwrap(fixture.store.entry(with: entryID))
        entry.body = "debounced body"

        fixture.store.update(entry)

        XCTAssertEqual(fixture.store.entry(with: entryID)?.body, "debounced body")
        XCTAssertFalse(try decodeEntries(from: fixture.storageURL).contains { $0.body == "debounced body" })

        try await Task.sleep(for: .milliseconds(220))

        XCTAssertTrue(try decodeEntries(from: fixture.storageURL).contains { $0.body == "debounced body" })
    }

    func testFlushPendingSaveWritesDebouncedUpdateImmediately() throws {
        let fixture = try makeStoreFixture(saveDebounceNanoseconds: 5_000_000_000)
        defer { fixture.cleanup() }

        let entryID = fixture.store.createEntry()
        var entry = try XCTUnwrap(fixture.store.entry(with: entryID))
        entry.body = "flushed body"

        fixture.store.update(entry)
        fixture.store.flushPendingSave()

        XCTAssertTrue(try decodeEntries(from: fixture.storageURL).contains { $0.body == "flushed body" })
    }

    private func makeStoreFixture(saveDebounceNanoseconds: UInt64 = 450_000_000) throws -> StoreFixture {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mdjournal-store-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let storageURL = directoryURL.appendingPathComponent("entries.json")
        let store = JournalStore(storageURL: storageURL, saveDebounceNanoseconds: saveDebounceNanoseconds)

        return StoreFixture(store: store, directoryURL: directoryURL, storageURL: storageURL)
    }

    private func decodeEntries(from storageURL: URL) throws -> [JournalEntry] {
        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([JournalEntry].self, from: data)
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
