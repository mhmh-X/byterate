import Foundation

enum HTTP {
    /// 临时会话：额度/账号响应不写入磁盘缓存
    private static let session = URLSession(configuration: .ephemeral)

    static func request(
        _ url: String,
        method: String = "GET",
        headers: [String: String] = [:],
        jsonBody: [String: Any]? = nil
    ) async throws -> (Int, Data) {
        guard let u = URL(string: url) else { throw UsageError.message("无效 URL", "Invalid URL") }
        var req = URLRequest(url: u, timeoutInterval: 15)
        req.httpMethod = method
        req.setValue("byterate/0.2", forHTTPHeaderField: "User-Agent")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if let body = jsonBody {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        return (status, data)
    }

    static func json(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}
