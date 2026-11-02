import SwiftUI

struct AddLinkView: View {
    let dependencies: AppDependencies
    @Bindable private var viewModel: AddLinkViewModel
    @State private var isShowingSettings = false
    /// Criado só ao tocar na engrenagem (lê o Keychain), não a cada redesenho.
    @State private var settingsViewModel: SettingsViewModel?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        viewModel = dependencies.addLinkViewModel
    }

    var body: some View {
        NavigationStack {
            Form {
                linkSection

                switch viewModel.state {
                case .idle:
                    EmptyView()
                case .resolving:
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Buscando informações do vídeo…")
                        }
                    }
                case .failed(let message):
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Button("Tentar de novo") {
                            Task { await viewModel.search() }
                        }
                    }
                case .resolved(let video, _):
                    videoSection(video)
                    presetSection(video)
                    Section {
                        Button {
                            viewModel.download()
                        } label: {
                            Label("Baixar", systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowInsets(EdgeInsets())
                        .accessibilityIdentifier("add.download")
                    }
                }
            }
            .navigationTitle("Adicionar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        settingsViewModel = dependencies.makeSettingsViewModel()
                        isShowingSettings = true
                    } label: {
                        Label("Ajustes", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("add.settings")
                }
            }
            .navigationDestination(isPresented: $isShowingSettings) {
                if let settingsViewModel {
                    SettingsView(viewModel: settingsViewModel)
                }
            }
        }
    }

    private var linkSection: some View {
        Section {
            TextField("Link do YouTube", text: $viewModel.urlText, prompt: Text(verbatim: "https://youtu.be/…"))
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.search() } }
                .accessibilityIdentifier("add.url")

            HStack {
                PasteButton(payloadType: String.self) { strings in
                    guard let text = strings.first else { return }
                    Task { @MainActor in viewModel.paste(text) }
                }
                .buttonBorderShape(.capsule)

                Spacer()

                Button {
                    Task { await viewModel.search() }
                } label: {
                    Text("Buscar").frame(minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSearch)
                .accessibilityIdentifier("add.search")
            }
            .buttonStyle(.borderless)
        } footer: {
            if viewModel.showsInvalidLinkHint {
                Text("Cole um link de vídeo do YouTube (youtube.com ou youtu.be).")
                    .foregroundStyle(.red)
            }
        }
    }

    private func videoSection(_ video: ResolveResponse) -> some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                RemoteThumbnail(url: video.thumbnail, width: 120, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(3)
                    Text(video.channel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Formatters.duration(video.durationSeconds))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func presetSection(_ video: ResolveResponse) -> some View {
        Section("Qualidade") {
            Picker("Qualidade", selection: $viewModel.selectedPresetID) {
                ForEach(video.presets) { preset in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.label)
                        if let bytes = preset.estimatedBytes {
                            Text("≈ \(Formatters.byteCount(bytes))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(preset.id)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }
}
