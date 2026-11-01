import SwiftData
import SwiftUI

struct QueueView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Query(sort: \DownloadJob.createdAt, order: .reverse) private var jobs: [DownloadJob]

    var body: some View {
        NavigationStack {
            Group {
                if jobs.isEmpty {
                    ContentUnavailableView(
                        "Nenhum download",
                        systemImage: "arrow.down.circle",
                        description: Text("Os downloads em andamento aparecem aqui.")
                    )
                } else {
                    List(jobs) { job in
                        DownloadJobRow(
                            job: job,
                            canCancel: downloadManager.canCancel(job),
                            canRetry: downloadManager.canRetry(job),
                            onCancel: { downloadManager.cancel(job) },
                            onRetry: { downloadManager.retry(job) }
                        )
                        .swipeActions {
                            if job.state.isFinished {
                                Button("Remover", systemImage: "trash", role: .destructive) {
                                    downloadManager.remove(job)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fila")
        }
    }
}
