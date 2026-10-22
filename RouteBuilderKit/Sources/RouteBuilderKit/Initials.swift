import Foundation

public enum Initials {
    public static func make(from name: String) -> String {
        let articles: Set<String> = ["the", "a", "an"]
        var words = name
            .replacingOccurrences(of: "—", with: " ")
            .replacingOccurrences(of: "–", with: " ")
            .replacingOccurrences(of: "&", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map { token in
                String(token.filter { $0.isLetter || $0.isNumber || $0 == "/" })
            }
            .filter { !$0.isEmpty }

        while words.count > 1, let first = words.first, articles.contains(first.lowercased()) {
            words.removeFirst()
        }

        guard let first = words.first, let firstChar = first.first else { return "?" }
        if words.count >= 4 {
            words = Array(words.prefix(2))
        }
        if words.count == 1 {
            let extra = first.dropFirst().first.map(String.init) ?? ""
            return (String(firstChar) + extra).uppercased()
        }
        if words.count >= 3, words[1].allSatisfy(\.isNumber) {
            return (String(firstChar) + words[1]).uppercased()
        }
        let lastChar = words[words.count - 1].first.map(String.init) ?? ""
        return (String(firstChar) + lastChar).uppercased()
    }

    /// Section header. A leading non-letter ("24/7 Pharmacy") is grouped under "#".
    public static func sectionLetter(name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let character = trimmed.first else { return "#" }
        if character.isLetter {
            return String(character).uppercased()
        }
        return "#"
    }
}

public struct StopSection: Equatable, Sendable, Identifiable {
    public var letter: String
    public var stops: [Stop]
    public var id: String { letter }

    public init(letter: String, stops: [Stop]) {
        self.letter = letter
        self.stops = stops
    }
}

public enum StopGrouping {
    public static func sections(_ stops: [Stop]) -> [StopSection] {
        let sorted = stops.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        var order: [String] = []
        var buckets: [String: [Stop]] = [:]
        for stop in sorted {
            let letter = Initials.sectionLetter(name: stop.name)
            if buckets[letter] == nil {
                order.append(letter)
            }
            buckets[letter, default: []].append(stop)
        }
        order.sort { lhs, rhs in
            if lhs == "#" { return true }
            if rhs == "#" { return false }
            return lhs < rhs
        }
        return order.map { StopSection(letter: $0, stops: buckets[$0] ?? []) }
    }
}
