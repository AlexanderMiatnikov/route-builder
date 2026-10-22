public enum PageMerge {
    public static func merge(
        existing: [Stop],
        page: StopPage
    ) -> (items: [Stop], added: Int) {
        var seen = Set(existing.map(\.id))
        var items = existing
        var added = 0
        for stop in page.items where seen.insert(stop.id).inserted {
            items.append(stop)
            added += 1
        }
        return (items, added)
    }
}

public struct DirectoryLoader: Sendable {
    private let api: any Dispatching

    public init(api: any Dispatching) {
        self.api = api
    }

    public func load(pageSize: Int, query: String?) async throws -> [Stop] {
        var items: [Stop] = []
        var pageNumber = 1

        while true {
            let page = try await api.fetchStops(
                page: pageNumber,
                pageSize: pageSize,
                query: query
            )
            let merged = PageMerge.merge(existing: items, page: page)
            items = merged.items

            guard page.hasMore, merged.added > 0 else { return items }
            pageNumber += 1
        }
    }
}
