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

    func testInlineCacheCoversOrdinaryIntroAndSectionBlocksWithUniqueConversions() {
        let blocks = """
        # **shared**
        ## **heading**

        **shared**

        **paragraph**

        > **shared**
        > **quote**
        - **shared**
        - **unordered**
        007. **shared**
        008. **ordered**
        - [ ] **shared**
        - [x] **checklist**

        plain 中文

        ```
        **code only**
        ```
        ```
        ```
        ---
        """
        let markedTexts = [
            "**shared**", "**heading**", "**paragraph**", "**quote**",
            "**unordered**", "**ordered**", "**checklist**"
        ]

        for grouped in [false, true] {
            let markdown = grouped
                ? blocks + "\n### **literal title**\n" + blocks + "\n### **empty title**"
                : blocks
            var calls: [String: Int] = [:]
            var parseCount = 0
            let model = MarkdownPreviewUpdateModel(
                inlineRenderer: { text in
                    calls[text, default: 0] += 1
                    return AttributedString("rendered: " + text)
                },
                parseDocument: { text in
                    parseCount += 1
                    return MarkdownBlockParser.parseDocument(text)
                }
            )
            model.activate(entryID: UUID(), markdown: markdown)
            let snapshot = model.snapshot
            XCTAssertEqual(parseCount, 1)
            XCTAssertEqual(snapshot.document, MarkdownBlockParser.parseDocument(markdown))
            XCTAssertEqual(snapshot.document.shouldUseSectionGroups, grouped)
            XCTAssertEqual(calls, Dictionary(uniqueKeysWithValues: markedTexts.map { ($0, 1) }))
            for _ in 0..<3 {
                for text in markedTexts {
                    XCTAssertEqual(snapshot.inlineCache[text], AttributedString("rendered: " + text))
                }
                XCTAssertEqual(snapshot.inlineCache["plain 中文"], AttributedString("plain 中文"))
                XCTAssertNil(snapshot.inlineCache["**code only**"])
                XCTAssertNil(snapshot.inlineCache["**literal title**"])
                XCTAssertNil(snapshot.inlineCache["**empty title**"])
                XCTAssertNil(snapshot.inlineCache["007."])
                XCTAssertNil(snapshot.inlineCache[""])
                XCTAssertNil(snapshot.inlineCache["missing"])
            }
            XCTAssertEqual(calls, Dictionary(uniqueKeysWithValues: markedTexts.map { ($0, 1) }))
            if grouped {
                XCTAssertTrue(snapshot.document.sectionGroups[0].isIntro)
                XCTAssertEqual(snapshot.document.sectionGroups[1].title, "**literal title**")
                XCTAssertEqual(snapshot.document.sectionGroups[2].title, "**empty title**")
                XCTAssertTrue(snapshot.document.sectionGroups[2].blocks.isEmpty)
            }
        }
    }

    func testDefaultInlineCachePreservesExistingInlineMarkdownSemantics() throws {
        let samples = [
            "**bold**", "*italic*", "_italic_", "`code`", "[link](https://example.com)",
            "\\*escaped\\*", "&amp;", "**unfinished", "a_b", "~~strike~~", "a|b",
            "!", "<tag>", "[", "]", "(", ")", "plain 中文 123。", "", " \t ",
            "普通第一行\n第二行", "**first**\nsecond", "中文 **强调** 👩🏽‍💻 e\u{301}",
            "**Case**", "**case**", " **Case** "
        ]
        let document = MarkdownParseResult(
            blocks: samples.map { .paragraph($0) }, sectionGroups: []
        )
        let cache = MarkdownPreviewInlineCache(document: document)
        for text in samples {
            let value = try XCTUnwrap(cache[text], text)
            XCTAssertEqual(value, MarkdownPreviewView.inlineMarkdown(text), text)
            let expected: AttributedString
            if MarkdownPreviewView.shouldParseInlineMarkdown(text) {
                expected = (try? AttributedString(markdown: text)) ?? AttributedString(text)
            } else {
                expected = AttributedString(text)
            }
            XCTAssertEqual(value, expected, text)
        }
        XCTAssertNil(cache["not in the document"])
    }

    func testThrowingRendererCachesOriginalTextAndNeverRetriesOnLookup() {
        enum RenderFailure: Error { case expected }
        let marked = ["**Case**", "**case**", " **Case** "]
        let plain = ["plain", "", " \t ", "中文\n第二行"]
        let document = MarkdownParseResult(
            blocks: (marked + marked + plain + plain).map { .paragraph($0) },
            sectionGroups: []
        )
        var calls: [String: Int] = [:]
        let cache = MarkdownPreviewInlineCache(document: document) { text in
            calls[text, default: 0] += 1
            throw RenderFailure.expected
        }
        for _ in 0..<3 {
            for text in marked + plain {
                XCTAssertEqual(cache[text], AttributedString(text))
            }
            XCTAssertNil(cache["**missing**"])
        }
        XCTAssertEqual(calls, Dictionary(uniqueKeysWithValues: marked.map { ($0, 1) }))
    }

    func testSnapshotReplacementKeepsCapturedDocumentAndCacheTogether() async throws {
        let scheduler = ManualMarkdownPreviewScheduler()
        var rendered: [String] = []
        var parsed: [String] = []
        let model = MarkdownPreviewUpdateModel(
            scheduler: scheduler,
            inlineRenderer: { text in
                rendered.append(text)
                return AttributedString("rendered: " + text)
            },
            parseDocument: { text in
                parsed.append(text)
                return MarkdownBlockParser.parseDocument(text)
            }
        )
        let entryID = UUID()
        XCTAssertTrue(model.snapshot.document.blocks.isEmpty)
        XCTAssertNil(model.snapshot.inlineCache["**old**"])
        XCTAssertTrue(parsed.isEmpty)
        XCTAssertTrue(rendered.isEmpty)

        model.activate(entryID: entryID, markdown: "**old**")
        let oldSnapshot = model.snapshot
        let generation = model.requestGeneration
        model.update(entryID: entryID, markdown: "**old**")
        model.activate(entryID: entryID, markdown: "**old**")
        XCTAssertEqual(model.requestGeneration, generation)
        XCTAssertEqual(scheduler.pendingCount, 0)
        XCTAssertEqual(rendered, ["**old**"])

        model.update(entryID: entryID, markdown: "### title\n**new**")
        let pendingGeneration = model.requestGeneration
        model.activate(entryID: entryID, markdown: "### title\n**new**")
        XCTAssertEqual(model.requestGeneration, pendingGeneration)
        XCTAssertEqual(scheduler.pendingCount, 1)
        XCTAssertEqual(scheduler.scheduledDelays, [.milliseconds(150)])
        for _ in 0..<3 {
            XCTAssertEqual(model.snapshot, oldSnapshot)
            XCTAssertEqual(model.snapshot.inlineCache["**old**"], AttributedString("rendered: **old**"))
        }
        XCTAssertEqual(rendered, ["**old**"])

        await scheduler.fireNext()
        XCTAssertEqual(model.document, MarkdownBlockParser.parseDocument("### title\n**new**"))
        XCTAssertEqual(model.snapshot.inlineCache["**new**"], AttributedString("rendered: **new**"))
        XCTAssertNil(model.snapshot.inlineCache["**old**"])
        guard case let .paragraph(oldText) = try XCTUnwrap(oldSnapshot.document.blocks.first) else {
            return XCTFail("Expected the captured old paragraph")
        }
        XCTAssertEqual(oldText, "**old**")
        XCTAssertEqual(oldSnapshot.inlineCache[oldText], AttributedString("rendered: **old**"))
        XCTAssertNil(oldSnapshot.inlineCache["**new**"])
        XCTAssertEqual(rendered, ["**old**", "**new**"])

        model.update(entryID: entryID, markdown: "")
        await scheduler.fireNext()
        XCTAssertEqual(model.snapshot, MarkdownPreviewRenderSnapshot())
        XCTAssertNil(model.snapshot.inlineCache["**new**"])
        XCTAssertNil(model.snapshot.inlineCache["**old**"])
        XCTAssertEqual(parsed, ["**old**", "### title\n**new**", ""])
        XCTAssertEqual(rendered, ["**old**", "**new**"])
    }

    func testSameBodyDifferentEntryAndReactivationBuildFreshCaches() {
        let scheduler = ManualMarkdownPreviewScheduler()
        var parseCount = 0
        var renderCount = 0
        let model = MarkdownPreviewUpdateModel(
            scheduler: scheduler,
            inlineRenderer: { text in
                renderCount += 1
                return AttributedString("\(renderCount):" + text)
            },
            parseDocument: { text in
                parseCount += 1
                return MarkdownBlockParser.parseDocument(text)
            }
        )
        let firstID = UUID()
        let secondID = UUID()
        model.activate(entryID: firstID, markdown: "**same**")
        let firstSnapshot = model.snapshot
        model.update(entryID: secondID, markdown: "**same**")
        XCTAssertEqual(model.snapshot.inlineCache["**same**"], AttributedString("2:**same**"))
        XCTAssertEqual(firstSnapshot.inlineCache["**same**"], AttributedString("1:**same**"))
        let secondSnapshot = model.snapshot
        model.deactivate()
        model.update(entryID: secondID, markdown: "**ignored**")
        XCTAssertEqual(model.snapshot, secondSnapshot)
        model.activate(entryID: secondID, markdown: "**same**")
        XCTAssertEqual(model.snapshot.inlineCache["**same**"], AttributedString("3:**same**"))
        XCTAssertNil(model.snapshot.inlineCache["**ignored**"])
        XCTAssertEqual(parseCount, 3)
        XCTAssertEqual(renderCount, 3)
        XCTAssertEqual(scheduler.pendingCount, 0)
    }

    func testInvalidatedTasksDoNotParseRenderOrReplaceSnapshot() async {
        let scheduler = ManualMarkdownPreviewScheduler()
        var parsed: [String] = []
        var rendered: [String] = []
        let model = MarkdownPreviewUpdateModel(
            scheduler: scheduler,
            inlineRenderer: { text in
                rendered.append(text)
                return AttributedString(text)
            },
            parseDocument: { text in
                parsed.append(text)
                return MarkdownBlockParser.parseDocument(text)
            }
        )
        let firstID = UUID()
        let secondID = UUID()
        model.activate(entryID: firstID, markdown: "**A**")
        let firstSnapshot = model.snapshot
        model.update(entryID: firstID, markdown: "**B**")
        model.update(entryID: firstID, markdown: "**C**")
        await scheduler.fireNext()
        XCTAssertEqual(model.snapshot, firstSnapshot)
        XCTAssertEqual(parsed, ["**A**"])
        XCTAssertEqual(rendered, ["**A**"])
        await scheduler.fireNext()
        XCTAssertEqual(model.snapshot.inlineCache["**C**"], AttributedString("**C**"))
        XCTAssertEqual(parsed, ["**A**", "**C**"])
        XCTAssertEqual(rendered, ["**A**", "**C**"])

        model.update(entryID: firstID, markdown: "**old entry pending**")
        model.activate(entryID: secondID, markdown: "**D**")
        let secondSnapshot = model.snapshot
        await scheduler.fireNext()
        XCTAssertEqual(model.snapshot, secondSnapshot)
        XCTAssertEqual(parsed, ["**A**", "**C**", "**D**"])
        XCTAssertEqual(rendered, parsed)

        model.update(entryID: secondID, markdown: "**hidden pending**")
        model.deactivate()
        await scheduler.fireNext()
        XCTAssertEqual(model.snapshot, secondSnapshot)
        XCTAssertEqual(parsed, ["**A**", "**C**", "**D**"])
        XCTAssertEqual(rendered, parsed)

        model.activate(entryID: secondID, markdown: "**D**")
        model.update(entryID: secondID, markdown: "**reactivation pending**")
        model.deactivate()
        model.activate(entryID: secondID, markdown: "**reactivation pending**")
        let reactivatedSnapshot = model.snapshot
        await scheduler.fireNext()
        XCTAssertEqual(model.snapshot, reactivatedSnapshot)
        XCTAssertEqual(parsed, ["**A**", "**C**", "**D**", "**D**", "**reactivation pending**"])
        XCTAssertEqual(rendered, parsed)
        XCTAssertEqual(scheduler.cancellationCount, 4)
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
