enum ConnectionStatus: Equatable {
    case idle
    case testing
    case connected(ytdlpVersion: String)
    case failed(message: String)
}
