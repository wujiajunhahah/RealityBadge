import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("rb.push.time") private var pushTime: Double = Date().timeIntervalSince1970
    @AppStorage("rb.push.freq") private var freq: Int = 1
    @AppStorage("rb.style") private var style: String = "embossed"
    @AppStorage("rb.enableParallax") private var enableParallax: Bool = true
    @AppStorage("rb.icloud") private var iCloudSync: Bool = true
    private var pushDate: Binding<Date> {
        .init(get: { Date(timeIntervalSince1970: pushTime) },
              set: { pushTime = $0.timeIntervalSince1970 })
    }

    var body: some View {
        NavigationStack {
            Form {
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
                Section("账号与数据") {
                    Toggle("iCloud 同步", isOn: $iCloudSync)
                    Button("导出全部徽章 (ZIP)") { /* TODO */ }
                    Button("清除缓存") { /* TODO */ }.foregroundStyle(.red)
                }
                Section("关于") {
                    HStack { Text("版本"); Spacer(); Text("1.0").foregroundStyle(.secondary) }
                    Link("隐私政策", destination: URL(string: "https://example.com/privacy")!)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}