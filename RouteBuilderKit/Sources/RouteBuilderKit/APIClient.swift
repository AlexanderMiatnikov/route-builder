import Foundation

public protocol Dispatching: Sendable {
    func fetchStops(page: Int, pageSize: Int, query: String?) async throws -> StopPage
    func fetchPhotos(stopID: String) async throws -> [DeliveryPhoto]
    func createRoute(stops: [RouteStopPayload]) async throws -> CreatedRoute
    func notify(routeID: String, stopID: String, idempotencyKey: String) async throws -> NotifyResult
}

public struct APIClient: Dispatching {
    public typealias Sleep = @Sendable (TimeInterval) async throws -> Void

    private let baseURL: URL
    private let session: URLSession
    private let sleep: Sleep
    private let stopPages = StopPageParser()
    private let photos = PhotoParser()
    private let routes = RouteResponseParser()

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        sleep: @escaping Sleep = { seconds in
            guard seconds > 0 else { return }
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.sleep = sleep
    }

    public func fetchStops(page: Int, pageSize: Int, query: String?) async throws -> StopPage {
        var components = URLComponents(
            url: endpoint("stops"),
            resolvingAgainstBaseURL: false
        )!
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        if let query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        return try await perform(request, parse: stopPages.page)
    }

    public func fetchPhotos(stopID: String) async throws -> [DeliveryPhoto] {
        var request = URLRequest(
            url: endpoint("stops")
                .appendingPathComponent(stopID)
                .appendingPathComponent("photos")
        )
        request.httpMethod = "GET"
        return try await perform(request, parse: photos.photos)
    }

    public func createRoute(stops: [RouteStopPayload]) async throws -> CreatedRoute {
        struct Body: Encodable { let stops: [RouteStopPayload] }
        var request = URLRequest(url: endpoint("routes"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encode(Body(stops: stops))
        return try await perform(request, parse: routes.created)
    }

    public func notify(
        routeID: String,
        stopID: String,
        idempotencyKey: String
    ) async throws -> NotifyResult {
        struct Body: Encodable {
            let stopID: String
            enum CodingKeys: String, CodingKey { case stopID = "stop_id" }
        }
        var request = URLRequest(
            url: endpoint("routes")
                .appendingPathComponent(routeID)
                .appendingPathComponent("notify")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try encode(Body(stopID: stopID))
        return try await perform(request, parse: routes.notify)
    }

    private func endpoint(_ component: String) -> URL {
        baseURL.appendingPathComponent(component)
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func perform<T>(
        _ request: URLRequest,
        parse: (Data) throws -> T
    ) async throws -> T {
        var retryCount = 0
        while true {
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw APIError.transport(error.localizedDescription)
            }

            guard let http = response as? HTTPURLResponse else {
                throw APIError.transport("response was not HTTP")
            }
            if (200..<300).contains(http.statusCode) {
                do {
                    return try parse(data)
                } catch let error as APIError {
                    throw error
                } catch {
                    throw APIError.decoding(error.localizedDescription)
                }
            }

            if Self.retryableStatuses.contains(http.statusCode), retryCount < 3 {
                retryCount += 1
                try await sleep(Self.retryDelay(from: http))
                continue
            }
            throw APIError.server(
                status: http.statusCode,
                code: routes.errorCode(from: data)
            )
        }
    }

    private static let retryableStatuses: Set<Int> = [429, 500, 503]

    private static func retryDelay(from response: HTTPURLResponse) -> TimeInterval {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After") else { return 0 }
        return max(0, TimeInterval(raw.trimmingCharacters(in: .whitespaces)) ?? 0)
    }
}
