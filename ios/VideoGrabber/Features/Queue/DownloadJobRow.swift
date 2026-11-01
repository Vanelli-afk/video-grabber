import SwiftUI

struct DownloadJobRow: View {
    let job: DownloadJob
    let canCancel: Bool
    let canRetry: Bool
    let onCancel: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: job.thumbnailURL.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(width: 80, height: 45)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(job.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                status
                if job.state.isInProgress {
                    ProgressView(value: job.progress)
                }
            }

            Spacer(minLength: 0)

            if canCancel {
                iconButton("xmark.circle.fill", label: "Cancelar", action: onCancel)
            } else if canRetry {
                iconButton("arrow.clockwise.circle.fill", label: "Tentar de novo", action: onRetry)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var status: some View {
        if job.state == .failed, let message = job.errorMessage {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        } else if job.state.isInProgress {
            Text(verbatim: "\(job.state.title) · \(Int(job.progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } else {
            Text(job.state.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func iconButton(_ systemImage: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}
