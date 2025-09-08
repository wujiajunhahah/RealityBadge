import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState

    @AppStorage("rb.push.time") private var pushTime: Double = Date().timeIntervalSince1970
    @AppStorage("rb.push.freq") private var freq: Int = 1
    @AppStorage("rb.style") private var style: String = "embossed"
    @AppStorage("rb.enableParallax") private var enableParallax: Bool = true
    @AppStorage("rb.icloud") private var iCloudSync: Bool = true
    @AppStorage("rb.validation.mode") private var validationModeRaw: String = RBValidationMode.standard.rawValue
    private var pushDate: Binding<Date> {
        .init(get: { Date(timeIntervalSince1970: pushTime) },
              set: { pushTime = $0.timeIntervalSince1970 })
    }

    @State private var exportFolderURL: URL? = nil
    @State private var showImporter: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("通知（占位）") {
                    Toggle("启用通知（即将开启）", isOn: .constant(false))
                        .disabled(true)
                    Text("上线后将提供每日挑战推送开关与时间设置。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("每日挑战") {
                    DatePicker("推送时间", selection: pushDate, displayedComponents: .hourAndMinute)
                    Picker("频率", selection: $freq) {
                        Text("每天").tag(1)
                        Text("每周 3 次").tag(3)
                        Text("关闭").tag(0)
                    }
                }
                Section("徽章与风格") {
                    Picker("默认风格", selection: $style) {
                        Text("浮雕章").tag("embossed")
                        Text("胶片卡").tag("film")
                        Text("像素章").tag("pixel")
                    }
                    Toggle("动态预览（3D-lite）", isOn: $enableParallax)
                }
                Section("验证模式") {
                    Picker("模式", selection: $validationModeRaw) {
                        ForEach(RBValidationMode.allCases) { m in
                            Text(m.rawValue).tag(m.rawValue)
                        }
                    }
                }
                Section("账号与数据") {
                    Toggle("iCloud 同步", isOn: $iCloudSync)
                    Button("导出全部徽章 (.rbadge)") {
                        do {
                            let url = try RBPackage.exportAll(state.recentBadges)
                            exportFolderURL = url
                        } catch {
                            print("Export failed: \(error)")
                        }
                    }
                    Button("导入徽章包 (.rbadge)") { showImporter = true }
                    if let url = exportFolderURL {
                        ShareLink(item: url) {
                            Label("分享导出文件夹", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button("清除缓存") { /* TODO */ }.foregroundStyle(.red)
                }
                Section("关于") {
                    HStack { Text("版本"); Spacer(); Text("1.0").foregroundStyle(.secondary) }
                    Link("隐私政策", destination: URL(string: "https://example.com/privacy")!)
                    Link("鸣谢与开源", destination: URL(string: "https://github.com/wujiajunhahah/RealityBadge")!)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.rbadge], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                RBBadgeImportHelper.importPackage(at: url, into: state)
            }
        }
    }
}
