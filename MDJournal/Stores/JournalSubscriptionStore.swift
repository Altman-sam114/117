import Combine
import Foundation
import StoreKit

struct JournalSubscriptionEntitlement: Equatable, Sendable {
    let productID: String
    let isVerified: Bool
    let expirationDate: Date?
    let revocationDate: Date?
    let isUpgraded: Bool
    var gracePeriodExpirationDate: Date? = nil

    func grantsAccess(productIDs: Set<String>, now: Date) -> Bool {
        guard isVerified, productIDs.contains(productID), revocationDate == nil, !isUpgraded else {
            return false
        }
        return accessExpirationDate.map { $0 > now } ?? false
    }

    var accessExpirationDate: Date? {
        switch (expirationDate, gracePeriodExpirationDate) {
        case let (expiration?, grace?): return max(expiration, grace)
        case let (expiration?, nil): return expiration
        case let (nil, grace?): return grace
        case (nil, nil): return nil
        }
    }
}

struct JournalSubscriptionCurrentEntitlements: Sendable {
    let entitlements: [JournalSubscriptionEntitlement]
    let subscriptionGroupIDs: Set<String>
}

struct JournalSubscriptionGroupEntitlements: Sendable {
    let activeEntitlements: [JournalSubscriptionEntitlement]
    let inactiveProductIDs: Set<String>
}

protocol JournalSubscriptionEntitlementReading: Sendable {
    func currentEntitlements(for productIDs: Set<String>) async -> JournalSubscriptionCurrentEntitlements
    func groupEntitlements(for groupID: String) async -> JournalSubscriptionGroupEntitlements
}

struct JournalStoreKitEntitlementReader: JournalSubscriptionEntitlementReading {
    func currentEntitlements(for productIDs: Set<String>) async -> JournalSubscriptionCurrentEntitlements {
        var entitlements: [JournalSubscriptionEntitlement] = []
        var groups: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productType == .autoRenewable,
                  productIDs.contains(transaction.productID) else { continue }
            entitlements.append(Self.entitlement(from: transaction))
            if let group = transaction.subscriptionGroupID { groups.insert(group) }
        }
        return JournalSubscriptionCurrentEntitlements(entitlements: entitlements, subscriptionGroupIDs: groups)
    }

    func groupEntitlements(for groupID: String) async -> JournalSubscriptionGroupEntitlements {
        guard let statuses = try? await Product.SubscriptionInfo.status(for: groupID) else {
            return JournalSubscriptionGroupEntitlements(activeEntitlements: [], inactiveProductIDs: [])
        }
        var active: [JournalSubscriptionEntitlement] = []
        var inactive: Set<String> = []
        for status in statuses {
            guard case let .verified(transaction) = status.transaction,
                  transaction.productType == .autoRenewable,
                  transaction.subscriptionGroupID == groupID else { continue }
            var candidate = Self.entitlement(from: transaction)
            if status.state == .subscribed {
                active.append(candidate)
            } else if status.state == .inGracePeriod,
                      case let .verified(renewal) = status.renewalInfo {
                candidate.gracePeriodExpirationDate = renewal.gracePeriodExpirationDate
                active.append(candidate)
            } else {
                inactive.insert(transaction.productID)
            }
        }
        return JournalSubscriptionGroupEntitlements(activeEntitlements: active, inactiveProductIDs: inactive)
    }

    private static func entitlement(from transaction: Transaction) -> JournalSubscriptionEntitlement {
        JournalSubscriptionEntitlement(
            productID: transaction.productID, isVerified: true,
            expirationDate: transaction.expirationDate, revocationDate: transaction.revocationDate,
            isUpgraded: transaction.isUpgraded
        )
    }
}

@MainActor
final class JournalSubscriptionStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var accessExpirationDate: Date?

    let productIDs: Set<String>
    private let entitlementReader: any JournalSubscriptionEntitlementReading
    private var hasLoadedProducts = false
    private var updatesTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?
    private var productTask: Task<Void, Never>?
    private var expirationTask: Task<Void, Never>?
    private var refreshGeneration = 0

    static let defaultProductIDs: Set<String> = [
        "com.codex.mdjournal.pro.monthly", "com.codex.mdjournal.pro.yearly"
    ]

    init(
        productIDs: Set<String>? = nil, startsAutomatically: Bool = true,
        entitlementReader: any JournalSubscriptionEntitlementReading = JournalStoreKitEntitlementReader()
    ) {
        let configured = Bundle.main.object(forInfoDictionaryKey: "JournalSubscriptionProductIDs") as? [String]
        self.productIDs = productIDs ?? configured.map(Set.init) ?? Self.defaultProductIDs
        self.entitlementReader = entitlementReader
        guard startsAutomatically else { return }

        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case let .verified(transaction) = result, self.productIDs.contains(transaction.productID) {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
        startupTask = Task { [weak self] in
            await self?.refreshEntitlements()
        }
        productTask = Task { [weak self] in
            await self?.loadProducts()
        }
    }

    deinit {
        updatesTask?.cancel()
        startupTask?.cancel()
        productTask?.cancel()
        expirationTask?.cancel()
    }

    func loadProducts(forceRefresh: Bool = false) async {
        guard !isLoadingProducts, forceRefresh || !hasLoadedProducts else { return }
        isLoadingProducts = true
        do {
            products = try await Product.products(for: productIDs)
                .filter { $0.type == .autoRenewable && Self.supportedPeriod($0) }
                .sorted { ($0.subscription?.subscriptionPeriod.unit == .month ? 0 : 1)
                    < ($1.subscription?.subscriptionPeriod.unit == .month ? 0 : 1) }
            statusMessage = products.isEmpty ? "暂时无法取得订阅方案，请稍后重试。" : nil
        } catch {
            statusMessage = "无法连接 App Store：\(error.localizedDescription)"
        }
        hasLoadedProducts = true
        isLoadingProducts = false
        await refreshEntitlements()
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing, productIDs.contains(product.id),
              products.contains(where: { $0.id == product.id }) else { return }
        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case let .success(result):
                switch result {
                case let .verified(transaction):
                    guard productIDs.contains(transaction.productID), transaction.productType == .autoRenewable else {
                        statusMessage = "这笔交易不属于当前订阅方案。"
                        return
                    }
                    await transaction.finish()
                    await refreshEntitlements()
                    statusMessage = isPremium ? "订阅已生效，感谢支持。" : "交易已完成，正在等待有效订阅权益。"
                case .unverified:
                    statusMessage = "无法验证这笔交易，暂未启用 Pro。请恢复购买或联系 Apple 支持。"
                    await refreshEntitlements()
                }
            case .pending:
                statusMessage = "购买正在等待批准，获批后会自动更新权益。"
            case .userCancelled:
                break
            @unknown default:
                statusMessage = "购买尚未完成，请稍后重试。"
            }
        } catch StoreKitError.userCancelled {
            statusMessage = nil
        } catch {
            statusMessage = "购买未完成：\(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = isPremium ? "已恢复有效订阅。" : "此 Apple 账户目前没有有效的 Pro 订阅。"
        } catch {
            statusMessage = "恢复购买未完成：\(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        let current = await entitlementReader.currentEntitlements(for: productIDs)
        var candidates = current.entitlements
        // Current entitlements include billing grace periods; catalog groups alone do not imply access.
        let groups = current.subscriptionGroupIDs
        for group in groups {
            let state = await entitlementReader.groupEntitlements(for: group)
            // A terminal status for a verified transaction overrides the older cached entitlement.
            candidates.removeAll { state.inactiveProductIDs.contains($0.productID) }
            candidates.append(contentsOf: state.activeEntitlements)
        }
        guard generation == refreshGeneration, !Task.isCancelled else { return }
        let now = Date()
        accessExpirationDate = candidates
            .filter { $0.grantsAccess(productIDs: productIDs, now: now) }
            .compactMap(\.accessExpirationDate).max()
        isPremium = accessExpirationDate != nil
        scheduleExpirationRefresh()
    }

    static func periodTitle(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "订阅" }
        switch period.unit {
        case .month: return period.value == 1 ? "每月" : "每 \(period.value) 个月"
        case .year: return period.value == 1 ? "每年" : "每 \(period.value) 年"
        case .week: return "每 \(period.value) 周"
        case .day: return "每 \(period.value) 天"
        @unknown default: return "订阅"
        }
    }

    private static func supportedPeriod(_ product: Product) -> Bool {
        guard let period = product.subscription?.subscriptionPeriod else { return false }
        return period.value == 1 && (period.unit == .month || period.unit == .year)
    }

    private func scheduleExpirationRefresh() {
        expirationTask?.cancel()
        guard let accessExpirationDate else { return }
        let delay = max(0.1, min(accessExpirationDate.timeIntervalSinceNow + 0.1, 86400))
        expirationTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            await self?.refreshEntitlements()
        }
    }
}
