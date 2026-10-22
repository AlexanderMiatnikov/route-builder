import Foundation

/// Client-side search rules.
///
/// The staging API matches `q` with a case-sensitive `String.includes`, so typing
/// "sova" or "north cafe" (the search field never auto-capitalizes) returns no
/// items even though "Sova Studio Gallery" / "North Cafe" exist. The app still
/// sends `q` exactly as typed, then unions the server answer with a
/// case/diacritic-insensitive match over the loaded directory.
public enum StopSearch {
    public static func matches(_ stop: Stop, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return false }
        if contains(stop.name, q) || contains(stop.address, q) { return true }
        let digits = q.filter(\.isNumber)
        // Same phone rule as the API: only when the query has 3+ digits.
        if digits.count >= 3 {
            return stop.phone.filter(\.isNumber).contains(digits)
        }
        return false
    }

    public static func filter(_ stops: [Stop], query: String) -> [Stop] {
        stops.filter { matches($0, query: query) }
    }

    /// Server results first (API order), then local-only matches; deduped by id.
    public static func combine(server: [Stop], local: [Stop]) -> [Stop] {
        var seen = Set<String>()
        return (server + local).filter { seen.insert($0.id).inserted }
    }

    private static func contains(_ text: String, _ query: String) -> Bool {
        text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
