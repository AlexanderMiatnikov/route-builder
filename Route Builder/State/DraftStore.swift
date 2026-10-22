import Foundation
import RouteBuilderKit

/// Persists the in-progress route. The storage directory and file manager are
/// injected, so tests can point it at a temporary directory.
final class DraftStore {
    private let fileURL: URL
    private let photosURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("draft.json")
        self.photosURL = directory.appendingPathComponent("photos", isDirectory: true)
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
        try? fileManager.removeItem(at: fileURL)
    }

    var photosDirectory: URL {
        try? fileManager.createDirectory(at: photosURL, withIntermediateDirectories: true)
        return photosURL
    }
}
