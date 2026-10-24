import StoreKit
import StoreKitTest
import SwiftUI
import UIKit
import XCTest
@testable import MDJournal

final class JournalSubscriptionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let productID = "com.codex.mdjournal.pro.monthly"

    func testEntitlementRequiresVerificationAndKnownProduct() {
        let known: Set<String> = [productID]
        XCTAssertTrue(entitlement().grantsAccess(productIDs: known, now: now))
        XCTAssertFalse(entitlement(isVerified: false).grantsAccess(productIDs: known, now: now))
        XCTAssertFalse(entitlement().grantsAccess(productIDs: ["other.product"], now: now))
    }

    func testEntitlementExpiresAtBoundaryAndMissingExpiryIsNotLifetimeAccess() {
        let known: Set<String> = [productID]
        XCTAssertFalse(entitlement(expiration: now).grantsAccess(productIDs: known, now: now))
        XCTAssertFalse(entitlement(expiration: now.addingTimeInterval(-1)).grantsAccess(productIDs: known, now: now))
        let missing = JournalSubscriptionEntitlement(
            productID: productID, isVerified: true, expirationDate: nil, revocationDate: nil, isUpgraded: false
        )
        XCTAssertFalse(missing.grantsAccess(productIDs: known, now: now))
    }

    func testRevokedAndUpgradedTransactionsNeverGrantAccess() {
        let known: Set<String> = [productID]
        XCTAssertFalse(entitlement(revocation: now).grantsAccess(productIDs: known, now: now))
        XCTAssertFalse(entitlement(isUpgraded: true).grantsAccess(productIDs: known, now: now))
    }

    func testGracePeriodHasFiniteVerifiedAccessAndCannotOverrideRevocation() {
        let known: Set<String> = [productID]
        var value = entitlement(expiration: now.addingTimeInterval(-60))
        value.gracePeriodExpirationDate = now.addingTimeInterval(60)
        XCTAssertTrue(value.grantsAccess(productIDs: known, now: now))
        XCTAssertFalse(value.grantsAccess(productIDs: known, now: now.addingTimeInterval(60)))
        var revoked = entitlement(expiration: now.addingTimeInterval(-60), revocation: now)
        revoked.gracePeriodExpirationDate = now.addingTimeInterval(60)
        XCTAssertFalse(revoked.grantsAccess(productIDs: known, now: now))
        var unverified = entitlement(isVerified: false, expiration: now.addingTimeInterval(-60))
        unverified.gracePeriodExpirationDate = now.addingTimeInterval(60)
        XCTAssertFalse(unverified.grantsAccess(productIDs: known, now: now))
    }

    @MainActor
    func testNewStoreDoesNotTrustStoredOrDebugPremiumFlags() {
        let store = JournalSubscriptionStore(startsAutomatically: false)
        XCTAssertFalse(store.isPremium)
        XCTAssertNil(store.accessExpirationDate)
        XCTAssertTrue(store.products.isEmpty)
        for key in ["JournalPrivacyPolicyURL", "JournalSupportURL"] {
            let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
            let url = value.flatMap(URL.init(string:))
            XCTAssertEqual(url?.scheme, "https", "The shipped app must include a valid \(key)")
            XCTAssertNotNil(url?.host)
        }
        let configured = Bundle.main.object(forInfoDictionaryKey: "JournalSubscriptionProductIDs") as? [String]
        XCTAssertEqual(Set(configured ?? []), JournalSubscriptionStore.defaultProductIDs)
        XCTAssertEqual(store.productIDs, JournalSubscriptionStore.defaultProductIDs)
    }

    @MainActor
    func testColdStartGraceRefreshQueriesVerifiedGroupWithoutProductCatalog() async {
        let expired = entitlement(expiration: Date().addingTimeInterval(-60))
        var grace = expired
        grace.gracePeriodExpirationDate = Date().addingTimeInterval(3600)
        let reader = CatalogUnavailableEntitlementReader(expired: expired, grace: grace)
        let store = JournalSubscriptionStore(
            productIDs: [productID], startsAutomatically: false, entitlementReader: reader
        )
        XCTAssertTrue(store.products.isEmpty)
        await store.refreshEntitlements()
        XCTAssertTrue(store.isPremium)
        XCTAssertEqual(store.accessExpirationDate, grace.gracePeriodExpirationDate)
        let groups = await reader.requestedGroups
        XCTAssertEqual(groups, ["verified-group"])
        await reader.expireGrace()
        await store.refreshEntitlements()
        XCTAssertFalse(store.isPremium)
        XCTAssertNil(store.accessExpirationDate)
        let staleFuture = entitlement(expiration: Date().addingTimeInterval(3600))
        await reader.setExpiredStatusWithStaleTransaction(staleFuture)
        await store.refreshEntitlements()
        XCTAssertFalse(store.isPremium, "An expired group status must override a cached transaction with an old future expiry")
    }

    @MainActor
    func testStoreKitUpdatesAutomaticallyApplyApprovalAndRefund() async throws {
        guard #available(iOS 17.0, *) else { return }
        let session = try session()
        defer { reset(session) }
        session.askToBuyEnabled = true
        let store = tracedStore(startsAutomatically: true)
        let loaded = try await step("wait for startup catalog") {
            try await eventually { store.products.count == 2 && !store.isLoadingProducts }
        }
        XCTAssertTrue(loaded, "The production startup task must load the StoreKit catalog")
        let product = try XCTUnwrap(store.products.first { $0.id == productID })
        await step("purchase pending subscription") { await store.purchase(product) }
        XCTAssertFalse(store.isPremium)
        let pending = try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
        trace("approve ask-to-buy: begin")
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        trace("approve ask-to-buy: complete")
        let approved = try await step("wait for verified approval update") {
            try await eventually { store.isPremium }
        }
        XCTAssertTrue(approved, "Transaction.updates must enable verified approved purchases without a manual refresh")
        let purchased = try XCTUnwrap(session.allTransactions().first { !$0.pendingAskToBuyConfirmation && $0.productIdentifier == productID })
        trace("refund approved transaction: begin")
        try session.refundTransaction(identifier: purchased.identifier)
        trace("refund approved transaction: complete")
        let revoked = try await step("wait for revoked transaction update") {
            try await eventually { !store.isPremium }
        }
        XCTAssertTrue(revoked, "Transaction.updates must remove refunded access without a manual refresh")
    }

    @MainActor
    func testStoreKitPurchaseRestoreAndRefundUseVerifiedTransactions() async throws {
        guard #available(iOS 17.0, *) else { return }
        let session = try session()
        defer { reset(session) }
        let store = tracedStore()
        await step("load catalog and refresh entitlements") { await store.loadProducts() }
        XCTAssertEqual(store.products.count, 2)
        let product = try XCTUnwrap(store.products.first { $0.id == productID })
        XCTAssertFalse(product.displayPrice.isEmpty)
        XCTAssertEqual(JournalSubscriptionStore.periodTitle(for: product), "每月")
        try await render(
            JournalPaywallView().environmentObject(store),
            name: "review-pro-paywall-390x844-light",
            isReady: { !store.isLoadingProducts && store.products.count == 2 }
        )
        await step("purchase verified subscription") { await store.purchase(product) }
        XCTAssertTrue(store.isPremium)
        XCTAssertNotNil(store.accessExpirationDate)
        try await render(
            JournalPremiumExportView(entries: [
                JournalEntry(title: "河边散步", body: "### 今天的片刻\n风把树叶吹得很轻。", category: .daily),
                JournalEntry(title: "留下一个念头", body: "### 值得记住\n认真完成手边的小事。", category: .inspiration)
            ]).environmentObject(store),
            name: "review-pro-export-390x844-light-verified",
            isReady: { store.isPremium }
        )
        await step("restore verified subscription") { await store.restorePurchases() }
        XCTAssertTrue(store.isPremium)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == productID })
        trace("refund transaction: begin")
        try session.refundTransaction(identifier: transaction.identifier)
        trace("refund transaction: complete")
        let revoked = try await step("wait for verified refund revocation") {
            try await eventually {
                await store.refreshEntitlements()
                return !store.isPremium && store.accessExpirationDate == nil
            }
        }
        XCTAssertTrue(revoked, "The refunded StoreKit transaction must lose verified access after status propagation")
        XCTAssertFalse(store.isPremium)
        XCTAssertNil(store.accessExpirationDate)
        let unavailable = JournalSubscriptionStore(productIDs: [], startsAutomatically: false)
        await unavailable.loadProducts()
        try await render(
            JournalPaywallView().environmentObject(unavailable),
            name: "review-pro-unavailable-390x844-light-accessibility3", typeSize: .accessibility3,
            scrollOffset: 700, isReady: { !unavailable.isLoadingProducts && unavailable.products.isEmpty }
        )
    }

    @MainActor
    func testStoreKitPendingApprovalColdStartAndExpiry() async throws {
        guard #available(iOS 17.0, *) else { return }
        let session = try session()
        defer { reset(session) }
        session.askToBuyEnabled = true
        let store = tracedStore()
        await step("load catalog and refresh entitlements") { await store.loadProducts() }
        let product = try XCTUnwrap(store.products.first { $0.id == productID })
        await step("purchase pending subscription") { await store.purchase(product) }
        XCTAssertFalse(store.isPremium)
        XCTAssertTrue(store.statusMessage?.contains("等待批准") == true)
        let pending = try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
        trace("approve ask-to-buy: begin")
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        trace("approve ask-to-buy: complete")
        let relaunched = tracedStore()
        let approved = try await step("wait for cold-start verified approval") {
            try await eventually {
                await relaunched.refreshEntitlements()
                return relaunched.isPremium && relaunched.accessExpirationDate != nil
            }
        }
        XCTAssertTrue(approved, "The approved StoreKit transaction must reach the cold-start entitlement reader")
        guard approved else { return }
        XCTAssertTrue(relaunched.isPremium)
        XCTAssertNotNil(relaunched.accessExpirationDate)
        trace("expire subscription: begin")
        try session.expireSubscription(productIdentifier: productID)
        trace("expire subscription: complete")
        let expired = try await step("wait for expired subscription status") {
            try await eventually {
                await relaunched.refreshEntitlements()
                return !relaunched.isPremium
            }
        }
        XCTAssertTrue(expired, "The expired StoreKit subscription must lose access after status propagation")
    }

    @MainActor
    func testStoreKitCancelledAndUnverifiedPurchasesDoNotUnlockPro() async throws {
        guard #available(iOS 17.0, *) else { return }
        let session = try session()
        defer { reset(session) }
        let store = tracedStore()
        await step("load catalog and refresh entitlements") { await store.loadProducts() }
        XCTAssertEqual(store.products.count, 2)
        let product = try XCTUnwrap(store.products.first { $0.id == productID })
        try await step("inject purchase cancellation") {
            try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        }
        let cancellation = await step("read purchase cancellation injection") {
            await session.simulatedError(forAPI: .purchase)
        }
        XCTAssertEqual(cancellation, .generic(.userCancelled))
        await step("purchase with cancellation") { await store.purchase(product) }
        XCTAssertFalse(store.isPremium)
        XCTAssertFalse(store.isPurchasing)
        XCTAssertNil(store.statusMessage, "A purchase error must not count as a successfully handled cancellation")
        try await step("clear purchase cancellation injection") {
            try await session.setSimulatedError(nil, forAPI: .purchase)
        }
        let purchaseError = await step("read cleared purchase injection") {
            await session.simulatedError(forAPI: .purchase)
        }
        XCTAssertNil(purchaseError)
        await step("purchase verified transaction before signature failure") { await store.purchase(product) }
        let verified = await step("read verified transaction before signature failure") {
            await Transaction.latest(for: productID)
        }
        guard case let .verified(purchased)? = verified else {
            XCTFail("The real StoreKit purchase must produce a verified transaction before injecting its signature failure")
            return
        }
        XCTAssertEqual(purchased.productID, productID)
        XCTAssertTrue(store.isPremium)
        XCTAssertNotNil(store.accessExpirationDate)
        guard store.isPremium && store.accessExpirationDate != nil else { return }
        try await step("inject transaction verification failure") {
            try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        }
        let verification = await step("read verification failure injection") {
            await session.simulatedError(forAPI: .verification)
        }
        XCTAssertEqual(verification, .verification(.invalidSignature))
        let latest = await step("read latest transaction with invalid signature") {
            await Transaction.latest(for: productID)
        }
        guard assertInvalidSignatureTransaction(latest, source: "Transaction.latest") else { return }
        let current: VerificationResult<StoreKit.Transaction>? = await step("read current transaction with invalid signature") {
            for await result in Transaction.currentEntitlements {
                switch result {
                case let .verified(transaction), let .unverified(transaction, _):
                    if transaction.productID == productID { return result }
                }
            }
            return nil
        }
        guard assertInvalidSignatureTransaction(current, source: "Transaction.currentEntitlements") else { return }
        await step("refresh entitlement with invalid transaction signature") { await store.refreshEntitlements() }
        XCTAssertFalse(store.isPremium)
        XCTAssertFalse(store.isPurchasing)
        XCTAssertNil(store.accessExpirationDate)
    }

    private func assertInvalidSignatureTransaction(
        _ result: VerificationResult<StoreKit.Transaction>?, source: String
    ) -> Bool {
        guard case let .unverified(transaction, error)? = result else {
            XCTFail("\(source) must return the real purchased transaction as unverified")
            return false
        }
        XCTAssertEqual(transaction.productID, productID)
        guard case .invalidSignature = error else {
            XCTFail("\(source) must report the injected invalid signature, got \(error)")
            return false
        }
        return transaction.productID == productID
    }

    private func entitlement(
        isVerified: Bool = true, expiration: Date? = nil,
        revocation: Date? = nil, isUpgraded: Bool = false
    ) -> JournalSubscriptionEntitlement {
        JournalSubscriptionEntitlement(
            productID: productID, isVerified: isVerified,
            expirationDate: expiration ?? now.addingTimeInterval(3600),
            revocationDate: revocation, isUpgraded: isUpgraded
        )
    }

    private func session() throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "JournalSubscriptions", withExtension: "storekit"))
        trace("create StoreKit test session: begin")
        let session = try SKTestSession(contentsOf: url)
        trace("create StoreKit test session: complete")
        trace("reset session defaults: begin")
        session.resetToDefaultState()
        trace("reset session defaults: complete")
        trace("disable purchase dialogs: begin")
        session.disableDialogs = true
        trace("disable purchase dialogs: complete")
        trace("clear initial transactions: begin")
        session.clearTransactions()
        trace("clear initial transactions: complete")
        trace("check initial session configuration: begin")
        XCTAssertTrue(session.disableDialogs)
        XCTAssertFalse(session.askToBuyEnabled)
        XCTAssertFalse(session.interruptedPurchasesEnabled)
        trace("check initial session configuration: complete")
        return session
    }

    private func reset(_ session: SKTestSession) {
        trace("cleanup clear transactions: begin")
        session.clearTransactions()
        trace("cleanup clear transactions: complete")
        trace("cleanup reset defaults: begin")
        session.resetToDefaultState()
        trace("cleanup reset defaults: complete")
    }

    @MainActor
    private func tracedStore(startsAutomatically: Bool = false) -> JournalSubscriptionStore {
        JournalSubscriptionStore(
            startsAutomatically: startsAutomatically,
            entitlementReader: TracedStoreKitEntitlementReader(testName: name)
        )
    }

    @MainActor
    private func step<Value>(_ label: String, _ operation: () async throws -> Value) async rethrows -> Value {
        trace("\(label): begin")
        do {
            let value = try await operation()
            trace("\(label): complete")
            return value
        } catch {
            trace("\(label): failed: \(error)")
            throw error
        }
    }

    private func trace(_ phase: String) {
        journalStoreKitTrace(testName: name, phase: phase)
    }

    @MainActor
    private func eventually(_ condition: () async -> Bool) async throws -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(30))
        while clock.now < deadline {
            if await condition() { return true }
            try await Task.sleep(for: .milliseconds(100))
        }
        return await condition()
    }

    @MainActor
    private func render<Content: View>(
        _ content: Content, name: String, typeSize: DynamicTypeSize = .large, scrollOffset: CGFloat? = nil,
        isReady: () -> Bool = { true }
    ) async throws {
        trace("render \(name): begin")
        let size = CGSize(width: 390, height: 844)
        let controller = UIHostingController(rootView: NavigationStack { content }
            .environment(\.colorScheme, .light)
            .environment(\.dynamicTypeSize, typeSize)
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .tint(JournalTheme.accent))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        let ready = try await eventually { isReady() }
        XCTAssertTrue(ready, "Review images must capture the resolved StoreKit state")
        controller.view.layoutIfNeeded()
        if let scrollOffset {
            let scrollView = try XCTUnwrap(scrollableContent(in: controller.view))
            scrollView.setContentOffset(CGPoint(
                x: 0, y: min(scrollOffset, max(0, scrollView.contentSize.height - scrollView.bounds.height))
            ), animated: false)
            try await Task.sleep(for: .milliseconds(100))
            controller.view.layoutIfNeeded()
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        var didDraw = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            didDraw = controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        XCTAssertTrue(didDraw)
        XCTAssertEqual(image.size, size)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        trace("render \(name): complete")
    }

    @MainActor
    private func scrollableContent(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height { return scroll }
        return view.subviews.lazy.compactMap { self.scrollableContent(in: $0) }.first
    }
}

private struct TracedStoreKitEntitlementReader: JournalSubscriptionEntitlementReading {
    let testName: String
    private let reader = JournalStoreKitEntitlementReader()

    func currentEntitlements(for productIDs: Set<String>) async -> JournalSubscriptionCurrentEntitlements {
        journalStoreKitTrace(testName: testName, phase: "Transaction.currentEntitlements: begin")
        let result = await reader.currentEntitlements(for: productIDs)
        journalStoreKitTrace(testName: testName, phase: "Transaction.currentEntitlements: complete, count=\(result.entitlements.count)")
        return result
    }

    func groupEntitlements(for groupID: String) async -> JournalSubscriptionGroupEntitlements {
        journalStoreKitTrace(testName: testName, phase: "Product.SubscriptionInfo.status: begin, group=\(groupID)")
        let result = await reader.groupEntitlements(for: groupID)
        journalStoreKitTrace(testName: testName, phase: "Product.SubscriptionInfo.status: complete, active=\(result.activeEntitlements.count), inactive=\(result.inactiveProductIDs.count)")
        return result
    }
}

private func journalStoreKitTrace(testName: String, phase: String) {
    // Write immediately so a killed runner still leaves the last entered StoreKit phase.
    let line = "[StoreKitTest pid=\(ProcessInfo.processInfo.processIdentifier)] \(testName): \(phase)\n"
    FileHandle.standardOutput.write(Data(line.utf8))
}

private actor CatalogUnavailableEntitlementReader: JournalSubscriptionEntitlementReading {
    private var expired: JournalSubscriptionEntitlement
    private var grace: JournalSubscriptionEntitlement
    private var isTerminal = false
    private(set) var requestedGroups: [String] = []

    init(expired: JournalSubscriptionEntitlement, grace: JournalSubscriptionEntitlement) {
        self.expired = expired
        self.grace = grace
    }

    func currentEntitlements(for productIDs: Set<String>) -> JournalSubscriptionCurrentEntitlements {
        JournalSubscriptionCurrentEntitlements(entitlements: [expired], subscriptionGroupIDs: ["verified-group"])
    }

    func groupEntitlements(for groupID: String) -> JournalSubscriptionGroupEntitlements {
        requestedGroups.append(groupID)
        return JournalSubscriptionGroupEntitlements(
            activeEntitlements: groupID == "verified-group" && !isTerminal ? [grace] : [],
            inactiveProductIDs: isTerminal ? [expired.productID] : []
        )
    }

    func expireGrace() { grace.gracePeriodExpirationDate = Date().addingTimeInterval(-1) }

    func setExpiredStatusWithStaleTransaction(_ transaction: JournalSubscriptionEntitlement) {
        expired = transaction
        isTerminal = true
    }
}
