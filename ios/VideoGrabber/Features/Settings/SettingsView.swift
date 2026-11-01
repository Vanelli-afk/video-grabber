import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section {
                TextField("Endereço do servidor", text: $viewModel.serverAddress, prompt: Text(verbatim: "http://192.168.0.10:8080"))
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { viewModel.save() }
                    .accessibilityIdentifier("settings.serverAddress")

                SecureField("Token de acesso", text: $viewModel.token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { viewModel.save() }
                    .accessibilityIdentifier("settings.token")
            } header: {
                Text("Servidor")
            } footer: {
                serverFooter
            }

            Section {
                Button {
                    Task { await viewModel.testConnection() }
                } label: {
                    HStack {
                        Text("Testar conexão")
                        Spacer()
                        statusIcon
                    }
                    .frame(minHeight: 44)
                }
                .disabled(!viewModel.canTestConnection)
                .accessibilityIdentifier("settings.testConnection")
            } footer: {
                statusFooter
            }

            Section("Download") {
                Picker("Qualidade padrão", selection: $viewModel.defaultPreset) {
                    ForEach(DownloadPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
            }

            Section("Aviso legal") {
                Text("Use o VideoGrabber apenas com conteúdo que você tem direito de baixar (próprio, licenciado ou com permissão). Baixar vídeos do YouTube pode violar os Termos de Serviço da plataforma e direitos autorais.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Ajustes")
        .onChange(of: viewModel.defaultPreset) { viewModel.save() }
        .onDisappear { viewModel.save() }
    }

    @ViewBuilder
    private var serverFooter: some View {
        if let message = viewModel.saveErrorMessage {
            Text(message).foregroundStyle(.red)
        } else if !viewModel.isServerAddressValid {
            Text("Endereço inválido. Exemplo: http://192.168.0.10:8080").foregroundStyle(.red)
        } else {
            Text("O token fica guardado no Keychain do iPhone.")
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch viewModel.status {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView()
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Conectado")
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel("Falha na conexão")
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        switch viewModel.status {
        case .connected(let version):
            Text("Conectado · yt-dlp \(version)")
                .accessibilityIdentifier("settings.status")
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
                .accessibilityIdentifier("settings.status")
        case .idle, .testing:
            EmptyView()
        }
    }
}
