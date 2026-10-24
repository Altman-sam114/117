import LocalAuthentication
import SwiftUI

@MainActor
protocol JournalOwnerAuthenticating: AnyObject {
    func authenticate(reason: String) async throws -> Bool
    func invalidate()
}

@MainActor
final class LocalJournalOwnerAuthenticator: JournalOwnerAuthenticating {
    private var context: LAContext?

    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        self.context = context
        defer { self.context = nil }
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? NSError(
                domain: "MDJournal.Authentication", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "请先在设备设置中启用密码或可用的身份验证方式。"]
            )
        }
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }

    func invalidate() {
        context?.invalidate()
        context = nil
    }
}

@MainActor
final class JournalAppLockStore: ObservableObject {
    enum State: Equatable {
        case unlocked
        case locked
        case authenticating
    }

    static let enabledDefaultsKey = "journal.appLock.enabled"
    @Published private(set) var isEnabled: Bool
    @Published private(set) var state: State
    @Published private(set) var message: String?

    private let defaults: UserDefaults
    private let authenticator: any JournalOwnerAuthenticating
    private var authenticationGeneration: UInt64 = 0

    init(defaults: UserDefaults = .standard, authenticator: (any JournalOwnerAuthenticating)? = nil) {
        self.defaults = defaults
        self.authenticator = authenticator ?? LocalJournalOwnerAuthenticator()
        let enabled = defaults.bool(forKey: Self.enabledDefaultsKey)
        isEnabled = enabled
        state = enabled ? .locked : .unlocked
    }

    var isAuthenticating: Bool { state == .authenticating }

    func needsPrivacyCover(sceneIsActive: Bool) -> Bool {
        isEnabled && (!sceneIsActive || state != .unlocked)
    }

    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled, !isAuthenticating else { return }
        let wasEnabled = isEnabled
        guard let success = await authenticate(reason: enabled ? "验证身份，以开启日记应用锁。" : "验证身份，以关闭日记应用锁。") else { return }
        guard success else {
            state = wasEnabled ? .locked : .unlocked
            return
        }
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledDefaultsKey)
        state = .unlocked
    }

    func unlock() async {
        guard isEnabled else { state = .unlocked; return }
        guard !isAuthenticating, state != .unlocked else { return }
        guard let success = await authenticate(reason: "验证身份，以查看和编辑本机日记。") else { return }
        state = success ? .unlocked : .locked
    }

    func lock() {
        guard isEnabled || isAuthenticating else { return }
        authenticationGeneration &+= 1
        authenticator.invalidate()
        state = isEnabled ? .locked : .unlocked
        message = nil
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            lock()
        case .active:
            if isEnabled, state == .locked {
                Task { await unlock() }
            }
        case .inactive:
            // The gate covers inactive scenes without cancelling the system authentication prompt.
            break
        @unknown default:
            lock()
        }
    }

    private func authenticate(reason: String) async -> Bool? {
        authenticationGeneration &+= 1
        let generation = authenticationGeneration
        message = nil
        state = .authenticating
        do {
            let success = try await authenticator.authenticate(reason: reason)
            guard generation == authenticationGeneration else { return nil }
            if !success { message = "身份验证未完成，请重试。" }
            return success
        } catch {
            guard generation == authenticationGeneration else { return nil }
            message = "无法完成身份验证：\(error.localizedDescription)"
            return false
        }
    }
}
