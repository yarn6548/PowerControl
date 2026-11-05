import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var testResult = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://192.168.1.88", text: $store.routerURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("小米路由器（局域网）")
                } footer: {
                    Text("负责发魔术包，开机走这条路。")
                }

                Section {
                    TextField("http://10.147.20.5", text: $store.routerURLRemote)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Toggle("出门时用这个地址", isOn: $store.useRemote)
                } header: {
                    Text("外网地址（ZeroTier）")
                } footer: {
                    Text("填小米在 ZeroTier 网络里的 IP。打开开关后，开机请求会走这里。")
                }

                Section {
                    TextField("http://192.168.1.235:8765", text: $store.pcURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("电脑（关机/重启）")
                } footer: {
                    Text("电脑上的 agent 地址。出门时这条可能连不上，正常。")
                }

                Section {
                    TextField("访问口令", text: $store.token)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("口令")
                } footer: {
                    Text("三处要一致：config.json、路由器 wake.cgi、这里。")
                }

                Section {
                    Button("测试连接") { Task { await test() } }
                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func test() async {
        testResult = "测试中…"
        var lines: [String] = []

        do {
            let s = try await PC.status(store: store)
            lines.append(s.online == true ? "电脑：在线" : "电脑：离线")
        } catch {
            lines.append("电脑：\(error.localizedDescription)")
        }

        do {
            _ = try await PC.wake(store: store)
            lines.append("路由器：通")
        } catch {
            lines.append("路由器：\(error.localizedDescription)")
        }

        testResult = lines.joined(separator: "\n")
    }
}
