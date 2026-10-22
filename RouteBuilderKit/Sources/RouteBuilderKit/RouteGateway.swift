import Foundation

public actor RouteGateway {
    private let api: any Dispatching
    private var inFlight: Task<CreatedRoute, Error>?

    public init(api: any Dispatching) {
        self.api = api
    }

    public func submit(_ stops: [RouteStopPayload]) async throws -> CreatedRoute {
        if let inFlight {
            return try await inFlight.value
        }
        let normalized = stops.map { $0.normalized() }
        let task = Task { try await api.createRoute(stops: normalized) }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    public func notifyDriver(routeID: String, stopIDs: [String]) async -> [NotifyResult] {
        var results: [NotifyResult] = []
        for stopID in stopIDs {
            let first = await notify(
                routeID: routeID,
                stopID: stopID,
                idempotencyKey: UUID().uuidString
            )
            if let first, first.sent {
                results.append(first)
                continue
            }

            let second = await notify(
                routeID: routeID,
                stopID: stopID,
                idempotencyKey: UUID().uuidString
            )
            results.append(
                second ?? NotifyResult(
                    stopID: stopID,
                    status: "failed",
                    attempts: 2,
                    detail: "Notification request failed"
                )
            )
        }
        return results
    }

    private func notify(
        routeID: String,
        stopID: String,
        idempotencyKey: String
    ) async -> NotifyResult? {
        try? await api.notify(
            routeID: routeID,
            stopID: stopID,
            idempotencyKey: idempotencyKey
        )
    }
}
