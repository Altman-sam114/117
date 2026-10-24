import SwiftUI
import UniformTypeIdentifiers

struct JournalSettingsView: View {
    @ObservedObject var store: JournalStore
    @EnvironmentObject private var appLock: JournalAppLockStore
    @EnvironmentObject private var subscription: JournalSubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var isBusy = false
    @State private var exportDocument: JournalBackupDocument?
    @State private var exportName = "MDJournal-backup"
    @State private var importPreview: JournalBackupImportPreview?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("每一页，都由你掌握。", systemImage: "book.closed")
                        .font(.system(.headline, design: .serif))
                    Text("本机保存 · 原生写作 · 随时备份")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                if let failure = store.readFailureMessage {
                    Section("原文件已保护") {
                        Text(failure).font(.footnote)
                        Text("已暂停新建、修改和导入，防止覆盖尚未成功读取的日记。关闭提示不会解除保护。")
                            .foregroundStyle(.secondary)
                        Button("导出原始文件") { export(original: true) }
                            .disabled(isBusy)
                        Button("重新读取原文件") {
                            message = store.retryReadingProtectedFile()
                                ? "已成功重新读取日记，修改功能已恢复。"
                                : "仍无法读取原文件，保护保持开启。你可以先导出原文件以便恢复。"
                        }
                        .disabled(isBusy)
                    }
                }

                Section {
                    Button { export(original: false) } label: {
                        Label("导出完整 JSON 备份", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isBusy || !store.canMutate)
                    .accessibilityIdentifier("journal.backup.export")
                    Button { isImporting = true } label: {
                        Label("合并导入 JSON 备份", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isBusy || !store.canMutate)
                    .accessibilityIdentifier("journal.backup.import")
                } header: {
                    Text("免费备份与恢复")
                } footer: {
                    Text("完整备份包含日记的全部正文与元数据。单次导入上限为 25 MB、10,000 篇；超过上限的完整备份需先在电脑分批整理。导入前会显示数量，同 ID 的本机日记不会被覆盖。备份文件未经额外加密，请妥善保管。")
                }

                Section {
                    Toggle("应用锁", isOn: Binding(
                        get: { appLock.isEnabled },
                        set: { enabled in Task { await appLock.setEnabled(enabled) } }
                    ))
                    .disabled(appLock.isAuthenticating)
                    .accessibilityIdentifier("journal.app-lock.toggle")
                    if appLock.isEnabled {
                        Button("立即锁定") { appLock.lock() }
                    }
                    if let lockMessage = appLock.message {
                        Text(lockMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("本地访问保护")
                } footer: {
                    Text("使用系统设备密码或生物识别验证。进入后台后再次验证，并遮挡非活跃界面；导出文件不受应用锁保护。")
                }

                Section("更多写作方式") {
                    NavigationLink {
                        JournalPaywallView()
                    } label: {
                        Label(subscription.isPremium ? "管理高级权益" : "了解高级功能", systemImage: "sparkles")
                    }
                    NavigationLink {
                        JournalPremiumExportView(entries: store.entries)
                    } label: {
                        Label("批量 Markdown 与 PDF", systemImage: "doc.on.doc")
                    }
                    .disabled(!store.canMutate)
                }

                Section("关于与隐私") {
                    NavigationLink("隐私与数据") { JournalPrivacyView() }
                    if let url = JournalPublicLinks.support {
                        Link("联系与支持", destination: url)
                    }
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(versionText).foregroundStyle(.secondary)
                    }
                }

                if isBusy { ProgressView("正在准备文件") }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $isExporting, document: exportDocument,
                contentType: .json, defaultFilename: exportName
            ) { result in
                exportDocument = nil
                if case let .failure(error) = result, !isCancellation(error) {
                    message = "导出失败：\(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                switch result {
                case let .success(url): importFile(url)
                case let .failure(error):
                    if !isCancellation(error) { message = "无法打开备份：\(error.localizedDescription)" }
                }
            }
            .sheet(item: $importPreview) { preview in
                JournalImportPreviewView(preview: preview) {
                    try store.confirmImport(preview)
                } onResult: { count in
                    Task {
                        let result = await store.flushPendingSave()
                        if case .some(.failed) = result {
                            message = "已合并 \(count) 篇到当前日记，但写入磁盘失败。请保留应用并处理保存错误后重试。"
                        } else {
                            message = "已合并 \(count) 篇新日记；已有 ID 的日记保持原样。"
                        }
                    }
                }
            }
            .alert("数据与设置", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {
                Button("好", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
        .tint(JournalTheme.accent)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func export(original: Bool) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let data = try await (original ? store.exportOriginalDataForRecovery() : store.exportBackupData())
                exportDocument = JournalBackupDocument(data: data)
                exportName = original ? "MDJournal-original-recovery" : "MDJournal-backup"
                isExporting = true
            } catch {
                message = "无法准备导出：\(error.localizedDescription)"
            }
        }
    }

    private func importFile(_ url: URL) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let entries = try await Task.detached(priority: .userInitiated) {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    return try JournalBackupCodec.decode(JournalBackupCodec.readBoundedData(from: url))
                }.value
                importPreview = try store.prepareImport(entries)
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
    }
}

private struct JournalImportPreviewView: View {
    let preview: JournalBackupImportPreview
    let onConfirm: () throws -> Int
    let onResult: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("合并计划") {
                    LabeledContent("新增日记", value: "\(preview.newEntryCount) 篇")
                    LabeledContent("保留本机、跳过同 ID", value: "\(preview.existingEntryCount) 篇")
                    Text("不会删除或覆盖本机日记。预览后日记若变化，需要重新导入并确认。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("备份中的日记（最多显示 20 篇）") {
                    ForEach(preview.entries.prefix(20)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.displayTitle)
                            Text(entry.createdAt.journalTitleText).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("导入预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认合并") {
                        do {
                            let count = try onConfirm()
                            dismiss()
                            onResult(count)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(errorMessage != nil)
                    .accessibilityIdentifier("journal.backup.confirm")
                }
            }
        }
    }
}
