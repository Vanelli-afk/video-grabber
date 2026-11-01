import SwiftUI

struct AddLinkView: View {
    let dependencies: AppDependencies
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Adicionar vídeo",
                systemImage: "link",
                description: Text("Em breve: cole aqui um link do YouTube para baixar.")
            )
            .navigationTitle("Adicionar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Ajustes", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("add.settings")
                }
            }
            .navigationDestination(isPresented: $isShowingSettings) {
                SettingsView(viewModel: dependencies.makeSettingsViewModel())
            }
        }
    }
}
