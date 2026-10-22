import Foundation

/// Lenient accessors over `JSONSerialization` output. Injected into the parsers.
struct JSONReader: Sendable {
    func object(_ data: Data) throws -> [String: Any] {
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let object = raw as? [String: Any] else {
            throw APIError.decoding("root was not an object")
        }
        return object
    }

    func int(_ value: Any?) -> Int? {
        if value == nil || value is NSNull { return nil }
        if let number = value as? NSNumber {
            if number === kCFBooleanTrue || number === kCFBooleanFalse { return nil }
            return number.intValue
        }
        if let string = value as? String {
            return Int(string.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    func string(_ value: Any?) -> String? {
        if value == nil || value is NSNull { return nil }
        if let string = value as? String { return string }
        return nil
    }

    func bool(_ value: Any?) -> Bool? {
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    func date(_ value: Any?) -> Date? {
        if value == nil || value is NSNull { return nil }
        if let number = value as? NSNumber, !(number === kCFBooleanTrue || number === kCFBooleanFalse) {
            let raw = number.doubleValue
            let seconds = raw > 10_000_000_000 ? raw / 1000 : raw
            return Date(timeIntervalSince1970: seconds)
        }
        guard var string = value as? String else { return nil }
        string = string.trimmingCharacters(in: .whitespaces)
        if string.contains("T"), !string.hasSuffix("Z"), string.range(of: #"[+-]\d{2}:?\d{2}$"#, options: .regularExpression) == nil {
            string += "Z"
        }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}

public struct StopPageParser: Sendable {
    private let reader: JSONReader

    public init() {
        self.reader = JSONReader()
    }

    init(reader: JSONReader) {
        self.reader = reader
    }

    public func page(from data: Data) throws -> StopPage {
        let json = try reader.object(data)
        let items = stops(from: json["items"])
        return StopPage(
            items: items,
            page: reader.int(json["page"]) ?? 1,
            pageSize: reader.int(json["page_size"]) ?? items.count,
            hasMore: reader.bool(json["has_more"]) ?? false
        )
    }

    public func stops(from value: Any?) -> [Stop] {
        if value == nil || value is NSNull { return [] }
        guard let rows = value as? [Any] else { return [] }
        return rows.compactMap { row in
            guard let object = row as? [String: Any] else { return nil }
            return stop(from: object)
        }
    }

    public func stop(from json: [String: Any]) -> Stop? {
        guard let id = reader.string(json["id"]), !id.isEmpty else { return nil }
        return Stop(
            id: id,
            name: reader.string(json["name"]) ?? "Unknown stop",
            address: reader.string(json["address"]) ?? "",
            phone: reader.string(json["phone"]) ?? "",
            zone: reader.string(json["zone"]),
            packagesMax: reader.int(json["packages_max"]),
            lastDeliveryAt: reader.date(json["last_delivery_at"]),
            notes: reader.string(json["notes"]),
            isLocal: reader.bool(json["isLocal"]) ?? false
        )
    }
}

public struct PhotoParser: Sendable {
    private let reader: JSONReader

    public init() {
        self.reader = JSONReader()
    }

    init(reader: JSONReader) {
        self.reader = reader
    }

    public func photos(from data: Data) throws -> [DeliveryPhoto] {
        let json = try reader.object(data)
        let raw = json["items"]
        if raw == nil || raw is NSNull { return [] }
        guard let rows = raw as? [Any] else { return [] }
        return rows.compactMap { row in
            guard let object = row as? [String: Any] else { return nil }
            guard let id = reader.string(object["id"]), !id.isEmpty else { return nil }
            guard let urlString = reader.string(object["url"]), let url = URL(string: urlString) else { return nil }
            return DeliveryPhoto(
                id: id,
                url: url,
                tag: reader.string(object["tag"]) ?? "",
                width: reader.int(object["width"]),
                height: reader.int(object["height"])
            )
        }
    }
}

public struct RouteResponseParser: Sendable {
    private let reader: JSONReader

    public init() {
        self.reader = JSONReader()
    }

    init(reader: JSONReader) {
        self.reader = reader
    }

    public func created(from data: Data) throws -> CreatedRoute {
        let json = try reader.object(data)
        guard let id = reader.string(json["id"]), !id.isEmpty else {
            throw APIError.decoding("route id missing")
        }
        let stops = (json["stops"] as? [Any] ?? []).compactMap { row -> RouteStopPayload? in
            guard let object = row as? [String: Any] else { return nil }
            guard let stopID = reader.string(object["stop_id"]) else { return nil }
            return RouteStopPayload(
                stopID: stopID,
                packages: reader.int(object["packages"]) ?? 1,
                instructions: reader.string(object["instructions"]) ?? ""
            )
        }
        return CreatedRoute(
            id: id,
            stops: stops,
            status: reader.string(json["status"]) ?? ""
        )
    }

    public func notify(from data: Data) throws -> NotifyResult {
        let json = try reader.object(data)
        guard let stopID = reader.string(json["stop_id"]) else {
            throw APIError.decoding("notify stop_id missing")
        }
        return NotifyResult(
            stopID: stopID,
            status: reader.string(json["status"]) ?? "failed",
            attempts: reader.int(json["attempts"]) ?? 1,
            detail: reader.string(json["reason"])
        )
    }

    public func errorCode(from data: Data) -> String? {
        guard let json = try? reader.object(data) else { return nil }
        return reader.string(json["error"])
    }
}
