import Foundation
import RouteBuilderKit
import SwiftUI

/// Camera behaviour injected into `CameraCapture` through the environment.
struct CameraCapabilities {
    var isSourceAvailable: (UIImagePickerController.SourceType) -> Bool = {
        UIImagePickerController.isSourceTypeAvailable($0)
    }
    var jpegQuality: CGFloat = 0.85
}

private struct CameraCapabilitiesKey: EnvironmentKey {
    static let defaultValue = CameraCapabilities(isSourceAvailable: { _ in false })
}

extension EnvironmentValues {
    var cameraCapabilities: CameraCapabilities {
        get { self[CameraCapabilitiesKey.self] }
        set { self[CameraCapabilitiesKey.self] = newValue }
    }
}

/// Composition root: the only place that wires concrete types together.
/// Order: APIConfig -> APIClient -> DirectoryLoader / RouteGateway ->
/// DraftStore -> DispatcherModel. Stateless helpers use property defaults;
/// only environment-dependent pieces are injected.
@MainActor
final class AppDependencies {
    let config: APIConfig
    private let session: URLSession
    private let storageDirectory: URL

    let search = StopSearch()
    let initials = Initials()
    let grouping = StopGrouping()
    let instructionRules = InstructionRules()
    let packageCount = PackageCount()
    let camera = CameraCapabilities()

    private(set) lazy var api: any Dispatching = APIClient(baseURL: config.baseURL, session: session)
    private(set) lazy var loader = DirectoryLoader(api: api)
    private(set) lazy var gateway = RouteGateway(api: api, rules: instructionRules)
    private(set) lazy var draftStore = DraftStore(directory: storageDirectory)

    init(
        config: APIConfig = APIConfig(),
        session: URLSession = .shared,
        storageDirectory: URL = AppDependencies.defaultStorageDirectory()
    ) {
        self.config = config
        self.session = session
        self.storageDirectory = storageDirectory
    }

    func makeDispatcherModel() -> DispatcherModel {
        DispatcherModel(
            api: api,
            loader: loader,
            gateway: gateway,
            draftStore: draftStore,
            search: search,
            grouping: grouping,
            initials: initials,
            instructionRules: instructionRules,
            packageCount: packageCount
        )
    }

    nonisolated static func defaultStorageDirectory() -> URL {
        let fileManager = FileManager.default
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return support.appendingPathComponent("RouteBuilder", isDirectory: true)
    }
}
