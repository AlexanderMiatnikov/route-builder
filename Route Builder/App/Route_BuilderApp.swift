import SwiftUI

@main
struct Route_BuilderApp: App {
    private let dependencies: AppDependencies
    @State private var model: DispatcherModel

    init() {
        let dependencies = AppDependencies()
        self.dependencies = dependencies
        self._model = State(initialValue: dependencies.makeDispatcherModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .environment(\.cameraCapabilities, dependencies.camera)
                .preferredColorScheme(.light)
        }
    }
}
