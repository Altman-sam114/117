import SwiftUI

struct JournalPrivacyView: View {
    var body: some View {
        List {
            Section("日记留在你的设备") {
                Text("日记正文、标题、分类和心情保存在本机 JSON 文件。MD Journal 没有自建账号、日记服务器或应用内云同步，也不接入广告与第三方分析服务。")
                Text("系统设备备份由你管理。日记位于 Documents，可能随 iCloud 或电脑设备备份保存；在文件、分享或导出中选择其他服务时，由所选服务按其政策处理。")
            }
            Section("应用锁与文件保护") {
                Text("默认开启“隐藏多任务预览”，离开应用时遮挡包括已打开设置页在内的窗口内容，返回后无需验证。可在设置关闭；启用应用锁后，非活跃界面始终遮挡。此功能不能阻止你主动截屏或录屏。")
                Text("应用锁由系统验证设备持有者身份，可使用设备密码或可用的生物识别。应用不会读取或保存面容、指纹或设备密码。")
                Text("应用锁是界面访问保护，不是自定义日记加密。iOS 文件使用系统数据保护，在设备重启后首次解锁前不可访问；首次解锁后允许后台保存。开启应用锁会在非活跃界面遮挡内容，并在进入后台后要求再次验证。")
                Text("导出的 JSON、Markdown 和 PDF 没有应用锁保护。请只保存到你信任的位置，勿向他人分享不希望公开的内容。")
            }
            Section("设置与购买") {
                Text("外观、字体、字号、行距、多任务预览与应用锁开关保存在本机偏好设置，仅用于你选择的应用行为。写作外观设置免费，不修改日记原文。")
                Text("如购买高级功能，商品、付款、退款及订阅管理由 Apple 的 App Store 处理。应用通过 StoreKit 验证交易并判断高级权益，不接收银行卡资料。商品显示价及订阅期限以 App Store 实时返回为准。")
                Link("Apple 标准最终用户许可协议", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            Section("控制你的内容") {
                Text("你可以免费导出完整 JSON 备份、合并导入备份、分享单篇日记或删除日记。导入仅追加新的日记 ID，同 ID 的本机内容始终保留。删除应用通常会移除本机数据，请提前备份。")
                if let privacyURL = JournalPublicLinks.privacy {
                    Link("公开隐私政策", destination: privacyURL)
                }
            }
        }
        .navigationTitle("隐私与数据")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum JournalPublicLinks {
    static var privacy: URL? { configuredURL(for: "JournalPrivacyPolicyURL") }
    static var support: URL? { configuredURL(for: "JournalSupportURL") }

    private static func configuredURL(for key: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}
