import SwiftData
import SwiftUI

/// Lista simples dos vídeos baixados. Miniaturas, player e ações chegam na Fase 4.
struct LibraryView: View {
    @Query(sort: \VideoItem.createdAt, order: .reverse) private var videos: [VideoItem]

    var body: some View {
        NavigationStack {
            Group {
                if videos.isEmpty {
                    ContentUnavailableView(
                        "Biblioteca vazia",
                        systemImage: "play.rectangle.on.rectangle",
                        description: Text("Os vídeos baixados aparecem aqui.")
                    )
                } else {
                    List(videos) { video in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(video.title)
                                .font(.headline)
                                .lineLimit(2)
                            Text(verbatim: "\(video.channel) · \(Formatters.duration(video.durationSeconds)) · \(Formatters.byteCount(video.fileSizeBytes))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Biblioteca")
        }
    }
}
