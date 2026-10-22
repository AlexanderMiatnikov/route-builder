import Foundation

public struct Stop: Equatable, Sendable, Identifiable, Hashable, Codable {
    public var id: String
    public var name: String
    public var address: String
    public var phone: String
    public var zone: String?
    public var packagesMax: Int?
    public var lastDeliveryAt: Date?
    public var notes: String?
    public var isLocal: Bool

    public init(
        id: String,
        name: String,
        address: String,
        phone: String,
        zone: String? = nil,
        packagesMax: Int? = nil,
        lastDeliveryAt: Date? = nil,
        notes: String? = nil,
        isLocal: Bool = false
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.phone = phone
        self.zone = zone
        self.packagesMax = packagesMax
        self.lastDeliveryAt = lastDeliveryAt
        self.notes = notes
        self.isLocal = isLocal
    }
}

public struct StopPage: Equatable, Sendable {
    public var items: [Stop]
    public var page: Int
    public var pageSize: Int
    public var hasMore: Bool

    public init(items: [Stop], page: Int, pageSize: Int, hasMore: Bool) {
        self.items = items
        self.page = page
        self.pageSize = pageSize
        self.hasMore = hasMore
    }
}

public struct DeliveryPhoto: Equatable, Sendable, Identifiable, Hashable {
    public var id: String
    public var url: URL
    public var tag: String
    public var width: Int?
    public var height: Int?

    public init(id: String, url: URL, tag: String, width: Int? = nil, height: Int? = nil) {
        self.id = id
        self.url = url
        self.tag = tag
        self.width = width
        self.height = height
    }

    public var tagTitle: String {
        switch tag {
        case "entrance": return "Entrance"
        case "parking": return "Parking"
        case "back_door": return "Back door"
        default:
            return tag.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

public struct RouteStopPayload: Equatable, Sendable, Codable {
    public var stopID: String
    public var packages: Int
    public var instructions: String

    public init(stopID: String, packages: Int, instructions: String) {
        self.stopID = stopID
        self.packages = packages
        self.instructions = instructions
    }

    public func normalized(rules: InstructionRules = InstructionRules()) -> RouteStopPayload {
        RouteStopPayload(
            stopID: stopID,
            packages: max(1, packages),
            instructions: rules.clip(instructions)
        )
    }

    enum CodingKeys: String, CodingKey {
        case stopID = "stop_id"
        case packages
        case instructions
    }
}

public struct CreatedRoute: Equatable, Sendable {
    public var id: String
    public var stops: [RouteStopPayload]
    public var status: String

    public init(id: String, stops: [RouteStopPayload], status: String) {
        self.id = id
        self.stops = stops
        self.status = status
    }
}

public struct NotifyResult: Equatable, Sendable {
    public var stopID: String
    public var status: String
    public var attempts: Int
    public var detail: String?

    public init(stopID: String, status: String, attempts: Int, detail: String? = nil) {
        self.stopID = stopID
        self.status = status
        self.attempts = attempts
        self.detail = detail
    }

    public var sent: Bool { status == "sent" }
}

public struct RouteDraft: Equatable, Sendable, Codable {
    public var mode: String
    public var stops: [DraftStop]

    public init(mode: String, stops: [DraftStop]) {
        self.mode = mode
        self.stops = stops
    }
}

public struct DraftStop: Equatable, Sendable, Codable {
    public var stop: Stop
    public var packages: Int
    public var instructions: String
    public var photoPath: String?

    public init(stop: Stop, packages: Int, instructions: String, photoPath: String? = nil) {
        self.stop = stop
        self.packages = packages
        self.instructions = instructions
        self.photoPath = photoPath
    }
}

public enum APIError: Error, Equatable, Sendable {
    case transport(String)
    case server(status: Int, code: String?)
    case decoding(String)

    public var userMessage: String {
        switch self {
        case .transport:
            return "The dispatch service didn't answer. Your route is still here."
        case .server(let status, let code):
            if status == 429 || code == "rate_limited" {
                return "The service is busy. Wait a moment and try again."
            }
            if code == "validation_failed" {
                return "The service rejected the route. Check the stops and try again."
            }
            return "The service failed (\(code ?? "HTTP \(status)")). Your route is still here."
        case .decoding:
            return "The service sent a response the app couldn't read. Your route is still here."
        }
    }
}

public struct InstructionRules: Sendable {
    /// The mock stores `instructions.slice(0, 200)` even though the doc says 250.
    public static let defaultMaxCharacters = 200

    public let maxCharacters: Int

    public init(maxCharacters: Int = InstructionRules.defaultMaxCharacters) {
        self.maxCharacters = maxCharacters
    }

    public func isEmpty(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func clip(_ text: String) -> String {
        String(text.prefix(maxCharacters))
    }
}

public struct PackageCount: Sendable {
    /// Used when the service sends `packages_max: null`.
    public static let defaultFallbackMax = 9

    public let fallbackMax: Int

    public init(fallbackMax: Int = PackageCount.defaultFallbackMax) {
        self.fallbackMax = fallbackMax
    }

    public func upperBound(max declared: Int?) -> Int {
        if let declared, declared >= 1 { return declared }
        return fallbackMax
    }

    public func clamp(_ value: Int, max declared: Int?) -> Int {
        min(upperBound(max: declared), max(1, value))
    }
}
