import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        @Bindable var router = dependencies.router

        TabView(selection: $router.selectedTab) {
            AddLinkView(dependencies: dependencies)
                .tabItem { Label("Adicionar", systemImage: "plus.circle") }
                .tag(AppRouter.Tab.add)

            QueueView()
                .tabItem { Label("Fila", systemImage: "arrow.down.circle") }
                .tag(AppRouter.Tab.queue)

            LibraryView()
                .tabItem { Label("Biblioteca", systemImage: "play.rectangle.on.rectangle") }
                .tag(AppRouter.Tab.library)
        }
    }
}
