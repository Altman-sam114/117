import SwiftUI

struct JournalWritingSettingsView: View {
    @AppStorage(JournalPreferenceKey.appearance) private var appearance = JournalAppearance.system.rawValue
    @AppStorage(JournalPreferenceKey.writingFont) private var font = JournalWritingFont.rounded.rawValue
    @AppStorage(JournalPreferenceKey.writingSize) private var size = JournalWritingSize.standard.rawValue
    @AppStorage(JournalPreferenceKey.writingSpacing) private var spacing = JournalWritingSpacing.standard.rawValue
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var preferences: JournalWritingPreferences {
        JournalWritingPreferences(fontRaw: font, sizeRaw: size, spacingRaw: spacing)
    }

    private var sampleFont: Font {
        .system(
            size: preferences.pointSize(category: JournalWritingPreferences.contentSizeCategory(for: dynamicTypeSize)),
            design: preferences.font.design
        )
    }

    private var sampleLineSpacing: CGFloat {
        5 + preferences.lineSpacing(category: JournalWritingPreferences.contentSizeCategory(for: dynamicTypeSize))
    }

    var body: some View {
        Form {
            Section {
                Picker("纸页外观", selection: $appearance) {
                    ForEach(JournalAppearance.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .accessibilityIdentifier("journal.writing.appearance")
            } header: {
                Text("外观")
            } footer: {
                Text("跟随系统会自动适应浅色与深色模式。所有写作设置免费，不会修改日记原文或导出格式。")
            }
            Section("正文排版") {
                Picker("字体", selection: $font) {
                    ForEach(JournalWritingFont.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .accessibilityIdentifier("journal.writing.font")
                Picker("字号", selection: $size) {
                    ForEach(JournalWritingSize.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("行距", selection: $spacing) {
                    ForEach(JournalWritingSpacing.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Text("编辑与阅读预览共用正文设置，并继续跟随系统辅助字号。中文使用系统提供的对应字形。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("此刻的纸页") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("日常，值得慢慢写。")
                        .font(.system(.title2, design: .serif).weight(.medium))
                    Text("一盏灯，一页纸，把今天留给自己。\nWrite a little, remember a little.\n\n### 明天的小事\n- 给自己留一点从容")
                        .font(sampleFont)
                        .lineSpacing(sampleLineSpacing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("journal.writing.sample")
                .listRowBackground(JournalTheme.paper)
            }
            Section {
                Button("恢复默认外观与排版") {
                    appearance = JournalAppearance.system.rawValue
                    font = JournalWritingFont.rounded.rawValue
                    size = JournalWritingSize.standard.rawValue
                    spacing = JournalWritingSpacing.standard.rawValue
                }
                .frame(minHeight: 44)
            } footer: {
                Text("只恢复此页偏好，不会更改日记、应用锁或订阅。")
            }
        }
        .scrollContentBackground(.hidden)
        .background { JournalBackdrop().ignoresSafeArea() }
        .tint(JournalTheme.accent)
        .navigationTitle("外观与写作")
        .navigationBarTitleDisplayMode(.inline)
    }
}
