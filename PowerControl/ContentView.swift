import SwiftUI

struct ContentView: View {
    @StateObject private var store = Store.shared

    @State private var online: Bool? = nil
    @State private var statusText = ""
    @State private var log = ""
    @State private var busy = false
    @State private var showSettings = false

    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                        .padding(.top, 4)

                    Button {
                        Task { await doWake() }
                    } label: {
                        Text("开 机")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 26)
                            .background(Color.green.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.green.opacity(0.4), lineWidth: 1)
                            )
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(busy)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                              spacing: 11) {
                        actionButton("关机", "shutdown", .red, "确定关机？")
                        actionButton("重启", "reboot", .orange, "确定重启？")
                        actionButton("睡眠", "sleep", .blue, nil)
                        actionButton("锁屏", "lock", .gray, nil)
                    }

                    if !log.isEmpty {
                        Text(log)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }

                    Text("关机后约 20 秒，上面的圆点会变灰。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .background(Color(red: 0.043, green: 0.051, blue: 0.063).ignoresSafeArea())
            .navigationTitle("REMOTE POWER")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(store: store)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { Task { await refresh() } }
        .onReceive(timer) { _ in Task { await refresh() } }
    }

    // MARK: - 组件

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Circle()
                    .fill(online == true ? Color.green :
                          (online == false ? Color.red : Color.gray))
                    .frame(width: 9, height: 9)
                    .shadow(color: online == true ? .green.opacity(0.5) : .clear, radius: 5)

                Text(online == true ? "电脑在线" :
                     (online == false ? "电脑离线" : "检测中…"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(online == true ? .green : .secondary)
            }
            Text(statusText.isEmpty ? " " : statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.067, green: 0.082, blue: 0.106))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func actionButton(_ title: String, _ action: String,
                              _ tint: Color, _ confirm: String?) -> some View {
        Button {
            Task { await doAction(action, confirm: confirm) }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                )
                .foregroundStyle(tint)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(busy)
    }

    // MARK: - 动作

    @MainActor
    private func refresh() async {
        do {
            let s = try await PC.status(store: store)
            online = s.ok && (s.online ?? false)
            statusText = s.info ?? (s.error ?? "")
        } catch {
            online = false
            statusText = ""
        }
    }

    @MainActor
    private func doWake() async {
        busy = true
        defer { busy = false }
        log = "发送魔术包…"
        do {
            let msg = try await PC.wake(store: store)
            log = "已发出：\(msg)"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            await refresh()
        } catch {
            log = "失败：\(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    @MainActor
    private func doAction(_ name: String, confirm: String?) async {
        if let c = confirm {
            let ok = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                let alert = UIAlertController(title: nil, message: c,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                    cont.resume(returning: false)
                })
                alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in
                    cont.resume(returning: true)
                })
                if let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene }).first,
                   let root = scene.keyWindow?.rootViewController {
                    root.present(alert, animated: true)
                } else {
                    cont.resume(returning: true)
                }
            }
            if !ok { return }
        }

        busy = true
        defer { busy = false }
        log = "执行 \(name)…"
        do {
            let msg = try await PC.action(name, store: store)
            log = "已执行：\(msg)"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await refresh()
        } catch {
            log = "失败：\(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

extension UIWindowScene {
    var keyWindow: UIWindow? {
        windows.first(where: { $0.isKeyWindow })
    }
}
