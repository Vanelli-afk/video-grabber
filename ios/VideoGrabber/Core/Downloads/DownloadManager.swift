import Foundation
import Observation
import os
import SwiftData

/// Núcleo dos downloads: cria o job no servidor, acompanha o preparo, baixa o arquivo
/// e cria o `VideoItem`. É o único lugar que muda o estado de um `DownloadJob`.
@MainActor
@Observable
final class DownloadManager {
    static let maxConcurrentDownloads = 2
    /// Parte do progresso total que corresponde ao preparo no servidor; o resto é a transferência.
    static let serverProgressWeight = 0.3

    private static let logger = Logger(subsystem: "com.vanelliafk.videograbber", category: "DownloadManager")
    private static let transitions: [DownloadState: Set<DownloadState>] = [
        .queued: [.resolving, .cancelled],
        .resolving: [.preparing, .failed, .cancelled],
        .preparing: [.downloading, .failed, .cancelled],
        .downloading: [.completed, .paused, .failed, .cancelled],
        .paused: [.downloading, .cancelled],
        .completed: [],
        .failed: [.queued],
        .cancelled: [.queued],
    ]

    static func isValidTransition(from current: DownloadState, to next: DownloadState) -> Bool {
        transitions[current]?.contains(next) ?? false
    }

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let apiClient: any APIClientProtocol
    @ObservationIgnored private let fileDownloader: any FileDownloading
    @ObservationIgnored private let videoStore: VideoStore
    @ObservationIgnored private let pollInterval: Duration
    @ObservationIgnored private let thumbnailLoader: @Sendable (URL) async throws -> Data
    @ObservationIgnored private var tasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var activeJobs: [UUID: DownloadJob] = [:]

    init(
        modelContext: ModelContext,
        apiClient: any APIClientProtocol,
        fileDownloader: any FileDownloading,
        videoStore: VideoStore,
        pollInterval: Duration = .milliseconds(1500),
        thumbnailLoader: @escaping @Sendable (URL) async throws -> Data
    ) {
        self.modelContext = modelContext
        self.apiClient = apiClient
        self.fileDownloader = fileDownloader
        self.videoStore = videoStore
        self.pollInterval = pollInterval
        self.thumbnailLoader = thumbnailLoader
        failInterruptedJobs()
        startQueuedJobs()
    }

    // MARK: - Ações

    @discardableResult
    func enqueue(_ video: ResolveResponse, sourceURL: String, presetID: String) -> DownloadJob {
        let job = DownloadJob(
            sourceURL: sourceURL,
            videoID: video.videoId,
            title: video.title,
            channel: video.channel,
            durationSeconds: video.durationSeconds,
            thumbnailURL: video.thumbnailUrl,
            presetID: presetID
        )
        modelContext.insert(job)
        save()
        startQueuedJobs()
        return job
    }

    func canCancel(_ job: DownloadJob) -> Bool {
        Self.isValidTransition(from: job.state, to: .cancelled)
    }

    func canRetry(_ job: DownloadJob) -> Bool {
        Self.isValidTransition(from: job.state, to: .queued)
    }

    func cancel(_ job: DownloadJob) {
        guard transition(job, to: .cancelled) else { return }
        tasks[job.id]?.cancel()
        deleteServerJob(of: job)
        save()
    }

    func retry(_ job: DownloadJob) {
        guard transition(job, to: .queued) else { return }
        job.progress = 0
        job.errorMessage = nil
        save()
        startQueuedJobs()
    }

    /// Tira um download terminado da fila (o vídeo baixado continua na Biblioteca).
    func remove(_ job: DownloadJob) {
        guard job.state.isFinished, tasks[job.id] == nil else { return }
        modelContext.delete(job)
        save()
    }

    // MARK: - Execução

    private func startQueuedJobs() {
        let queued = DownloadState.queued.rawValue
        let descriptor = FetchDescriptor<DownloadJob>(
            predicate: #Predicate { $0.stateRaw == queued },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let jobs = try? modelContext.fetch(descriptor) else { return }
        for job in jobs where tasks[job.id] == nil {
            guard tasks.count < Self.maxConcurrentDownloads else { return }
            let jobID = job.id
            activeJobs[jobID] = job
            tasks[jobID] = Task { [weak self] in
                await self?.run(jobID: jobID)
            }
        }
    }

    private func run(jobID: UUID) async {
        defer {
            tasks[jobID] = nil
            activeJobs[jobID] = nil
            startQueuedJobs()
        }
        guard let job = activeJobs[jobID] else { return }

        do {
            try advance(job, to: .resolving)
            let serverJobID = try await apiClient.createJob(url: job.sourceURL, presetID: job.presetID)
            job.serverJobID = serverJobID
            try advance(job, to: .preparing)
            save()

            try await waitUntilReady(job, serverJobID: serverJobID)
            try advance(job, to: .downloading)

            let request = try await apiClient.fileRequest(id: serverJobID)
            // Referência forte de propósito: o callback só vive enquanto dura este download.
            let downloadedFile = try await fileDownloader.download(request) { fraction in
                Task { @MainActor in self.updateTransferProgress(fraction, jobID: jobID) }
            }
            try await finish(job, downloadedFile: downloadedFile)
        } catch {
            handleFailure(error, job: job)
        }
    }

    private func waitUntilReady(_ job: DownloadJob, serverJobID: String) async throws {
        while true {
            let status = try await apiClient.jobStatus(id: serverJobID)
            switch status.status {
            case .ready:
                return
            case .failed:
                throw APIError(serverCode: status.errorCode ?? "", message: status.errorMessage ?? "")
            case .queued, .preparing:
                job.progress = status.progress * Self.serverProgressWeight
                try await Task.sleep(for: pollInterval)
            }
        }
    }

    private func updateTransferProgress(_ fraction: Double, jobID: UUID) {
        guard let job = activeJobs[jobID], job.state == .downloading else { return }
        let total = Self.serverProgressWeight + (1 - Self.serverProgressWeight) * min(max(fraction, 0), 1)
        // Atualiza de 1 em 1% para não redesenhar a fila a cada pedaço recebido.
        if total - job.progress >= 0.01 || fraction >= 1 {
            job.progress = total
        }
    }

    private func finish(_ job: DownloadJob, downloadedFile: URL) async throws {
        try Task.checkCancellation()
        let fileExtension = job.presetID == DownloadPreset.audioM4A.rawValue ? "m4a" : "mp4"
        let stored = try videoStore.importVideo(from: downloadedFile, fileExtension: fileExtension)
        let itemID = UUID()
        let thumbnailFileName = await saveThumbnail(from: job.thumbnailURL, itemID: itemID)

        guard transition(job, to: .completed) else {
            // Cancelado enquanto a miniatura baixava.
            videoStore.deleteFiles(videoFileName: stored.fileName, thumbnailFileName: thumbnailFileName)
            throw CancellationError()
        }
        modelContext.insert(VideoItem(
            id: itemID,
            videoID: job.videoID,
            title: job.title,
            channel: job.channel,
            durationSeconds: job.durationSeconds,
            presetID: job.presetID,
            fileName: stored.fileName,
            fileSizeBytes: stored.sizeBytes,
            thumbnailFileName: thumbnailFileName
        ))
        job.progress = 1
        deleteServerJob(of: job)
        save()
    }

    private func saveThumbnail(from urlString: String?, itemID: UUID) async -> String? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        do {
            let data = try await thumbnailLoader(url)
            return try videoStore.saveThumbnail(data, id: itemID)
        } catch {
            Self.logger.notice("Miniatura indisponível: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func handleFailure(_ error: Error, job: DownloadJob) {
        // Cancelado pelo usuário: `cancel` já cuidou do estado.
        guard job.state != .cancelled, !(error is CancellationError) else { return }
        let jobID = job.id.uuidString
        Self.logger.error("Download \(jobID, privacy: .public) falhou: \(String(describing: error), privacy: .public)")
        let apiError = (error as? APIError) ?? (error as? URLError).map(APIError.init(urlError:)) ?? .unknown
        guard transition(job, to: .failed) else { return }
        job.errorMessage = apiError.localizedDescription
        deleteServerJob(of: job)
        save()
    }

    /// Ao abrir o app, downloads que estavam no meio não têm mais tarefa: viram "falhou".
    private func failInterruptedJobs() {
        let interrupted = Set([DownloadState.resolving, .preparing, .downloading].map(\.rawValue))
        guard let jobs = try? modelContext.fetch(FetchDescriptor<DownloadJob>()) else { return }
        for job in jobs where interrupted.contains(job.stateRaw) {
            transition(job, to: .failed)
            job.errorMessage = String(localized: "O download foi interrompido. Toque em Tentar de novo.")
            deleteServerJob(of: job)
        }
        save()
    }

    // MARK: - Auxiliares

    private func advance(_ job: DownloadJob, to state: DownloadState) throws {
        try Task.checkCancellation()
        guard transition(job, to: state) else { throw CancellationError() }
    }

    @discardableResult
    private func transition(_ job: DownloadJob, to state: DownloadState) -> Bool {
        guard Self.isValidTransition(from: job.state, to: state) else {
            let current = job.state.rawValue
            Self.logger.notice("Transição ignorada: \(current, privacy: .public) → \(state.rawValue, privacy: .public)")
            return false
        }
        job.state = state
        return true
    }

    /// O servidor também apaga sozinho depois do TTL; aqui é só para liberar espaço antes.
    private func deleteServerJob(of job: DownloadJob) {
        guard let serverJobID = job.serverJobID else { return }
        job.serverJobID = nil
        let apiClient = apiClient
        Task {
            do {
                try await apiClient.deleteJob(id: serverJobID)
            } catch {
                Self.logger.notice("Não foi possível apagar o job \(serverJobID, privacy: .public) no servidor")
            }
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Falha ao salvar: \(error.localizedDescription, privacy: .public)")
        }
    }
}
