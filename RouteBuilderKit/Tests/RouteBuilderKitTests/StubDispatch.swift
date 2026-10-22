import Foundation
@testable import RouteBuilderKit

actor StubDispatch: Dispatching {
    var stopPages: [Result<StopPage, APIError>] = []
    var photos: [DeliveryPhoto] = []
    var createResults: [Result<CreatedRoute, APIError>] = []
    var notifyResults: [Result<NotifyResult, APIError>] = []
    var createDelayNanoseconds: UInt64 = 0

    private(set) var fetchStopCalls: [(page: Int, pageSize: Int, query: String?)] = []
    private(set) var createCalls: [[RouteStopPayload]] = []
    private(set) var notifyCalls: [(routeID: String, stopID: String, key: String)] = []

    func fetchStops(page: Int, pageSize: Int, query: String?) async throws -> StopPage {
        fetchStopCalls.append((page, pageSize, query))
        return try stopPages.removeFirst().get()
    }

    func fetchPhotos(stopID: String) async throws -> [DeliveryPhoto] {
        photos
    }

    func createRoute(stops: [RouteStopPayload]) async throws -> CreatedRoute {
        createCalls.append(stops)
        if createDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: createDelayNanoseconds)
        }
        return try createResults.removeFirst().get()
    }

    func notify(routeID: String, stopID: String, idempotencyKey: String) async throws -> NotifyResult {
        notifyCalls.append((routeID, stopID, idempotencyKey))
        return try notifyResults.removeFirst().get()
    }

    func configureStopPages(_ pages: [Result<StopPage, APIError>]) {
        stopPages = pages
    }

    func configureCreate(
        results: [Result<CreatedRoute, APIError>],
        delayNanoseconds: UInt64 = 0
    ) {
        createResults = results
        createDelayNanoseconds = delayNanoseconds
    }

    func configureNotify(_ results: [Result<NotifyResult, APIError>]) {
        notifyResults = results
    }

    func recordedFetchStopCalls() -> [(page: Int, pageSize: Int, query: String?)] {
        fetchStopCalls
    }

    func recordedCreateCalls() -> [[RouteStopPayload]] {
        createCalls
    }

    func recordedNotifyCalls() -> [(routeID: String, stopID: String, key: String)] {
        notifyCalls
    }
}
