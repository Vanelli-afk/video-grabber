import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Biblioteca vazia",
                systemImage: "play.rectangle.on.rectangle",
                description: Text("Os vídeos baixados aparecem aqui.")
            )
            .navigationTitle("Biblioteca")
        }
    }
}
