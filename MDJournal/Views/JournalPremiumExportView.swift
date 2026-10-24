import SwiftUI

struct JournalPremiumExportView: View {
    let entries: [JournalEntry]
    @EnvironmentObject private var subscriptions: JournalSubscriptionStore
    @Environment(\.calendar) private var calendar
    @State private var filtersDates = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var selectedCategory: JournalEntry.Category?
    @State private var format = JournalPremiumExportFormat.markdown
    @State private var document: JournalPremiumExportDocument?
    @State private var isExporting = false
    @State private var isPreparing = false
    @State private var message: String?
    @State private var preparationTask: Task<Void, Never>?

    private var selectedEntries: [JournalEntry] {
        JournalPremiumExportSelection(
            startDate: filtersDates ? startDate : nil,
            endDate: filtersDates ? endDate : nil,
            category: selectedCategory
        ).entries(from: entries, calendar: calendar)
    }

    var body: some View {
        Form {
            Section {
                Text("把记录整理成册")
                    .font(.system(.title2, design: .serif).weight(.medium))
                Text("Markdown 保留原始标记，方便继续编辑；PDF 会保留原文并自动分页，方便阅读和打印。导出文件包含私人日记，请选择可信的位置。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if subscriptions.isPremium {
                Section("选择日记") {
                    Toggle("按日期筛选", isOn: $filtersDates)
                    if filtersDates {
                        DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                        DatePicker("结束日期", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                    Picker("分类", selection: $selectedCategory) {
                        Text("全部分类").tag(nil as JournalEntry.Category?)
                        ForEach(JournalEntry.Category.allCases) { category in
                            Text(category.rawValue).tag(Optional(category))
                        }
                    }
                    Text("已选择 \(selectedEntries.count) 篇日记，按日期从早到晚排列。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("文件格式") {
                    Picker("导出格式", selection: $format) {
                        ForEach(JournalPremiumExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    Button(action: prepareExport) {
                        HStack {
                            Label("生成导出文件", systemImage: "square.and.arrow.up")
                            if isPreparing { Spacer(); ProgressView() }
                        }
                        .frame(minHeight: 44)
                    }
                    .disabled(isPreparing || selectedEntries.isEmpty)
                }
            } else {
                Section {
                    NavigationLink { JournalPaywallView() } label: {
                        Label("了解 Pro 与导出功能", systemImage: "leaf")
                    }
                    Text("日常写作、单篇分享与 JSON 备份保持免费。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let message {
                Section { Text(message).font(.footnote).accessibilityLabel("导出状态：\(message)") }
            }
        }
        .scrollContentBackground(.hidden)
        .background { JournalBackdrop().ignoresSafeArea() }
        .navigationTitle("日记集导出").navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isExporting, document: document, contentType: format.contentType,
            defaultFilename: "MD-Journal"
        ) { result in
            switch result {
            case .success: message = "日记集已导出。"
            case let .failure(error):
                if (error as NSError).code != NSUserCancelledError { message = "导出未完成：\(error.localizedDescription)" }
            }
            document = nil
        }
        .onAppear {
            startDate = entries.map(\.createdAt).min() ?? Date()
            endDate = max(startDate, entries.map(\.createdAt).max() ?? Date())
        }
        .onChange(of: startDate) { date in if endDate < date { endDate = date } }
        .onChange(of: subscriptions.isPremium) { enabled in
            if !enabled { preparationTask?.cancel(); document = nil; isExporting = false }
        }
        .onDisappear { preparationTask?.cancel() }
    }

    private func prepareExport() {
        guard subscriptions.isPremium, !isPreparing else { return }
        let snapshot = selectedEntries
        let requestedFormat = format
        message = nil
        isPreparing = true
        preparationTask = Task { @MainActor in
            defer { isPreparing = false }
            do {
                let data = try await JournalPremiumExportBuilder().build(entries: snapshot, format: requestedFormat)
                try Task.checkCancellation()
                guard subscriptions.isPremium else { return }
                format = requestedFormat
                document = JournalPremiumExportDocument(data: data)
                isExporting = true
            } catch is CancellationError {
                return
            } catch {
                message = "无法生成日记集：\(error.localizedDescription)"
            }
        }
    }
}
