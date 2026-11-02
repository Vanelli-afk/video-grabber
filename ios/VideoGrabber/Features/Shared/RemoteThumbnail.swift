import SwiftUI

/// Miniatura 16:9 carregada da internet, com um retângulo neutro enquanto carrega (ou se falhar).
struct RemoteThumbnail: View {
    let url: URL?
    let width: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle().fill(.quaternary)
        }
        .frame(width: width, height: width * 9 / 16)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
    }
}
