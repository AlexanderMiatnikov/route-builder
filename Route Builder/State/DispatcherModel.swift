import Foundation
import Observation
import RouteBuilderKit
import SwiftUI

enum SelectionMode: String, Codable {
    case oneStop
    case multiStop
}

enum AppTab: Hashable {
    case stops
    case instructions
}

enum SubmitPhase: Equatable {
    case idle
    case sending
    case success(routeID: String, notifies: [NotifyResult])
    case failure(String)
}

struct SelectedStop: Identifiable, Equatable {
    var stop: Stop
    var packages: Int
    var instructions: String
    var photoPath: String?
    var showInstructionError: Bool

    var id: String { stop.id }

    init(stop: Stop, packages: Int = 1, instructions: String = "", photoPath: String? = nil, showInstructionError: Bool = false) {
        self.stop = stop
        self.packages = packages
        self.instructions = instructions
        self.photoPath = photoPath
        self.showInstructionError = showInstructionError
    }
}

struct UndoToken: Equatable {
    var item: SelectedStop
    var index: Int
    var expiresAt: Date
}

@MainActor
@Observable
final class DispatcherModel {
    var mode: SelectionMode = .oneStop
    var tab: AppTab = .stops
    var searchText = ""
    var directory: [Stop] = []
    var searchResults: [Stop]?
    var isLoadingDirectory = false
    var isSearching = false
    var directoryError: String?
    var selected: [SelectedStop] = []
    var submitPhase: SubmitPhase = .idle
    var undo: UndoToken?
    var photosByStop: [String: [DeliveryPhoto]] = [:]

    let initials: Initials
    let packageCount: PackageCount
    let instructionRules: InstructionRules

    private let api: any Dispatching
    private let loader: DirectoryLoader
    private let gateway: RouteGateway
    private let draftStore: DraftStore
    private let search: StopSearch
    private let grouping: StopGrouping
    private var searchTask: Task<Void, Never>?
    private var undoTask: Task<Void, Never>?

    init(
        api: any Dispatching,
        loader: DirectoryLoader,
        gateway: RouteGateway,
        draftStore: DraftStore,
        search: StopSearch,
        grouping: StopGrouping,
        initials: Initials,
        instructionRules: InstructionRules,
        packageCount: PackageCount
    ) {
        self.api = api
        self.loader = loader
        self.gateway = gateway
        self.draftStore = draftStore
        self.search = search
        self.grouping = grouping
        self.initials = initials
        self.instructionRules = instructionRules
        self.packageCount = packageCount
        if let draft = draftStore.load() {
            apply(draft: draft)
        }
    }

    var displayedStops: [Stop] {
        if let searchResults { return searchResults }
        return directory
    }

    var sections: [StopSection] {
        grouping.sections(displayedStops)
    }

    var isSearchingActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var packageTotal: Int {
        selected.reduce(0) { $0 + $1.packages }
    }

    var subtitle: String {
        if selected.isEmpty {
            let n = directory.count
            return n == 1 ? "1 stop in the book" : "\(n) stops in the book"
        }
        let p = packageTotal
        let n = selected.count
        let packages = p == 1 ? "1 package" : "\(p) packages"
        let stops = n == 1 ? "1 stop" : "\(n) stops"
        return "\(packages) | \(stops)"
    }

    var canContinue: Bool { !selected.isEmpty }

    func bootstrap() async {
        await loadDirectory()
    }

    func loadDirectory() async {
        isLoadingDirectory = true
        directoryError = nil
        do {
            let items = try await loader.load(pageSize: 50, query: nil)
            directory = items
        } catch {
            directoryError = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
        isLoadingDirectory = false
    }

    func updateSearch(_ text: String) {
        searchText = text
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = nil
            isSearching = false
            return
        }
        isSearching = true
        // Instant, case-insensitive answer from the loaded directory; the API
        // (case-sensitive) result is merged in after the debounce.
        searchResults = search.filter(directory, query: trimmed)
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            let server: [Stop]
            do {
                server = try await loader.load(pageSize: 50, query: trimmed)
            } catch {
                server = []
            }
            guard !Task.isCancelled else { return }
            searchResults = search.combine(
                server: server,
                local: search.filter(directory, query: trimmed)
            )
            isSearching = false
        }
    }

    func setMode(_ newMode: SelectionMode) {
        mode = newMode
        if newMode == .oneStop, selected.count > 1 {
            selected = Array(selected.prefix(1))
        }
        persist()
    }

    func isSelected(_ stop: Stop) -> Bool {
        selected.contains { $0.id == stop.id }
    }

    func packages(for stop: Stop) -> Int {
        selected.first { $0.id == stop.id }?.packages ?? 1
    }

    func toggle(_ stop: Stop) {
        if let index = selected.firstIndex(where: { $0.id == stop.id }) {
            selected.remove(at: index)
        } else {
            let item = SelectedStop(stop: stop, packages: 1)
            if mode == .oneStop {
                selected = [item]
            } else {
                selected.append(item)
            }
        }
        persist()
    }

    func setPackages(stopID: String, value: Int) {
        guard let index = selected.firstIndex(where: { $0.id == stopID }) else { return }
        let maxAllowed = selected[index].stop.packagesMax
        selected[index].packages = packageCount.clamp(value, max: maxAllowed)
        persist()
    }

    func removeSelected(stopID: String) {
        selected.removeAll { $0.id == stopID }
        if selected.isEmpty { tab = .stops }
        persist()
    }

    func addManualStop(name: String, address: String, phone: String) {
        let stop = Stop(
            id: "local_" + UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Custom stop"
                : name.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            isLocal: true
        )
        let item = SelectedStop(stop: stop)
        if mode == .oneStop {
            selected = [item]
        } else if !selected.contains(where: { $0.id == stop.id }) {
            selected.append(item)
        }
        searchText = ""
        searchResults = nil
        persist()
    }

    func goToInstructions() {
        guard canContinue else { return }
        tab = .instructions
    }

    func setInstructions(stopID: String, text: String) {
        guard let index = selected.firstIndex(where: { $0.id == stopID }) else { return }
        let clipped = instructionRules.clip(text)
        selected[index].instructions = clipped
        if !instructionRules.isEmpty(clipped) {
            selected[index].showInstructionError = false
        }
        persist()
    }

    func clearInstructions(stopID: String) {
        setInstructions(stopID: stopID, text: "")
    }

    func setLocalPhoto(stopID: String, path: String?) {
        guard let index = selected.firstIndex(where: { $0.id == stopID }) else { return }
        selected[index].photoPath = path
        persist()
    }

    func removeFromRoute(stopID: String) {
        guard let index = selected.firstIndex(where: { $0.id == stopID }) else { return }
        let item = selected[index]
        selected.remove(at: index)
        undo = UndoToken(item: item, index: min(index, selected.count), expiresAt: Date().addingTimeInterval(5))
        undoTask?.cancel()
        undoTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if undo?.item.id == item.id {
                undo = nil
            }
        }
        if selected.isEmpty {
            tab = .stops
            submitPhase = .idle
        }
        persist()
    }

    func undoRemove() {
        guard let token = undo else { return }
        let insertAt = min(token.index, selected.count)
        selected.insert(token.item, at: insertAt)
        undo = nil
        undoTask?.cancel()
        persist()
    }

    func loadPhotosIfNeeded(for stop: Stop) async {
        guard !stop.isLocal else { return }
        if photosByStop[stop.id] != nil { return }
        do {
            photosByStop[stop.id] = try await api.fetchPhotos(stopID: stop.id)
        } catch {
            photosByStop[stop.id] = []
        }
    }

    @discardableResult
    func validateInstructions() -> String? {
        var firstBad: String?
        for index in selected.indices {
            if instructionRules.isEmpty(selected[index].instructions) {
                selected[index].showInstructionError = true
                if firstBad == nil { firstBad = selected[index].id }
            } else {
                selected[index].showInstructionError = false
            }
        }
        return firstBad
    }

    func finish() async {
        if case .sending = submitPhase { return }
        if case .success = submitPhase { return }
        guard validateInstructions() == nil else { return }

        submitPhase = .sending
        let payload = selected.map {
            RouteStopPayload(stopID: $0.stop.id, packages: $0.packages, instructions: $0.instructions)
        }
        do {
            let route = try await gateway.submit(payload)
            let notifies = await gateway.notifyDriver(
                routeID: route.id,
                stopIDs: payload.map(\.stopID)
            )
            submitPhase = .success(routeID: route.id, notifies: notifies)
        } catch {
            let message = (error as? APIError)?.userMessage ?? error.localizedDescription
            submitPhase = .failure(message)
        }
    }

    func startAnotherRoute() {
        selected = []
        submitPhase = .idle
        tab = .stops
        undo = nil
        draftStore.clear()
        persist()
    }

    func savePhotoJPEG(_ data: Data, stopID: String) -> String? {
        let url = draftStore.photosDirectory.appendingPathComponent("\(stopID).jpg")
        do {
            try data.write(to: url, options: .atomic)
            setLocalPhoto(stopID: stopID, path: url.path)
            return url.path
        } catch {
            return nil
        }
    }

    private func persist() {
        let draft = RouteDraft(
            mode: mode.rawValue,
            stops: selected.map {
                DraftStop(
                    stop: $0.stop,
                    packages: $0.packages,
                    instructions: $0.instructions,
                    photoPath: $0.photoPath
                )
            }
        )
        draftStore.save(draft)
    }

    private func apply(draft: RouteDraft) {
        mode = SelectionMode(rawValue: draft.mode) ?? .oneStop
        selected = draft.stops.map {
            SelectedStop(
                stop: $0.stop,
                packages: packageCount.clamp($0.packages, max: $0.stop.packagesMax),
                instructions: instructionRules.clip($0.instructions),
                photoPath: $0.photoPath
            )
        }
    }
}
