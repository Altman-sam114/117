import SwiftUI
import UIKit
import XCTest
@testable import MDJournal

@MainActor
final class JournalSecurityTests: XCTestCase {
    func testCorruptFileRemainsProtectedAfterDismissAndEveryMutationEntry() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let original = Data("{ unrecoverable original bytes 📝".utf8)
        try original.write(to: fixture.file)
        let counter = SecurityWriteCounter()
        let writer = JSONJournalPersistenceWriter(storageURL: fixture.file, onWriteAttempt: { counter.increment() })
        let store = JournalStore(storageURL: fixture.file, persistenceWriter: writer)
        XCTAssertFalse(store.canMutate)
        XCTAssertNotNil(store.readFailureMessage)
        store.dismissError()
        XCTAssertNil(store.errorMessage)
        XCTAssertFalse(store.canMutate)
        XCTAssertNil(store.createEntry())
        let entry = makeEntry()
        store.update(entry)
        store.delete(entry)
        let flush = await store.flushPendingSave()
        XCTAssertNil(flush)
        XCTAssertThrowsError(try store.prepareImport([entry]))
        let forged = JournalBackupImportPreview(entries: [entry], newEntryCount: 1, existingEntryCount: 0, basedOnRevision: 0)
        XCTAssertThrowsError(try store.confirmImport(forged))
        XCTAssertEqual(store.revision, 0)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(store.bodyPresentations.isEmpty)
        XCTAssertEqual(counter.value, 0)
        XCTAssertEqual(try Data(contentsOf: fixture.file), original)
        let recovery = try await store.exportOriginalDataForRecovery()
        XCTAssertEqual(recovery, original)
        do {
            _ = try await store.exportBackupData()
            XCTFail("A protected unread file must not export an empty replacement as a valid backup")
        } catch {
            XCTAssertEqual(error as? JournalBackupError, .readProtected)
        }
    }

    func testOnlySuccessfulRetryReleasesReadProtectionAndAllowsRealCreation() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        try Data("bad json".utf8).write(to: fixture.file)
        let store = JournalStore(storageURL: fixture.file)
        store.dismissError()
        XCTAssertFalse(store.retryReadingProtectedFile())
        XCTAssertFalse(store.canMutate)
        let recoveryFile = fixture.directory.appendingPathComponent("original-for-recovery.json")
        try FileManager.default.moveItem(at: fixture.file, to: recoveryFile)
        XCTAssertFalse(store.retryReadingProtectedFile())
        XCTAssertFalse(store.canMutate)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(store.revision, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.file.path))
        XCTAssertEqual(try Data(contentsOf: recoveryFile), Data("bad json".utf8))
        let restored = makeEntry()
        try JournalBackupCodec.encode([restored]).write(to: fixture.file)
        XCTAssertTrue(store.retryReadingProtectedFile())
        XCTAssertTrue(store.canMutate)
        XCTAssertNil(store.readFailureMessage)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.entries, [restored])
        let created = try XCTUnwrap(store.createEntry())
        _ = await store.flushPendingSave()
        XCTAssertTrue(try JournalBackupCodec.decode(Data(contentsOf: fixture.file)).contains { $0.id == created })
        XCTAssertEqual(store.entry(with: restored.id), restored)
    }

    func testUnreadableDirectoryDoesNotCreateAStarterOrScheduleWrites() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let original = try JournalBackupCodec.encode([makeEntry()])
        try original.write(to: fixture.file)
        let counter = SecurityWriteCounter()
        let writer = JSONJournalPersistenceWriter(storageURL: fixture.file, onWriteAttempt: { counter.increment() })
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: fixture.directory.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fixture.directory.path)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.file.path), "Fixture must hide the inaccessible file from the Boolean existence check")
        XCTAssertThrowsError(try Data(contentsOf: fixture.file))
        let store = JournalStore(storageURL: fixture.file, persistenceWriter: writer)
        XCTAssertFalse(store.canMutate)
        XCTAssertNotNil(store.readFailureMessage)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(store.revision, 0)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fixture.directory.path)
        let flush = await store.flushPendingSave()
        XCTAssertNil(flush)
        XCTAssertEqual(counter.value, 0)
        XCTAssertEqual(try Data(contentsOf: fixture.file), original)
        XCTAssertTrue(store.retryReadingProtectedFile())
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.revision, 0)
    }

    func testMissingFileAndValidEmptyCollectionRemainWritable() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let missing = JournalStore(storageURL: fixture.file)
        XCTAssertTrue(missing.canMutate)
        XCTAssertEqual(missing.entries.count, 1)
        _ = await missing.flushPendingSave()
        try JournalBackupCodec.encode([]).write(to: fixture.file)
        let empty = JournalStore(storageURL: fixture.file)
        XCTAssertTrue(empty.canMutate)
        XCTAssertTrue(empty.entries.isEmpty)
        XCTAssertNotNil(empty.createEntry())
        _ = await empty.flushPendingSave()
    }

    func testAppLockDefaultsOffRequiresAuthenticationToEnableAndDisable() async {
        let suite = "mdjournal-security-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let authenticator = SecurityAuthenticationStub(results: [false, true, true])
        let store = JournalAppLockStore(defaults: defaults, authenticator: authenticator)
        XCTAssertFalse(store.isEnabled)
        XCTAssertFalse(store.needsPrivacyCover(sceneIsActive: false))
        await store.setEnabled(true)
        XCTAssertFalse(store.isEnabled)
        await store.setEnabled(true)
        XCTAssertTrue(store.isEnabled)
        XCTAssertTrue(defaults.bool(forKey: JournalAppLockStore.enabledDefaultsKey))
        XCTAssertEqual(store.state, .unlocked)
        XCTAssertFalse(store.needsPrivacyCover(sceneIsActive: true))
        XCTAssertTrue(store.needsPrivacyCover(sceneIsActive: false))
        store.handleScenePhase(.inactive)
        XCTAssertEqual(store.state, .unlocked, "System authentication becoming inactive must not cancel itself")
        await store.setEnabled(false)
        XCTAssertFalse(store.isEnabled)
        XCTAssertFalse(defaults.bool(forKey: JournalAppLockStore.enabledDefaultsKey))
        XCTAssertEqual(authenticator.calls, 3)
    }

    func testFailedAuthenticationKeepsEnabledDiaryCovered() async {
        let suite = "mdjournal-security-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: JournalAppLockStore.enabledDefaultsKey)
        let store = JournalAppLockStore(defaults: defaults, authenticator: SecurityAuthenticationStub(results: [false]))
        XCTAssertEqual(store.state, .locked)
        await store.unlock()
        XCTAssertEqual(store.state, .locked)
        XCTAssertTrue(store.needsPrivacyCover(sceneIsActive: true))
        XCTAssertNotNil(store.message)
    }

    func testBackgroundInvalidatesAnInFlightSuccessfulAuthentication() async {
        let suite = "mdjournal-security-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: JournalAppLockStore.enabledDefaultsKey)
        let authenticator = SuspendedSecurityAuthenticator()
        let store = JournalAppLockStore(defaults: defaults, authenticator: authenticator)
        let request = Task { await store.unlock() }
        await authenticator.waitUntilStarted(1)
        XCTAssertEqual(store.state, .authenticating)
        store.handleScenePhase(.background)
        XCTAssertTrue(authenticator.wasInvalidated)
        authenticator.complete(true)
        await request.value
        XCTAssertEqual(store.state, .locked)
        XCTAssertTrue(store.needsPrivacyCover(sceneIsActive: true))
    }

    func testBackgroundInvalidatesEnableBeforeItsLateSuccess() async {
        let suite = "mdjournal-security-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let authenticator = SuspendedSecurityAuthenticator()
        let store = JournalAppLockStore(defaults: defaults, authenticator: authenticator)
        let request = Task { await store.setEnabled(true) }
        await authenticator.waitUntilStarted(1)
        XCTAssertEqual(store.state, .authenticating)
        store.handleScenePhase(.background)
        authenticator.complete(true)
        await request.value
        XCTAssertTrue(authenticator.wasInvalidated)
        XCTAssertFalse(store.isEnabled)
        XCTAssertFalse(defaults.bool(forKey: JournalAppLockStore.enabledDefaultsKey))
        XCTAssertEqual(store.state, .unlocked)
    }

    func testStaleAuthenticationCannotReplaceANewerAuthenticationState() async {
        let suite = "mdjournal-security-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: JournalAppLockStore.enabledDefaultsKey)
        let authenticator = SuspendedSecurityAuthenticator()
        let store = JournalAppLockStore(defaults: defaults, authenticator: authenticator)
        let first = Task { await store.unlock() }
        await authenticator.waitUntilStarted(1)
        store.lock()
        let second = Task { await store.unlock() }
        await authenticator.waitUntilStarted(2)
        XCTAssertEqual(store.state, .authenticating)
        authenticator.complete(true)
        await first.value
        XCTAssertEqual(store.state, .authenticating)
        authenticator.complete(true)
        await second.value
        XCTAssertEqual(store.state, .unlocked)
    }

    func testPrivacyShieldCoversAnAlreadyPresentedSheetAtWindowLevel() async throws {
        let suite = "mdjournal-security-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: JournalAppLockStore.enabledDefaultsKey)
        let store = JournalAppLockStore(defaults: defaults, authenticator: SecurityAuthenticationStub(results: [true, true]))
        await store.unlock()
        let host = UIHostingController(rootView: JournalPrivacyGate { Text("私密正文") }
            .environmentObject(store).environment(\.scenePhase, .active))
        let window = try makeForegroundWindow(size: CGSize(width: 390, height: 844))
        let previousKeyWindow = window.windowScene?.windows.first(where: \.isKeyWindow)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        host.view.layoutIfNeeded()
        let sheet = UIViewController()
        sheet.view.backgroundColor = .systemBackground
        host.present(sheet, animated: false)
        try await Task.sleep(for: .milliseconds(100))
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        let cover = try XCTUnwrap(window.subviews.last)
        XCTAssertEqual(cover.accessibilityIdentifier, "journal.window-privacy-cover")
        XCTAssertEqual(cover.frame, window.bounds)
        XCTAssertTrue(cover.accessibilityViewIsModal)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertFalse(window.subviews.contains { $0.accessibilityIdentifier == "journal.window-privacy-cover" })

        NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: nil)
        XCTAssertFalse(window.subviews.contains { $0.accessibilityIdentifier == "journal.window-privacy-cover" }, "Only this window's scene notifications may cover it")
        let scene = try XCTUnwrap(window.windowScene)
        NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: scene)
        XCTAssertEqual(window.subviews.last?.accessibilityIdentifier, "journal.window-privacy-cover", "Scene deactivation must cover an existing sheet synchronously")
        XCTAssertEqual(store.state, .unlocked, "Inactive system authentication must not be cancelled by scene shielding")
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        XCTAssertFalse(window.subviews.contains { $0.accessibilityIdentifier == "journal.window-privacy-cover" })
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertEqual(store.state, .locked, "Backgrounding this scene must lock immediately, before SwiftUI's phase update")
        XCTAssertEqual(window.subviews.last?.accessibilityIdentifier, "journal.window-privacy-cover")
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        XCTAssertEqual(window.subviews.last?.accessibilityIdentifier, "journal.window-privacy-cover", "Activation cannot bypass owner authentication")
        await store.unlock()
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(window.subviews.contains { $0.accessibilityIdentifier == "journal.window-privacy-cover" })
        sheet.dismiss(animated: false)
    }

    func testRenderSettingsPrivacyAndLockedWindowReview() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        try JournalBackupCodec.encode([makeEntry()]).write(to: fixture.file)
        let store = JournalStore(storageURL: fixture.file)
        let subscriptions = JournalSubscriptionStore(startsAutomatically: false)
        let suite = "mdjournal-security-review-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let lock = JournalAppLockStore(defaults: defaults, authenticator: SecurityAuthenticationStub(results: []))
        let settings = JournalSettingsView(store: store)
            .environmentObject(lock).environmentObject(subscriptions)
        try await renderSecurityReview(settings, name: "settings-390x844-light")
        try await renderSecurityReview(
            settings, name: "settings-390x844-light-accessibility3", typeSize: .accessibility3
        )
        try await renderSecurityReview(
            NavigationStack { JournalPrivacyView() }, name: "privacy-390x844-light"
        )
        defaults.set(true, forKey: JournalAppLockStore.enabledDefaultsKey)
        let lockedStore = JournalAppLockStore(
            defaults: defaults, authenticator: SecurityAuthenticationStub(results: [true])
        )
        await lockedStore.unlock()
        try await renderSecurityReview(
            JournalPrivacyGate { Text("仅用于验证遮罩的私密正文") }
                .environmentObject(lockedStore).environment(\.scenePhase, .active),
            name: "lock-390x844-dark-presented-sheet", dark: true,
            lockAfterPresentingSheet: lockedStore
        )
        XCTAssertEqual(store.revision, 0)
        XCTAssertFalse(subscriptions.isPremium)
    }

    private func renderSecurityReview<Content: View>(
        _ content: Content, name: String, dark: Bool = false,
        typeSize: DynamicTypeSize = .large,
        lockAfterPresentingSheet appLock: JournalAppLockStore? = nil
    ) async throws {
        let size = CGSize(width: 390, height: 844)
        let host = UIHostingController(rootView: content
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .environment(\.dynamicTypeSize, typeSize)
            .environment(\.colorScheme, dark ? .dark : .light))
        host.overrideUserInterfaceStyle = dark ? .dark : .light
        let window = try makeForegroundWindow(size: size)
        let previousKeyWindow = window.windowScene?.windows.first(where: \.isKeyWindow)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        if let appLock {
            let sheet = UIViewController()
            sheet.view.backgroundColor = .systemBackground
            let label = UILabel()
            label.text = "此已呈现内容必须被窗口遮罩覆盖"
            label.frame = CGRect(x: 20, y: 80, width: 350, height: 100)
            sheet.view.addSubview(label)
            host.present(sheet, animated: false)
            try await Task.sleep(for: .milliseconds(100))
            appLock.lock()
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertEqual(window.subviews.last?.accessibilityIdentifier, "journal.window-privacy-cover")
            XCTAssertEqual(window.subviews.last?.frame, window.bounds)
        }
        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        var didDraw = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            didDraw = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        XCTAssertTrue(didDraw, "The foreground window must render its content and any sheet privacy cover")
        XCTAssertEqual(image.size, size)
        let attachment = XCTAttachment(image: image)
        attachment.name = "review-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeForegroundWindow(size: CGSize) throws -> UIWindow {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive },
            "Window snapshots require the test host's foreground scene"
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        return window
    }

    private func makeEntry() -> JournalEntry {
        let date = Date(timeIntervalSince1970: 100)
        return JournalEntry(title: "原日记", body: "### 内容\n安全保留", createdAt: date, updatedAt: date)
    }

    private func makeFixture() throws -> SecurityFixture {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mdjournal-security-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return SecurityFixture(directory: directory, file: directory.appendingPathComponent("entries.json"))
    }
}

private struct SecurityFixture {
    let directory: URL
    let file: URL
    func cleanup() { try? FileManager.default.removeItem(at: directory) }
}

private final class SecurityWriteCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    func increment() { lock.lock(); count += 1; lock.unlock() }
}

@MainActor
private final class SecurityAuthenticationStub: JournalOwnerAuthenticating {
    var results: [Bool]
    var calls = 0
    init(results: [Bool]) { self.results = results }
    func authenticate(reason: String) async throws -> Bool {
        calls += 1
        return results.isEmpty ? false : results.removeFirst()
    }
    func invalidate() {}
}

@MainActor
private final class SuspendedSecurityAuthenticator: JournalOwnerAuthenticating {
    private var continuations: [CheckedContinuation<Bool, Never>] = []
    private var startedRequests = 0
    private var requestWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var wasInvalidated = false
    func authenticate(reason: String) async throws -> Bool {
        startedRequests += 1
        let waiting = requestWaiters
        requestWaiters.removeAll()
        for (count, continuation) in waiting {
            if startedRequests >= count { continuation.resume() }
            else { requestWaiters.append((count, continuation)) }
        }
        return await withCheckedContinuation { continuations.append($0) }
    }
    func waitUntilStarted(_ count: Int) async {
        guard startedRequests < count else { return }
        await withCheckedContinuation { requestWaiters.append((count, $0)) }
    }
    func invalidate() { wasInvalidated = true }
    func complete(_ success: Bool) {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume(returning: success)
    }
}
