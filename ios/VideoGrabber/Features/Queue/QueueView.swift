import SwiftUI

struct QueueView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Nenhum download",
                systemImage: "arrow.down.circle",
                description: Text("Os downloads em andamento aparecem aqui.")
            )
            .navigationTitle("Fila")
        }
    }
}
