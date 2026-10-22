import Foundation

/// Resolves the API base URL. Sources default to the real process environment
/// and main bundle; tests override them through the memberwise init.
struct APIConfig {
    var environment = ProcessInfo.processInfo.environment
    var bundle = Bundle.main
    var fallbackOrigin = URL(string: "http://localhost:4000")!

    /// Configured value is the service origin (e.g. `http://localhost:4000`).
    /// `APIClient` appends `stops`, `routes`, ... to this URL, and every endpoint
    /// of the service lives under `/v1`, so the API root is `<origin>/v1`.
    var baseURL: URL {
        apiRoot(from: configuredURL)
    }

    func apiRoot(from url: URL) -> URL {
        if url.pathComponents.contains("v1") { return url }
        return url.appendingPathComponent("v1")
    }

    private var configuredURL: URL {
        if let env = environment["ROUTE_API_BASE_URL"],
           let url = URL(string: env),
           !env.isEmpty {
            return url
        }
        if let raw = bundle.object(forInfoDictionaryKey: "APIBaseURL") as? String,
           let url = URL(string: raw),
           !raw.isEmpty {
            return url
        }
        return fallbackOrigin
    }
}
