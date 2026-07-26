import Foundation

struct JournalPersistenceSnapshot: Sendable, Equatable {
    let revision: UInt64
    let entries: [JournalEntry]
}

enum JournalPersistenceResult: Sendable, Equatable {
    case written(revision: UInt64)
    case alreadyDurable(revision: UInt64)
    case rejectedStale(revision: UInt64, highestAcceptedRevision: UInt64)
    case failed(revision: UInt64, message: String)

    var revision: UInt64 {
        switch self {
        case let .written(revision),
             let .alreadyDurable(revision),
             let .rejectedStale(revision, _),
             let .failed(revision, _):
            revision
        }
    }
}

protocol JournalPersistenceWriting: Sendable {
    func persist(_ snapshot: JournalPersistenceSnapshot) async -> JournalPersistenceResult
}

actor JSONJournalPersistenceWriter: JournalPersistenceWriting {
    private let storageURL: URL
    private let onWriteAttempt: @Sendable () -> Void
    private var highestAcceptedRevision: UInt64?
    private var durableRevision: UInt64?

    init(
        storageURL: URL,
        onWriteAttempt: @escaping @Sendable () -> Void = {}
    ) {
        self.storageURL = storageURL
        self.onWriteAttempt = onWriteAttempt
    }

    func persist(_ snapshot: JournalPersistenceSnapshot) async -> JournalPersistenceResult {
        if let highestAcceptedRevision, snapshot.revision < highestAcceptedRevision {
            return .rejectedStale(
                revision: snapshot.revision,
                highestAcceptedRevision: highestAcceptedRevision
            )
        }

        highestAcceptedRevision = snapshot.revision

        if durableRevision == snapshot.revision {
            return .alreadyDurable(revision: snapshot.revision)
        }

        do {
            onWriteAttempt()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot.entries)
            try data.write(to: storageURL, options: [.atomic])
            durableRevision = snapshot.revision
            return .written(revision: snapshot.revision)
        } catch {
            return .failed(revision: snapshot.revision, message: error.localizedDescription)
        }
    }
}

struct JournalScheduledSave: Sendable {
    private let cancellation: @MainActor @Sendable () -> Void

    init(cancellation: @escaping @MainActor @Sendable () -> Void) {
        self.cancellation = cancellation
    }

    @MainActor
    func cancel() {
        cancellation()
    }
}

protocol JournalSaveScheduling: Sendable {
    @MainActor
    func schedule(
        after delay: Duration,
        operation: @escaping @MainActor @Sendable () async -> Void
    ) -> JournalScheduledSave
}

struct TaskJournalSaveScheduler: JournalSaveScheduling {
    @MainActor
    func schedule(
        after delay: Duration,
        operation: @escaping @MainActor @Sendable () async -> Void
    ) -> JournalScheduledSave {
        let task = Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await operation()
        }

        return JournalScheduledSave {
            task.cancel()
        }
    }
}
