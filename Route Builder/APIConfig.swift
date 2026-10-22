import Foundation

enum APIConfig {
    static var baseURL: URL {
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
