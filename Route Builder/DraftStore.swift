import Foundation
import RouteBuilderKit

struct DraftStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = support.appendingPathComponent("RouteBuilder", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("draft.json")
    }

    func load() -> RouteDraft? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(RouteDraft.self, from: data)
    }

    func save(_ draft: RouteDraft) {
        guard let data = try? encoder.encode(draft) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    var photosDirectory: URL {
        let dir = fileURL.deletingLastPathComponent().appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
