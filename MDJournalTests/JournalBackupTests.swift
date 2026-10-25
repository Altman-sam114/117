import XCTest
@testable import MDJournal

@MainActor
final class JournalBackupTests: XCTestCase {
    func testBackupRoundTripPreservesUnicodeAndLegacyMetadataDefaults() throws {
        let entry = makeEntry(title: "河边 👨‍👩‍👧‍👦 e\u{301}", body: "### 今天\n\n中文 **记录**\r\n- [ ] 明天")
        let data = try JournalBackupCodec.encode([entry])
        XCTAssertEqual(try JournalBackupCodec.decode(data), [entry])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        json[0].removeValue(forKey: "updatedAt")
        json[0].removeValue(forKey: "category")
        json[0].removeValue(forKey: "mood")
        let legacy = try XCTUnwrap(JournalBackupCodec.decode(JSONSerialization.data(withJSONObject: json)).first)
        XCTAssertEqual(legacy.updatedAt, legacy.createdAt)
        XCTAssertEqual(legacy.category, .daily)
        XCTAssertEqual(legacy.mood, .calm)
        XCTAssertEqual(legacy.body, entry.body)
    }

    func testImportPreviewDoesNotWriteAndConfirmationOnlyAppendsNewIdentifiers() async throws {
        let existing = makeEntry(title: "本机原文", body: "不能覆盖")
        let fixture = try makeFixture(entries: [existing])
        defer { fixture.cleanup() }
        let store = JournalStore(storageURL: fixture.file)
        let originalBytes = try Data(contentsOf: fixture.file)
        var conflict = existing
        conflict.title = "导入冲突"
        conflict.body = "不同正文"
        let addition = makeEntry(title: "新篇", body: "### 新小节\n记录", date: 200)
        let preview = try store.prepareImport([conflict, addition])
        XCTAssertEqual(preview.newEntryCount, 1)
        XCTAssertEqual(preview.existingEntryCount, 1)
        XCTAssertEqual(store.revision, 0)
        XCTAssertEqual(try Data(contentsOf: fixture.file), originalBytes)
        XCTAssertEqual(try store.confirmImport(preview), 1)
        XCTAssertEqual(store.revision, 1)
        XCTAssertEqual(store.entries.map(\.id), [addition.id, existing.id])
        XCTAssertEqual(store.entry(with: existing.id), existing)
        XCTAssertEqual(Set(store.bodyPresentations.keys), Set(store.entries.map(\.id)))
        _ = await store.flushPendingSave()
        XCTAssertEqual(try JournalBackupCodec.decode(Data(contentsOf: fixture.file)), store.entries)
    }

    func testSameIdentifierImportIsANoOpAndDoesNotRewriteDisk() throws {
        let entry = makeEntry(title: "保留", body: "原文")
        let fixture = try makeFixture(entries: [entry])
        defer { fixture.cleanup() }
        let store = JournalStore(storageURL: fixture.file)
        let originalBytes = try Data(contentsOf: fixture.file)
        let preview = try store.prepareImport([entry])
        XCTAssertEqual(try store.confirmImport(preview), 0)
        XCTAssertEqual(store.revision, 0)
        XCTAssertEqual(try Data(contentsOf: fixture.file), originalBytes)
    }

    func testStalePreviewCannotOverwriteEditsOrPartiallyImport() async throws {
        let entry = makeEntry(title: "旧标题", body: "本机内容")
        let fixture = try makeFixture(entries: [entry])
        defer { fixture.cleanup() }
        let store = JournalStore(storageURL: fixture.file)
        let addition = makeEntry(title: "待导入", body: "外部内容", date: 200)
        let preview = try store.prepareImport([addition])
        var edited = entry
        edited.title = "最新标题"
        store.update(edited)
        let revision = store.revision
        XCTAssertThrowsError(try store.confirmImport(preview)) { error in
            XCTAssertEqual(error as? JournalBackupError, .stalePreview)
        }
        XCTAssertEqual(store.revision, revision)
        XCTAssertNil(store.entry(with: addition.id))
        XCTAssertEqual(store.entries.first?.title, "最新标题")
        _ = await store.flushPendingSave()
        XCTAssertEqual(try JournalBackupCodec.decode(Data(contentsOf: fixture.file)).first?.title, "最新标题")
    }

    func testInvalidDuplicateAndOversizeBackupsAreRejectedBeforeMutation() throws {
        XCTAssertThrowsError(try JournalBackupCodec.decode(Data("not json".utf8))) { error in
            XCTAssertEqual(error as? JournalBackupError, .invalidFormat)
        }
        let entry = makeEntry(title: "重复", body: "内容")
        XCTAssertThrowsError(try JournalBackupCodec.decode(JournalBackupCodec.encode([entry, entry]))) { error in
            XCTAssertEqual(error as? JournalBackupError, .duplicateIdentifiers)
        }
        XCTAssertThrowsError(try JournalBackupCodec.decode(Data(repeating: 0x20, count: JournalBackupCodec.maximumBytes + 1))) { error in
            XCTAssertEqual(error as? JournalBackupError, .tooLarge)
        }
        let fixture = try makeFixture(entries: [entry])
        defer { fixture.cleanup() }
        let store = JournalStore(storageURL: fixture.file)
        let bytes = try Data(contentsOf: fixture.file)
        XCTAssertThrowsError(try store.prepareImport([entry, entry]))
        XCTAssertEqual(store.revision, 0)
        XCTAssertEqual(try Data(contentsOf: fixture.file), bytes)
    }

    func testBackupExportUsesCurrentUnsavedSnapshotWithoutMutatingStore() async throws {
        let entry = makeEntry(title: "标题", body: "旧正文")
        let fixture = try makeFixture(entries: [entry])
        defer { fixture.cleanup() }
        let store = JournalStore(storageURL: fixture.file, saveDebounceNanoseconds: 30_000_000_000)
        var changed = entry
        changed.body = "尚在内存的新正文 📝"
        store.update(changed)
        let revision = store.revision
        let data = try await store.exportBackupData()
        XCTAssertEqual(try JournalBackupCodec.decode(data).first?.body, changed.body)
        XCTAssertEqual(store.revision, revision)
        _ = await store.flushPendingSave()
    }

    func testBoundedFileReaderRejectsAnOversizeFileWithoutChangingIt() async throws {
        let fixture = try makeFixture(entries: [])
        defer { fixture.cleanup() }
        let oversized = Data(repeating: 0x20, count: JournalBackupCodec.maximumBytes + 1)
        try oversized.write(to: fixture.file)
        XCTAssertThrowsError(try JournalBackupCodec.readBoundedData(from: fixture.file)) { error in
            XCTAssertEqual(error as? JournalBackupError, .tooLarge)
        }
        let store = JournalStore(storageURL: fixture.file)
        XCTAssertFalse(store.canMutate)
        let recovery = try await store.exportOriginalDataForRecovery()
        XCTAssertEqual(recovery, oversized, "Recovery must preserve original bytes even above the import limit")
        XCTAssertEqual(store.revision, 0)
        let flush = await store.flushPendingSave()
        XCTAssertNil(flush)
        XCTAssertEqual(try Data(contentsOf: fixture.file), oversized)
    }

    private func makeEntry(title: String, body: String, date: TimeInterval = 100) -> JournalEntry {
        let date = Date(timeIntervalSince1970: date)
        return JournalEntry(title: title, body: body, createdAt: date, updatedAt: date, category: .inspiration, mood: .focused)
    }

    private func makeFixture(entries: [JournalEntry]) throws -> BackupFixture {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mdjournal-backup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("entries.json")
        try JournalBackupCodec.encode(entries).write(to: file)
        return BackupFixture(directory: directory, file: file)
    }
}

private struct BackupFixture {
    let directory: URL
    let file: URL
    func cleanup() { try? FileManager.default.removeItem(at: directory) }
}
