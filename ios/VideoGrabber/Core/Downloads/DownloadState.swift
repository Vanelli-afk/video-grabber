import Foundation

/// Estados de um `DownloadJob`. As transições válidas ficam só no `DownloadManager`.
enum DownloadState: String, CaseIterable, Sendable {
    case queued
    case resolving
    case preparing
    case downloading
    case paused
    case completed
    case failed
    case cancelled

    var isInProgress: Bool {
        switch self {
        case .queued, .resolving, .preparing, .downloading, .paused: true
        case .completed, .failed, .cancelled: false
        }
    }

    var isFinished: Bool { !isInProgress }

    var title: String {
        switch self {
        case .queued: String(localized: "Na fila")
        case .resolving: String(localized: "Enviando ao servidor")
        case .preparing: String(localized: "Preparando no servidor")
        case .downloading: String(localized: "Baixando")
        case .paused: String(localized: "Pausado")
        case .completed: String(localized: "Concluído")
        case .failed: String(localized: "Falhou")
        case .cancelled: String(localized: "Cancelado")
        }
    }
}
