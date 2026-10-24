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
        let store = JournalSubscriptionStore(productIDs: [productID], startsAutomatically: false)
        XCTAssertFalse(store.isPremium)
        XCTAssertNil(store.accessExpirationDate)
        XCTAssertTrue(store.products.isEmpty)
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
    }

    @MainActor
    func testStoreKitUpdatesAutomaticallyApplyApprovalAndRefund() async throws {
        guard #available(iOS 17.0, *) else { return }
        let session = try session()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.askToBuyEnabled = true
        let store = JournalSubscriptionStore(startsAutomatically: true)
        let loaded = try await eventually { store.products.count == 2 && !store.isLoadingProducts }
        XCTAssertTrue(loaded, "The production startup task must load the StoreKit catalog")
        let product = try XCTUnwrap(store.products.first { $0.id == productID })
        await store.purchase(product)
        XCTAssertFalse(store.isPremium)
        let pending = try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        let approved = try await eventually { store.isPremium }
        XCTAssertTrue(approved, "Transaction.updates must enable verified approved purchases without a manual refresh")
        let purchased = try XCTUnwrap(session.allTransactions().first { !$0.pendingAskToBuyConfirmation && $0.productIdentifier == productID })
        try session.refundTransaction(identifier: purchased.identifier)
        let revoked = try await eventually { !store.isPremium }
        XCTAssertTrue(revoked, "Transaction.updates must remove refunded access without a manual refresh")
    }

    @MainActor
    func testStoreKitPurchaseRestoreAndRefundUseVerifiedTransactions() async throws {
        guard #available(iOS 17.0, *) else { return }
        let session = try session()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = JournalSubscriptionStore(startsAutomatically: false)
        await store.loadProducts()
        XCTAssertEqual(store.products.count, 2)
        let product = try XCTUnwrap(store.products.first { $0.id == productID })
        XCTAssertFalse(product.displayPrice.isEmpty)
        XCTAssertEqual(JournalSubscriptionStore.periodTitle(for: product), "每月")
        try await render(
            JournalPaywallView().environmentObject(store),
            name: "review-pro-paywall-390x844-light"
        )
        await store.purchase(product)
        XCTAssertTrue(store.isPremium)
        XCTAssertNotNil(store.accessExpirationDate)
        try await render(
            JournalPremiumExportView(entries: [
                JournalEntry(title: "河边散步", body: "### 今天的片刻\n风把树叶吹得很轻。", category: .daily),
                JournalEntry(title: "留下一个念头", body: "### 值得记住\n认真完成手边的小事。", category: .inspiration)
            ]).environmentObject(store),
            name: "review-pro-export-390x844-light-verified"
        )
        await store.restorePurchases()
        XCTAssertTrue(store.isPremium)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == productID })
        try session.refundTransaction(identifier: transaction.identifier)
        await store.refreshEntitlements()
        XCTAssertFalse(store.isPremium)
        let unavailable = JournalSubscriptionStore(productIDs: [], startsAutomatically: false)
        await unavailable.loadProducts()
        try await render(
            JournalPaywallView().environmentObject(unavailable),
            name: "review-pro-unavailable-390x844-light-accessibility3", typeSize: .accessibility3,
            scrollOffset: 700
        )
    }

    @MainActor
    func testStoreKitPendingApprovalColdStartAndExpiry() async throws {
        guard #available(iOS 17.0, *) else { return }
        let session = try session()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.askToBuyEnabled = true
        let store = JournalSubscriptionStore(startsAutomatically: false)
        await store.loadProducts()
        let product = try XCTUnwrap(store.products.first { $0.id == productID })
        await store.purchase(product)
        XCTAssertFalse(store.isPremium)
        XCTAssertTrue(store.statusMessage?.contains("等待批准") == true)
        let pending = try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        let relaunched = JournalSubscriptionStore(startsAutomatically: false)
        await relaunched.refreshEntitlements()
        XCTAssertTrue(relaunched.isPremium)
        try session.expireSubscription(productIdentifier: productID)
        await relaunched.refreshEntitlements()
        XCTAssertFalse(relaunched.isPremium)
    }

    @MainActor
    func testStoreKitCancelledAndUnverifiedPurchasesDoNotUnlockPro() async throws {
        guard #available(iOS 17.0, *) else { return }
        let session = try session()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = JournalSubscriptionStore(startsAutomatically: false)
        await store.loadProducts()
        let product = try XCTUnwrap(store.products.first { $0.id == productID })
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        await store.purchase(product)
        XCTAssertFalse(store.isPremium)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        await store.purchase(product)
        XCTAssertFalse(store.isPremium)
        XCTAssertNil(store.accessExpirationDate)
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
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    @MainActor
    private func eventually(_ condition: () -> Bool) async throws -> Bool {
        for _ in 0..<80 {
            if condition() { return true }
            try await Task.sleep(for: .milliseconds(100))
        }
        return condition()
    }

    @MainActor
    private func render<Content: View>(
        _ content: Content, name: String, typeSize: DynamicTypeSize = .large, scrollOffset: CGFloat? = nil
    ) async throws {
        let size = CGSize(width: 390, height: 844)
        let controller = UIHostingController(rootView: NavigationStack { content }
            .environment(\.colorScheme, .light)
            .environment(\.dynamicTypeSize, typeSize)
            .environment(\.locale, Locale(identifier: "zh_CN")))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
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
    }

    @MainActor
    private func scrollableContent(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height { return scroll }
        return view.subviews.lazy.compactMap { scrollableContent(in: $0) }.first
    }
}

private actor CatalogUnavailableEntitlementReader: JournalSubscriptionEntitlementReading {
    let expired: JournalSubscriptionEntitlement
    private var grace: JournalSubscriptionEntitlement
    private(set) var requestedGroups: [String] = []

    init(expired: JournalSubscriptionEntitlement, grace: JournalSubscriptionEntitlement) {
        self.expired = expired
        self.grace = grace
    }

    func currentEntitlements(for productIDs: Set<String>) -> JournalSubscriptionCurrentEntitlements {
        JournalSubscriptionCurrentEntitlements(entitlements: [expired], subscriptionGroupIDs: ["verified-group"])
    }

    func graceEntitlements(for groupID: String) -> [JournalSubscriptionEntitlement] {
        requestedGroups.append(groupID)
        return groupID == "verified-group" ? [grace] : []
    }

    func expireGrace() { grace.gracePeriodExpirationDate = Date().addingTimeInterval(-1) }
}
