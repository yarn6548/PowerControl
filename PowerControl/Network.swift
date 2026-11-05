import Foundation

enum PCError: LocalizedError {
    case badURL(String)
    case http(Int)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badURL(let s):  return "地址不对：\(s)"
        case .http(let code): return "HTTP \(code)"
        case .server(let msg): return msg
        }
    }
}

struct StatusInfo: Decodable {
    let ok: Bool
    let online: Bool?
    let info: String?
    let error: String?
}

struct BasicReply: Decodable {
    let ok: Bool
    let msg: String?
    let error: String?
}

enum PC {

    private static var session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 6
        c.timeoutIntervalForResource = 10
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    private static func request(_ urlString: String, method: String = "GET",
                                body: Data? = nil, token: String? = nil) throws -> URLRequest {
        guard let url = URL(string: urlString) else { throw PCError.badURL(urlString) }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.cachePolicy = .reloadIgnoringLocalCacheData
        if let t = token { r.setValue(t, forHTTPHeaderField: "X-Token") }
        if let b = body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = b
        }
        return r
    }

    /// 让小米路由器发魔术包
    static func wake(store: Store) async throws -> String {
        let base = store.activeRouter
        guard var comp = URLComponents(string: base + "/cgi-bin/wake") else {
            throw PCError.badURL(base)
        }
        comp.queryItems = [URLQueryItem(name: "token", value: store.token)]
        guard let url = comp.url else { throw PCError.badURL(base) }

        let (data, resp) = try await session.data(for: URLRequest(url: url))
        guard let http = resp as? HTTPURLResponse else { throw PCError.http(-1) }
        guard http.statusCode == 200 else { throw PCError.http(http.statusCode) }

        let reply = try JSONDecoder().decode(BasicReply.self, from: data)
        guard reply.ok else { throw PCError.server(reply.error ?? "路由器拒绝了") }
        return reply.msg ?? "已发出"
    }

    /// 查电脑在线状态
    static func status(store: Store) async throws -> StatusInfo {
        guard var comp = URLComponents(string: store.pcURL + "/api/status") else {
            throw PCError.badURL(store.pcURL)
        }
        comp.queryItems = [URLQueryItem(name: "token", value: store.token)]
        guard let url = comp.url else { throw PCError.badURL(store.pcURL) }

        let req = try request(url.absoluteString, token: store.token)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw PCError.http(-1) }
        guard http.statusCode == 200 else { throw PCError.http(http.statusCode) }
        return try JSONDecoder().decode(StatusInfo.self, from: data)
    }

    /// 关机 / 重启 / 睡眠 / 锁屏 / 取消
    static func action(_ name: String, store: Store) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["action": name])
        let req = try request(store.pcURL + "/api/action", method: "POST",
                              body: body, token: store.token)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw PCError.http(-1) }
        guard http.statusCode == 200 else { throw PCError.http(http.statusCode) }
        let reply = try JSONDecoder().decode(BasicReply.self, from: data)
        guard reply.ok else { throw PCError.server(reply.error ?? "执行失败") }
        return reply.msg ?? "已执行"
    }

    /// 局域网内直接发魔术包（不经过路由器，路由器挂了时的备用路径）
    static func wakeDirect(mac: String, broadcast: String = "255.255.255.255",
                           port: UInt16 = 9) throws {
        let hex = mac.replacingOccurrences(of: "-", with: ":")
                     .split(separator: ":").compactMap { UInt8($0, radix: 16) }
        guard hex.count == 6 else { throw PCError.server("MAC 格式不对") }

        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: hex) }

        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { throw PCError.server("socket 创建失败") }
        defer { close(fd) }

        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &on, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(broadcast)

        let sent = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                packet.withUnsafeBytes { buf in
                    sendto(fd, buf.baseAddress, buf.count, 0, sa,
                           socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { throw PCError.server("发送失败") }
    }
}
