import SwiftUI

@main
struct VideoGrabberApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .environment(dependencies.downloadManager)
                .modelContainer(dependencies.modelContainer)
        }
    }
}
