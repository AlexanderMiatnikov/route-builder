import Foundation

enum JSONValue {
    static func object(_ data: Data) throws -> [String: Any] {
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let object = raw as? [String: Any] else {
            throw APIError.decoding("root was not an object")
        }
        return object
    }

    static func int(_ value: Any?) -> Int? {
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

    static func string(_ value: Any?) -> String? {
        if value == nil || value is NSNull { return nil }
        if let string = value as? String { return string }
        return nil
    }

    static func bool(_ value: Any?) -> Bool? {
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    static func date(_ value: Any?) -> Date? {
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

public enum StopPageParser {
    public static func page(from data: Data) throws -> StopPage {
        let json = try JSONValue.object(data)
        let items = stops(from: json["items"])
        return StopPage(
            items: items,
            page: JSONValue.int(json["page"]) ?? 1,
            pageSize: JSONValue.int(json["page_size"]) ?? items.count,
            hasMore: JSONValue.bool(json["has_more"]) ?? false
        )
    }

    public static func stops(from value: Any?) -> [Stop] {
        if value == nil || value is NSNull { return [] }
        guard let rows = value as? [Any] else { return [] }
        return rows.compactMap { row in
            guard let object = row as? [String: Any] else { return nil }
            return stop(from: object)
        }
    }

    public static func stop(from json: [String: Any]) -> Stop? {
        guard let id = JSONValue.string(json["id"]), !id.isEmpty else { return nil }
        return Stop(
            id: id,
            name: JSONValue.string(json["name"]) ?? "Unknown stop",
            address: JSONValue.string(json["address"]) ?? "",
            phone: JSONValue.string(json["phone"]) ?? "",
            zone: JSONValue.string(json["zone"]),
            packagesMax: JSONValue.int(json["packages_max"]),
            lastDeliveryAt: JSONValue.date(json["last_delivery_at"]),
            notes: JSONValue.string(json["notes"]),
            isLocal: JSONValue.bool(json["isLocal"]) ?? false
        )
    }
}

public enum PhotoParser {
    public static func photos(from data: Data) throws -> [DeliveryPhoto] {
        let json = try JSONValue.object(data)
        let raw = json["items"]
        if raw == nil || raw is NSNull { return [] }
        guard let rows = raw as? [Any] else { return [] }
        return rows.compactMap { row in
            guard let object = row as? [String: Any] else { return nil }
            guard let id = JSONValue.string(object["id"]), !id.isEmpty else { return nil }
            guard let urlString = JSONValue.string(object["url"]), let url = URL(string: urlString) else { return nil }
            return DeliveryPhoto(
                id: id,
                url: url,
                tag: JSONValue.string(object["tag"]) ?? "",
                width: JSONValue.int(object["width"]),
                height: JSONValue.int(object["height"])
            )
        }
    }
}

public enum RouteResponseParser {
    public static func created(from data: Data) throws -> CreatedRoute {
        let json = try JSONValue.object(data)
        guard let id = JSONValue.string(json["id"]), !id.isEmpty else {
            throw APIError.decoding("route id missing")
        }
        let stops = (json["stops"] as? [Any] ?? []).compactMap { row -> RouteStopPayload? in
            guard let object = row as? [String: Any] else { return nil }
            guard let stopID = JSONValue.string(object["stop_id"]) else { return nil }
            return RouteStopPayload(
                stopID: stopID,
                packages: JSONValue.int(object["packages"]) ?? 1,
                instructions: JSONValue.string(object["instructions"]) ?? ""
            )
        }
        return CreatedRoute(
            id: id,
            stops: stops,
            status: JSONValue.string(json["status"]) ?? ""
        )
    }

    public static func notify(from data: Data) throws -> NotifyResult {
        let json = try JSONValue.object(data)
        guard let stopID = JSONValue.string(json["stop_id"]) else {
            throw APIError.decoding("notify stop_id missing")
        }
        return NotifyResult(
            stopID: stopID,
            status: JSONValue.string(json["status"]) ?? "failed",
            attempts: JSONValue.int(json["attempts"]) ?? 1,
            detail: JSONValue.string(json["reason"])
        )
    }

    public static func errorCode(from data: Data) -> String? {
        guard let json = try? JSONValue.object(data) else { return nil }
        return JSONValue.string(json["error"])
    }
}
