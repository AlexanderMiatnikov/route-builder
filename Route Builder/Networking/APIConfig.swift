import Foundation

enum APIConfig {
    /// Configured value is the service origin (e.g. `http://localhost:4000`).
    /// `APIClient` appends `stops`, `routes`, ... to this URL, and every endpoint
    /// of the service lives under `/v1`, so the API root is `<origin>/v1`.
    static var baseURL: URL {
        apiRoot(from: configuredURL)
    }

    static func apiRoot(from url: URL) -> URL {
        if url.pathComponents.contains("v1") { return url }
        return url.appendingPathComponent("v1")
    }

    private static var configuredURL: URL {
        if let env = ProcessInfo.processInfo.environment["ROUTE_API_BASE_URL"],
           let url = URL(string: env),
           !env.isEmpty {
            return url
        }
        if let raw = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
           let url = URL(string: raw),
           !raw.isEmpty {
            return url
        }
        return URL(string: "http://localhost:4000")!
    }
}
