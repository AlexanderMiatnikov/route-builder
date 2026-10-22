import Foundation
import XCTest
@testable import RouteBuilderKit

final class ClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func testAPIClientRetries500OnceThenSucceeds() async throws {
        URLProtocolStub.enqueue(status: 500, body: #"{"error":"temporary"}"#)
        URLProtocolStub.enqueue(
            status: 200,
            body: #"{"items":[],"page":1,"page_size":20,"has_more":false}"#
        )
        let client = makeClient()

        let page = try await client.fetchStops(page: 1, pageSize: 20, query: nil)

        XCTAssertEqual(page.items, [])
        XCTAssertEqual(URLProtocolStub.requestCount, 2)
    }

    func testAPIClientDoesNotRetry400() async {
        URLProtocolStub.enqueue(status: 400, body: #"{"error":"bad_request"}"#)
        let client = makeClient()

        do {
            _ = try await client.fetchStops(page: 1, pageSize: 20, query: nil)
            XCTFail("Expected a server error")
        } catch {
            XCTAssertEqual(error as? APIError, .server(status: 400, code: "bad_request"))
        }
        XCTAssertEqual(URLProtocolStub.requestCount, 1)
    }

    func testDirectoryLoaderDedupesOverlappingPages() async throws {
        let stub = StubDispatch()
        await stub.configureStopPages([
            .success(page(ids: ["a", "b"], number: 1, hasMore: true)),
            .success(page(ids: ["b", "c"], number: 2, hasMore: false))
        ])

        let stops = try await DirectoryLoader(api: stub).load(pageSize: 2, query: "central")

        XCTAssertEqual(stops.map(\.id), ["a", "b", "c"])
        let calls = await stub.recordedFetchStopCalls()
        XCTAssertEqual(calls.map(\.page), [1, 2])
        XCTAssertEqual(calls.map(\.query), ["central", "central"])
    }

    func testDirectoryLoaderStopsWhenHasMorePageIsEmpty() async throws {
        let stub = StubDispatch()
        await stub.configureStopPages([
            .success(page(ids: ["a"], number: 1, hasMore: true)),
            .success(page(ids: [], number: 2, hasMore: true)),
            .success(page(ids: ["unreachable"], number: 3, hasMore: false))
        ])

        let stops = try await DirectoryLoader(api: stub).load(pageSize: 1, query: nil)

        XCTAssertEqual(stops.map(\.id), ["a"])
        let calls = await stub.recordedFetchStopCalls()
        XCTAssertEqual(calls.count, 2)
    }

    func testConcurrentSubmitCoalescesCreateAndNormalizesBody() async throws {
        let stub = StubDispatch()
        let created = CreatedRoute(id: "route-1", stops: [], status: "created")
        await stub.configureCreate(
            results: [.success(created)],
            delayNanoseconds: 50_000_000
        )
        let gateway = RouteGateway(api: stub)
        let oversized = RouteStopPayload(
            stopID: "stop-1",
            packages: 0,
            instructions: String(repeating: "x", count: 250)
        )

        async let first = gateway.submit([oversized])
        async let second = gateway.submit([oversized])
        let results = try await [first, second]

        XCTAssertEqual(results, [created, created])
        let calls = await stub.recordedCreateCalls()
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0][0].packages, 1)
        XCTAssertEqual(calls[0][0].instructions.count, 200)
    }

    func testFailedNotifyRetriesWithDifferentIdempotencyKey() async {
        let stub = StubDispatch()
        await stub.configureNotify([
            .success(NotifyResult(stopID: "stop-1", status: "failed", attempts: 1)),
            .success(NotifyResult(stopID: "stop-1", status: "sent", attempts: 2))
        ])
        let gateway = RouteGateway(api: stub)

        let results = await gateway.notifyDriver(routeID: "route-1", stopIDs: ["stop-1"])

        XCTAssertEqual(results.map(\.status), ["sent"])
        let calls = await stub.recordedNotifyCalls()
        XCTAssertEqual(calls.count, 2)
        XCTAssertNotEqual(calls[0].key, calls[1].key)
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return APIClient(
            baseURL: URL(string: "https://dispatch.example/v1/")!,
            session: URLSession(configuration: configuration),
            sleep: { _ in }
        )
    }

    private func page(ids: [String], number: Int, hasMore: Bool) -> StopPage {
        StopPage(
            items: ids.map { Stop(id: $0, name: $0, address: "", phone: "") },
            page: number,
            pageSize: ids.count,
            hasMore: hasMore
        )
    }
}

private final class URLProtocolStub: URLProtocol {
    struct Response {
        let status: Int
        let body: Data
        let headers: [String: String]
    }

    private static let lock = NSLock()
    private static var responses: [Response] = []
    private static var requests: [URLRequest] = []

    static var requestCount: Int {
        lock.withLock { requests.count }
    }

    static func enqueue(status: Int, body: String, headers: [String: String] = [:]) {
        lock.withLock {
            responses.append(Response(status: status, body: Data(body.utf8), headers: headers))
        }
    }

    static func reset() {
        lock.withLock {
            responses = []
            requests = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = Self.lock.withLock { () -> Response in
            Self.requests.append(request)
            return Self.responses.removeFirst()
        }
        let http = HTTPURLResponse(
            url: request.url!,
            statusCode: response.status,
            httpVersion: nil,
            headerFields: response.headers
        )!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
