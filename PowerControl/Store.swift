import Foundation
import Combine

/// 全部配置存在 UserDefaults 里，改完立刻生效。
final class Store: ObservableObject {

    static let shared = Store()

    @Published var token: String {
        didSet { UserDefaults.standard.set(token, forKey: "token") }
    }
    /// 局域网：小米路由器（发魔术包）
    @Published var routerURL: String {
        didSet { UserDefaults.standard.set(routerURL, forKey: "routerURL") }
    }
    /// 外网：走 ZeroTier 时的小米地址，留空表示不用
    @Published var routerURLRemote: String {
        didSet { UserDefaults.standard.set(routerURLRemote, forKey: "routerURLRemote") }
    }
    /// 电脑 agent 地址（关机/重启用）
    @Published var pcURL: String {
        didSet { UserDefaults.standard.set(pcURL, forKey: "pcURL") }
    }
    @Published var useRemote: Bool {
        didSet { UserDefaults.standard.set(useRemote, forKey: "useRemote") }
    }

    private init() {
        let d = UserDefaults.standard
        token = d.string(forKey: "token") ?? "77c52ec8a779849b"
        routerURL = d.string(forKey: "routerURL") ?? "http://192.168.1.88"
        routerURLRemote = d.string(forKey: "routerURLRemote") ?? ""
        pcURL = d.string(forKey: "pcURL") ?? "http://192.168.1.235:8765"
        useRemote = d.bool(forKey: "useRemote")
    }

    /// 当前该用哪个小米地址
    var activeRouter: String {
        if useRemote && !routerURLRemote.trimmingCharacters(in: .whitespaces).isEmpty {
            return routerURLRemote.trimmingCharacters(in: .whitespaces)
        }
        return routerURL.trimmingCharacters(in: .whitespaces)
    }
}
