import XCTest
@testable import MDJournal

@MainActor
final class MarkdownPreviewTests: XCTestCase {
    func testInitialActivationPublishesImmediatelyAndDebouncesUpdates() async {
        let scheduler = ManualMarkdownPreviewScheduler()
        var parsedMarkdown: [String] = []
        let model = MarkdownPreviewUpdateModel(scheduler: scheduler) { markdown in
            parsedMarkdown.append(markdown)
            return MarkdownBlockParser.parseDocument(markdown)
        }
        let entryID = UUID()

        model.activate(entryID: entryID, markdown: "初始")
        XCTAssertEqual(parsedMarkdown, ["初始"])

        model.update(entryID: entryID, markdown: "最新")
        XCTAssertEqual(model.document, MarkdownBlockParser.parseDocument("初始"))
        XCTAssertEqual(scheduler.pendingCount, 1)
        XCTAssertEqual(scheduler.scheduledDelays, [.milliseconds(150)])

        await scheduler.fireNext()
        XCTAssertEqual(parsedMarkdown, ["初始", "最新"])
        XCTAssertEqual(model.document, MarkdownBlockParser.parseDocument("最新"))
    }

    func testLatestRequestWinsWhenCancelledRequestArrivesLate() async {
        let scheduler = ManualMarkdownPreviewScheduler()
        var parsedMarkdown: [String] = []
        let model = MarkdownPreviewUpdateModel(scheduler: scheduler) { markdown in
            parsedMarkdown.append(markdown)
            return MarkdownBlockParser.parseDocument(markdown)
        }
        let entryID = UUID()

        model.activate(entryID: entryID, markdown: "A")
        model.update(entryID: entryID, markdown: "B")
        model.update(entryID: entryID, markdown: "C")

        XCTAssertEqual(scheduler.cancellationCount, 1)
        await scheduler.fireNext()
        XCTAssertEqual(parsedMarkdown, ["A"])
        XCTAssertEqual(model.document, MarkdownBlockParser.parseDocument("A"))

        await scheduler.fireNext()
        XCTAssertEqual(parsedMarkdown, ["A", "C"])
        XCTAssertEqual(model.document, MarkdownBlockParser.parseDocument("C"))
    }

    func testEntrySwitchAndDeactivationInvalidatePendingRequests() async {
        let scheduler = ManualMarkdownPreviewScheduler()
        var parsedMarkdown: [String] = []
        let model = MarkdownPreviewUpdateModel(scheduler: scheduler) { markdown in
            parsedMarkdown.append(markdown)
            return MarkdownBlockParser.parseDocument(markdown)
        }
        let firstEntryID = UUID()
        let secondEntryID = UUID()

        model.activate(entryID: firstEntryID, markdown: "旧日记")
        model.update(entryID: firstEntryID, markdown: "旧日记延迟更新")
        model.activate(entryID: secondEntryID, markdown: "新日记")

        await scheduler.fireNext()
        XCTAssertEqual(parsedMarkdown, ["旧日记", "新日记"])
        XCTAssertEqual(model.document, MarkdownBlockParser.parseDocument("新日记"))

        model.update(entryID: secondEntryID, markdown: "隐藏前更新")
        model.deactivate()
        await scheduler.fireNext()

        XCTAssertEqual(parsedMarkdown, ["旧日记", "新日记"])
        XCTAssertFalse(model.isActive)
    }

    func testSameMarkdownDoesNotCreateAnotherRequest() {
        let scheduler = ManualMarkdownPreviewScheduler()
        var parseCount = 0
        let model = MarkdownPreviewUpdateModel(scheduler: scheduler) { markdown in
            parseCount += 1
            return MarkdownBlockParser.parseDocument(markdown)
        }
        let entryID = UUID()

        model.activate(entryID: entryID, markdown: "不变")
        let generation = model.requestGeneration
        model.update(entryID: entryID, markdown: "不变")
        model.activate(entryID: entryID, markdown: "不变")

        XCTAssertEqual(parseCount, 1)
        XCTAssertEqual(model.requestGeneration, generation)
        XCTAssertEqual(scheduler.pendingCount, 0)
    }
}

@MainActor
private final class ManualMarkdownPreviewScheduler: MarkdownPreviewScheduling {
    private struct PendingOperation {
        let operation: @MainActor @Sendable () async -> Void
        let id: UUID
    }

    private var pendingOperations: [PendingOperation] = []
    private var cancelledIDs: Set<UUID> = []
    private(set) var scheduledDelays: [Duration] = []

    var pendingCount: Int {
        pendingOperations.count
    }

    var cancellationCount: Int {
        cancelledIDs.count
    }

    func schedule(
        after delay: Duration,
        operation: @escaping @MainActor @Sendable () async -> Void
    ) -> MarkdownPreviewScheduledUpdate {
        let id = UUID()
        scheduledDelays.append(delay)
        pendingOperations.append(PendingOperation(operation: operation, id: id))
        return MarkdownPreviewScheduledUpdate { [weak self] in
            self?.cancelledIDs.insert(id)
        }
    }

    func fireNext() async {
        guard !pendingOperations.isEmpty else { return }
        let pendingOperation = pendingOperations.removeFirst()
        await pendingOperation.operation()
    }
}
