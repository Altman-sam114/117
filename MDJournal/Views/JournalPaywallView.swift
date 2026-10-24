import StoreKit
import SwiftUI
import UIKit

struct JournalPaywallView: View {
    @EnvironmentObject private var subscriptions: JournalSubscriptionStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var managementError: String?

    private var privacyURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "JournalPrivacyPolicyURL") as? String,
              let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
        return url
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("MD Journal Pro", systemImage: "leaf")
                        .font(.caption.weight(.semibold)).foregroundStyle(JournalTheme.accent)
                    Text("让记录，走得更远。")
                        .font(.system(.largeTitle, design: .serif).weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("把一段日子的原文汇成 Markdown，或排成可保存、打印的 PDF。你的日记始终属于你。")
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 18) {
                    feature("批量 Markdown 导出", detail: "按日期与分类筛选，保留完整正文。", image: "doc.text")
                    feature("分页 PDF 日记集", detail: "自动分页，中文与长文也能从容阅读。", image: "doc.richtext")
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading).journalSurface()

                if subscriptions.isPremium {
                    Label("Pro 已启用", systemImage: "checkmark.seal")
                        .font(.headline).foregroundStyle(JournalTheme.accent)
                    if let date = subscriptions.accessExpirationDate {
                        Text("当前权益有效至 \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if subscriptions.isLoadingProducts {
                    ProgressView("正在获取 App Store 方案…").frame(maxWidth: .infinity)
                } else if subscriptions.products.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("订阅方案暂不可用").font(.headline)
                        Text("请检查网络并稍后重试。只有取得 App Store 的真实商品与价格后才能购买。")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("重新获取方案") { Task { await subscriptions.loadProducts() } }
                            .frame(minHeight: 44)
                    }
                } else {
                    ForEach(subscriptions.products, id: \.id) { product in
                        Button {
                            Task { await subscriptions.purchase(product) }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName).font(.headline)
                                    Text("\(product.displayPrice) / \(JournalSubscriptionStore.periodTitle(for: product))")
                                        .font(.subheadline)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.right")
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .foregroundStyle(JournalTheme.onAccent)
                        }
                        .buttonStyle(.borderedProminent).tint(JournalTheme.accent)
                        .disabled(subscriptions.isPurchasing || privacyURL == nil)
                    }
                }
                if privacyURL == nil {
                    Text("暂未提供有效的隐私政策链接，购买功能尚未开放。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let message = subscriptions.statusMessage {
                    Text(message).font(.footnote).accessibilityLabel("购买状态：\(message)")
                }
                if let managementError { Text(managementError).font(.footnote) }
                if subscriptions.isPurchasing { ProgressView("正在处理…") }
                VStack(alignment: .leading, spacing: 8) {
                    Button("恢复购买") { Task { await subscriptions.restorePurchases() } }
                        .disabled(subscriptions.isPurchasing).frame(minHeight: 44)
                    Button("管理订阅") { Task { await manageSubscriptions() } }
                        .frame(minHeight: 44)
                    Text("订阅会自动续订，费用由 Apple 账户收取。可随时在系统订阅设置中取消，取消后仍可使用至当前已付费期限结束。月付与年付包含相同功能。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("日常写作、预览、单篇分享与 JSON 备份始终免费；到期后也不会删除或锁住日记。")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let privacyURL { Link("隐私政策", destination: privacyURL).frame(minHeight: 44) }
                    Link("使用条款（Apple 标准 EULA）", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderless)
            }
            .padding(JournalTheme.pageInset)
            .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background { JournalBackdrop().ignoresSafeArea() }
        .navigationTitle("Pro 订阅").navigationBarTitleDisplayMode(.inline)
        .task { await subscriptions.loadProducts() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await subscriptions.refreshEntitlements() } }
        }
    }

    private func feature(_ title: String, detail: String, image: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: image).foregroundStyle(JournalTheme.accent).frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    @MainActor
    private func manageSubscriptions() async {
        #if targetEnvironment(macCatalyst)
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        await UIApplication.shared.open(url)
        #else
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            managementError = "请在系统设置的 Apple 账户中管理订阅。"
            return
        }
        do { try await AppStore.showManageSubscriptions(in: scene) }
        catch { managementError = "无法打开订阅管理：\(error.localizedDescription)" }
        #endif
        await subscriptions.refreshEntitlements()
    }
}
