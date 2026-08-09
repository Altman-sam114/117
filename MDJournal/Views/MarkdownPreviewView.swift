import Combine
import SwiftUI

struct MarkdownPreviewScheduledUpdate: Sendable {
    private let cancellation: @MainActor @Sendable () -> Void

    init(cancellation: @escaping @MainActor @Sendable () -> Void) {
        self.cancellation = cancellation
    }

    @MainActor
    func cancel() {
        cancellation()
    }
}

protocol MarkdownPreviewScheduling: Sendable {
    @MainActor
    func schedule(
        after delay: Duration,
        operation: @escaping @MainActor @Sendable () async -> Void
    ) -> MarkdownPreviewScheduledUpdate
}

struct TaskMarkdownPreviewScheduler: MarkdownPreviewScheduling {
    @MainActor
    func schedule(
        after delay: Duration,
        operation: @escaping @MainActor @Sendable () async -> Void
    ) -> MarkdownPreviewScheduledUpdate {
        let task = Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await operation()
        }

        return MarkdownPreviewScheduledUpdate {
            task.cancel()
        }
    }
}

struct MarkdownPreviewUpdateRequest: Equatable, Sendable {
    let entryID: UUID
    let markdown: String
    let generation: UInt64
}

@MainActor
final class MarkdownPreviewUpdateModel: ObservableObject {
    static let trailingDelay: Duration = .milliseconds(150)

    @Published private(set) var document: MarkdownParseResult

    private let scheduler: any MarkdownPreviewScheduling
    private let parseDocument: (String) -> MarkdownParseResult
    private var scheduledUpdate: MarkdownPreviewScheduledUpdate?
    private var activeEntryID: UUID?
    private var lastRequestedMarkdown: String?
    private(set) var requestGeneration: UInt64 = 0
    private(set) var isActive = false

    init(
        scheduler: any MarkdownPreviewScheduling = TaskMarkdownPreviewScheduler(),
        parseDocument: @escaping (String) -> MarkdownParseResult = MarkdownBlockParser.parseDocument
    ) {
        self.scheduler = scheduler
        self.parseDocument = parseDocument
        document = MarkdownParseResult(blocks: [], sectionGroups: [])
    }

    func activate(entryID: UUID, markdown: String) {
        let entryChanged = activeEntryID != entryID
        guard !isActive || entryChanged else {
            update(entryID: entryID, markdown: markdown)
            return
        }

        cancelScheduledUpdate()
        isActive = true
        activeEntryID = entryID
        lastRequestedMarkdown = markdown
        requestGeneration &+= 1

        publishImmediately(
            MarkdownPreviewUpdateRequest(
                entryID: entryID,
                markdown: markdown,
                generation: requestGeneration
            )
        )
    }

    func update(entryID: UUID, markdown: String) {
        guard isActive else { return }

        guard activeEntryID == entryID else {
            activate(entryID: entryID, markdown: markdown)
            return
        }

        guard lastRequestedMarkdown != markdown else { return }

        lastRequestedMarkdown = markdown
        requestGeneration &+= 1
        let request = MarkdownPreviewUpdateRequest(
            entryID: entryID,
            markdown: markdown,
            generation: requestGeneration
        )

        cancelScheduledUpdate()
        scheduledUpdate = scheduler.schedule(after: Self.trailingDelay) { [weak self] in
            self?.publish(request)
        }
    }

    func deactivate() {
        cancelScheduledUpdate()
        isActive = false
        activeEntryID = nil
        lastRequestedMarkdown = nil
        requestGeneration &+= 1
    }

    private func publishImmediately(_ request: MarkdownPreviewUpdateRequest) {
        guard accepts(request) else { return }
        document = parseDocument(request.markdown)
    }

    private func publish(_ request: MarkdownPreviewUpdateRequest) {
        guard accepts(request) else { return }
        scheduledUpdate = nil
        document = parseDocument(request.markdown)
    }

    private func accepts(_ request: MarkdownPreviewUpdateRequest) -> Bool {
        isActive
            && activeEntryID == request.entryID
            && lastRequestedMarkdown == request.markdown
            && requestGeneration == request.generation
    }

    private func cancelScheduledUpdate() {
        scheduledUpdate?.cancel()
        scheduledUpdate = nil
    }
}

struct MarkdownPreviewView: View {
    let entryID: UUID
    let markdown: String
    var accent: Color = .teal
    var maxContentWidth: CGFloat = 720
    @StateObject private var updateModel: MarkdownPreviewUpdateModel

    init(
        entryID: UUID,
        markdown: String,
        accent: Color = .teal,
        maxContentWidth: CGFloat = 720,
        scheduler: any MarkdownPreviewScheduling = TaskMarkdownPreviewScheduler()
    ) {
        self.entryID = entryID
        self.markdown = markdown
        self.accent = accent
        self.maxContentWidth = maxContentWidth
        _updateModel = StateObject(
            wrappedValue: MarkdownPreviewUpdateModel(scheduler: scheduler)
        )
    }

    var body: some View {
        let document = updateModel.document
        let shouldUseSectionGroups = document.shouldUseSectionGroups

        ScrollView {
            LazyVStack(alignment: .leading, spacing: shouldUseSectionGroups ? 14 : 12) {
                if document.blocks.isEmpty {
                    Text("暂无内容")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 60)
                } else if shouldUseSectionGroups {
                    ForEach(document.sectionGroups) { group in
                        sectionGroupView(group)
                    }
                } else {
                    ForEach(document.blocks.indices, id: \.self) { index in
                        blockView(document.blocks[index])
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(previewBackground)
        .onAppear {
            updateModel.activate(entryID: entryID, markdown: markdown)
        }
        .onChange(of: markdown) { newMarkdown in
            updateModel.update(entryID: entryID, markdown: newMarkdown)
        }
        .onChange(of: entryID) { newEntryID in
            updateModel.activate(entryID: newEntryID, markdown: markdown)
        }
        .onDisappear {
            updateModel.deactivate()
        }
    }

    private var previewBackground: some View {
        LinearGradient(
            colors: [
                accent.opacity(0.08),
                Color(.secondarySystemGroupedBackground),
                Color(.secondarySystemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func sectionGroupView(_ group: MarkdownSectionGroup) -> some View {
        if group.isIntro {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(group.blocks.indices, id: \.self) { index in
                    blockView(group.blocks[index])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "number")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)

                    Text(group.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                if group.blocks.isEmpty {
                    Text("这个小节还没有内容")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(group.blocks.indices, id: \.self) { index in
                        blockView(group.blocks[index])
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            Text(Self.inlineMarkdown(text))
                .font(font(for: level))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, level == 1 ? 2 : 8)

        case let .paragraph(text):
            Text(Self.inlineMarkdown(text))
                .font(.body)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)

        case let .quote(text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 4)

                Text(Self.inlineMarkdown(text))
                    .font(.body.italic())
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

        case let .unorderedList(items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("•")
                            .font(.body.weight(.bold))
                            .foregroundStyle(accent)
                        Text(Self.inlineMarkdown(item))
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

        case let .orderedList(items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(item.number).")
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(accent)
                            .frame(minWidth: 28, alignment: .trailing)

                        Text(Self.inlineMarkdown(item.text))
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

        case let .checklist(items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isChecked ? accent : .secondary)
                        Text(Self.inlineMarkdown(item.text))
                            .font(.body)
                            .strikethrough(item.isChecked)
                            .foregroundStyle(item.isChecked ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

        case let .code(code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.isEmpty ? " " : code)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
            )

        case .divider:
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(height: 1)
                .padding(.vertical, 8)
        }
    }

    static func inlineMarkdown(_ text: String) -> AttributedString {
        guard shouldParseInlineMarkdown(text) else {
            return AttributedString(text)
        }

        if let attributedText = try? AttributedString(markdown: text) {
            return attributedText
        }

        return AttributedString(text)
    }

    static func shouldParseInlineMarkdown(_ text: String) -> Bool {
        text.contains { character in
            switch character {
            case "*", "_", "`", "[", "]", "(", ")", "!", "<", ">", "&", "\\", "~", "|":
                return true
            default:
                return false
            }
        }
    }

    private func font(for headingLevel: Int) -> Font {
        switch headingLevel {
        case 1:
            return .title.weight(.bold)
        case 2:
            return .title3.weight(.semibold)
        default:
            return .headline
        }
    }
}
