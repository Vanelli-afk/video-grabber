# PROMPT PARA CLAUDE CODE — App iOS "Baixador de Vídeos" (SwiftUI + Backend yt-dlp)

> Cole este documento inteiro como primeira mensagem no Claude Code, na raiz de uma pasta vazia, em um Mac com Xcode instalado.
> Salve também o conteúdo das seções 1 a 9 como `CLAUDE.md` na raiz do projeto, para o agente consultar em toda sessão.

---

## 0. PAPEL E MODO DE TRABALHO

Você é um engenheiro iOS sênior com experiência em backend Python. Vai implementar, do zero, um projeto completo composto por:

1. **App iOS nativo** (SwiftUI) que recebe um link do YouTube, mostra as opções de download, baixa o arquivo e o guarda numa biblioteca local.
2. **Backend próprio** (Python + FastAPI + yt-dlp + ffmpeg) que resolve o link e prepara o arquivo. O app iOS **não** extrai nada sozinho.

Regras de trabalho:

- Trabalhe **por fases** (seção 8). Ao final de cada fase: compile, rode os testes, faça um commit com mensagem clara e só então avance.
- **Não peça confirmação** para decisões já definidas neste documento. Pergunte apenas se houver bloqueio real (ex.: Xcode ausente, conflito de versão).
- Prefira **soluções simples e legíveis**. Não adicione dependências, camadas ou abstrações que este documento não pede.
- Se algo não estiver especificado, escolha a opção mais simples e registre a decisão em `docs/DECISIONS.md` (uma linha por decisão).
- Nunca invente APIs. Em caso de dúvida sobre uma API do Swift/iOS/yt-dlp, consulte a documentação oficial antes de escrever o código.

---

## 1. OBJETIVO E ESCOPO

### Objetivo
Permitir que o usuário cole (ou compartilhe) um link do YouTube no iPhone, escolha a qualidade e tenha o vídeo/áudio salvo no aparelho, com biblioteca e player integrados.

### Dentro do escopo (MVP)
- Colar URL ou receber via Share Sheet (Share Extension) a partir do Safari/app do YouTube.
- Resolver metadados: título, miniatura, duração, canal e formatos disponíveis.
- Três presets de download: **Melhor qualidade (MP4 até 1080p)**, **720p (MP4)** e **Somente áudio (M4A)**.
- Fila de downloads com progresso, cancelar, pausar/retomar e retentativa.
- Downloads continuam com o app em segundo plano (background `URLSession`).
- Biblioteca local com miniatura, título, tamanho e duração; apagar itens.
- Player nativo (AVKit), com Picture-in-Picture e reprodução de áudio em segundo plano.
- Salvar no Rolo da Câmera (Fotos) e exportar via Share Sheet / app Arquivos.
- Tela de Configurações: URL do servidor, token de acesso, preset padrão, botão "Testar conexão".

### Fora do escopo (NÃO implementar)
- Contas de usuário, login, nuvem, sincronização, pagamentos, analytics.
- Download de playlists, canais, lives ou conteúdo protegido por DRM.
- Qualquer forma de contornar DRM ou restrições de acesso (conteúdo privado, com login ou pago).
- iPadOS/macOS/Android. **Apenas iPhone, iOS 17+.**
- Publicação na App Store (ver seção 9).

---

## 2. DECISÃO ARQUITETURAL CENTRAL (leia antes de codar)

O iOS não permite executar `yt-dlp`/Python nem processos externos dentro do app. Por isso a arquitetura é **cliente-servidor**:

```
┌────────────────────────┐        HTTPS + Bearer token        ┌──────────────────────────────┐
│       App iOS          │ ─────────────────────────────────▶ │  Backend (Docker)            │
│  SwiftUI · iOS 17+     │   POST /v1/resolve                 │  FastAPI + yt-dlp + ffmpeg   │
│                        │   POST /v1/jobs                    │                              │
│  - Fila de downloads   │   GET  /v1/jobs/{id}               │  - Resolve metadados         │
│  - Biblioteca          │   GET  /v1/jobs/{id}/file (Range)  │  - Baixa + remuxa p/ MP4/M4A │
│  - Player              │ ◀───────────────────────────────── │  - Serve o arquivo final     │
│  - Share Extension     │      arquivo final (URLSession bg) │  - Limpeza automática (TTL)  │
└────────────────────────┘                                    └──────────────────────────────┘
```

Fluxo de um download:
1. App envia a URL → `POST /v1/resolve` → recebe metadados e presets disponíveis.
2. Usuário escolhe o preset → `POST /v1/jobs` → recebe `job_id`.
3. App consulta `GET /v1/jobs/{id}` (polling a cada 1,5 s) até `status = ready`, exibindo o progresso de preparo no servidor.
4. App baixa `GET /v1/jobs/{id}/file` com `URLSession` em **background**, mostrando o progresso de transferência.
5. App move o arquivo para o armazenamento local, gera o registro na biblioteca e notifica o backend (`DELETE /v1/jobs/{id}`) para limpar o arquivo.

O servidor é de uso **pessoal**: o usuário roda no próprio Mac/PC/VPS. Não há multiusuário.

---

## 3. STACK E VERSÕES

| Camada | Tecnologia |
|---|---|
| Linguagem iOS | Swift 6 (modo de concorrência estrita onde viável; use `async/await` e `actor`) |
| UI | SwiftUI, iOS 17+, `NavigationStack`, `@Observable` |
| Persistência | SwiftData |
| Rede | `URLSession` (sem Alamofire) |
| Mídia | AVKit / AVFoundation |
| Geração do projeto | **XcodeGen** (`project.yml`) — o projeto `.xcodeproj` é gerado, não escrito à mão |
| Dependências iOS | **Nenhuma** de terceiros |
| Backend | Python 3.12, FastAPI, Uvicorn, `yt-dlp` (versão fixada em `requirements.txt`), ffmpeg |
| Backend infra | Docker + docker-compose |
| Testes iOS | Swift Testing (`import Testing`) para unidade; XCUITest mínimo para o fluxo principal |
| Testes backend | pytest + httpx (com `yt-dlp` mockado) |

Pré-requisitos (verifique no início e relate o que faltar): `xcodebuild -version`, `xcodegen --version` (instale via `brew install xcodegen` se ausente), `docker --version`, `python3 --version`.

---

## 4. ESTRUTURA DE PASTAS

```
.
├── CLAUDE.md
├── README.md
├── docs/
│   ├── DECISIONS.md
│   └── API.md                      # contrato do backend (fonte da verdade)
├── backend/
│   ├── app/
│   │   ├── main.py                 # criação do FastAPI, rotas, auth
│   │   ├── config.py               # variáveis de ambiente (pydantic-settings)
│   │   ├── models.py               # schemas pydantic
│   │   ├── services/
│   │   │   ├── resolver.py         # yt-dlp: extrair metadados
│   │   │   ├── downloader.py       # yt-dlp: baixar + remux
│   │   │   └── jobs.py             # registro de jobs em memória + TTL
│   │   └── security.py             # validação do Bearer token
│   ├── tests/
│   ├── requirements.txt
│   ├── Dockerfile
│   └── docker-compose.yml
└── ios/
    ├── project.yml                 # XcodeGen
    ├── VideoGrabber/               # target do app
    │   ├── App/                    # VideoGrabberApp.swift, AppRouter
    │   ├── Core/
    │   │   ├── Networking/         # APIClient, Endpoints, APIError
    │   │   ├── Downloads/          # DownloadManager, DownloadTask, BackgroundSession
    │   │   ├── Persistence/        # modelos SwiftData, VideoStore
    │   │   ├── Media/              # PhotosSaver, ThumbnailCache
    │   │   └── Settings/           # AppSettings (UserDefaults), KeychainStore
    │   ├── Features/
    │   │   ├── Add/                # AddLinkView + AddLinkViewModel
    │   │   ├── Queue/              # QueueView + QueueViewModel
    │   │   ├── Library/            # LibraryView + LibraryViewModel
    │   │   ├── Player/             # PlayerView
    │   │   └── Settings/           # SettingsView + SettingsViewModel
    │   └── Resources/              # Assets, Info.plist entries
    ├── VideoGrabberShare/          # target da Share Extension
    └── VideoGrabberTests/
```

Convenções:
- **MVVM** simples: uma `View` + um `@Observable ViewModel` por feature. Views não falam com rede/disco diretamente.
- Tudo que toca rede, disco ou Fotos fica em `Core/` atrás de protocolos pequenos, para permitir mocks nos testes.
- Um tipo por arquivo; nomes em inglês no código, textos de interface em **português do Brasil** (usar `String(localized:)` / String Catalog).
- Sem `print` em código final: use `os.Logger`.
- Sem força de unwrap (`!`) fora de testes.

---

## 5. CONTRATO DA API DO BACKEND

Crie `docs/API.md` com este contrato e implemente exatamente assim. Todas as rotas exigem o header `Authorization: Bearer <TOKEN>` (exceto `/health`).

### `GET /health`
`200` → `{ "status": "ok", "ytdlp_version": "2025.xx.xx" }`

### `POST /v1/resolve`
Body: `{ "url": "https://www.youtube.com/watch?v=..." }`
`200` →
```json
{
  "video_id": "string",
  "title": "string",
  "channel": "string",
  "duration_seconds": 213,
  "thumbnail_url": "https://...",
  "presets": [
    { "id": "best_mp4",   "label": "Melhor qualidade (até 1080p)", "kind": "video", "estimated_bytes": 123456789 },
    { "id": "mp4_720",    "label": "720p",                          "kind": "video", "estimated_bytes": 54000000 },
    { "id": "audio_m4a",  "label": "Somente áudio (M4A)",           "kind": "audio", "estimated_bytes": 4500000 }
  ]
}
```
Erros: `400 invalid_url`, `404 video_unavailable`, `422 unsupported_content` (live, playlist, DRM), `502 extractor_failed`.

### `POST /v1/jobs`
Body: `{ "url": "...", "preset_id": "best_mp4" }`
`202` → `{ "job_id": "uuid" }`

### `GET /v1/jobs/{job_id}`
`200` →
```json
{
  "job_id": "uuid",
  "status": "queued | preparing | ready | failed",
  "progress": 0.0,
  "file_size_bytes": null,
  "file_name": null,
  "error_code": null,
  "error_message": null
}
```
`progress` vai de 0.0 a 1.0 e representa o preparo no servidor.

### `GET /v1/jobs/{job_id}/file`
Serve o arquivo final com `Content-Length`, `Accept-Ranges: bytes` e suporte a `Range` (necessário para retomar). `409` se o job ainda não estiver `ready`.

### `DELETE /v1/jobs/{job_id}`
`204`. Remove o arquivo e o registro. Também há limpeza automática por TTL (padrão: 2 h).

### Regras do backend
- Presets mapeiam para formatos do yt-dlp que resultem em **H.264 + AAC dentro de MP4** (compatível com AVPlayer sem transcodificar sempre); use `merge_output_format = mp4` e, só se necessário, ffmpeg para remux/transcode. Áudio: M4A (AAC).
- Rejeitar playlists (`noplaylist=True`), lives e URLs que não sejam de youtube.com / youtu.be.
- Configuração por variáveis de ambiente: `API_TOKEN` (obrigatório, o app não sobe sem ele), `DOWNLOAD_DIR`, `JOB_TTL_SECONDS`, `MAX_CONCURRENT_JOBS` (padrão 2).
- Execução do yt-dlp fora do event loop (thread pool) para não bloquear a API.
- Nada de CORS aberto; sem logs com tokens.
- `docker-compose.yml` sobe o serviço na porta 8080 com volume para `DOWNLOAD_DIR`.

---

## 6. ESPECIFICAÇÃO DO APP iOS

### 6.1 Navegação (TabView com 3 abas)
1. **Adicionar** — campo de URL, botão "Colar da área de transferência", botão "Buscar". Após resolver, mostra card com miniatura/título/duração e a lista de presets; botão "Baixar".
2. **Fila** — downloads ativos e recentes com estado, barra de progresso, ações (pausar, retomar, cancelar, tentar de novo).
3. **Biblioteca** — grade/lista dos vídeos baixados. Toque abre o player. Menu de contexto: "Salvar em Fotos", "Compartilhar", "Apagar".
- **Ajustes** abre como tela dentro da aba Adicionar (ícone de engrenagem) — não crie uma 4ª aba.

### 6.2 Modelo de dados (SwiftData)
```swift
@Model final class VideoItem {
    @Attribute(.unique) var id: UUID
    var videoID: String          // id do YouTube
    var title: String
    var channel: String
    var durationSeconds: Int
    var presetID: String
    var fileName: String         // relativo a Application Support/Videos
    var fileSizeBytes: Int64
    var thumbnailFileName: String?
    var createdAt: Date
}

@Model final class DownloadJob {
    @Attribute(.unique) var id: UUID
    var sourceURL: String
    var title: String
    var thumbnailURL: String?
    var presetID: String
    var serverJobID: String?
    var stateRaw: String         // DownloadState
    var progress: Double         // 0...1 (servidor + transferência combinados: 30% / 70%)
    var errorMessage: String?
    var resumeData: Data?
    var createdAt: Date
}
```

`enum DownloadState: String { case queued, resolving, preparing, downloading, paused, completed, failed, cancelled }` — implemente as transições válidas em um único lugar (`DownloadManager`) e teste a máquina de estados.

### 6.3 DownloadManager (núcleo)
- Marcado como `actor` ou `@MainActor` isolado conforme necessário; **uma única instância** injetada via `Environment`.
- Usa `URLSessionConfiguration.background(withIdentifier:)`, `isDiscretionary = false`, `sessionSendsLaunchEvents = true`.
- Implementa `URLSessionDownloadDelegate`: progresso, conclusão (mover arquivo **dentro** do callback para um local permanente), erro com `resumeData`.
- Reconecta tarefas pendentes ao reabrir o app (`getAllTasks`) e trata `handleEventsForBackgroundURLSession` via `AppDelegate` adaptado (`@UIApplicationDelegateAdaptor`).
- Concorrência máxima: 2 downloads simultâneos; o resto fica em `queued`.
- Retentativa automática: até 3 vezes com backoff exponencial para erros de rede; sem retentativa para erros 4xx.
- Ao concluir: cria `VideoItem`, baixa/gera miniatura, chama `DELETE /v1/jobs/{id}`, dispara notificação local "Download concluído".

### 6.4 APIClient
- `protocol APIClientProtocol` com `resolve(url:)`, `createJob(url:presetID:)`, `jobStatus(id:)`, `fileRequest(id:)`, `deleteJob(id:)`, `health()`.
- Lê base URL do `AppSettings` e o token do **Keychain** (nunca UserDefaults, nunca hardcoded).
- Erros tipados em `APIError` (com mensagens em português): sem conexão, token inválido, servidor inacessível, vídeo indisponível, conteúdo não suportado, erro desconhecido.
- App Transport Security: exigir HTTPS por padrão. Permitir HTTP **somente** para IPs de rede local (`NSAllowsLocalNetworking`) e adicionar `NSLocalNetworkUsageDescription`.

### 6.5 Share Extension
- Aceita `public.url` e texto contendo URL do YouTube.
- Grava a URL num **App Group** (`group.<bundle-id>.shared`) e abre o app principal via URL scheme `videograbber://add?url=...`.
- O app, ao abrir pela scheme, vai direto para a aba Adicionar e já resolve o link.

### 6.6 Player
- `AVPlayerViewController` encapsulado em `UIViewControllerRepresentable`.
- Habilitar `allowsPictureInPicturePlayback` e a capability **Audio, AirPlay, and Picture in Picture** (Background Modes → audio).
- Configurar `AVAudioSession` categoria `.playback`.

### 6.7 Permissões e Info.plist
- `NSPhotoLibraryAddUsageDescription` (salvar em Fotos).
- `NSLocalNetworkUsageDescription`.
- Background Modes: `audio`. Notificações locais: pedir permissão na primeira vez que o usuário inicia um download.
- URL Types: scheme `videograbber`.

### 6.8 Acabamento visual
- Visual nativo e limpo (SF Symbols, `Material`, cantos arredondados, Dynamic Type, Dark Mode).
- Estados vazios amigáveis (biblioteca vazia, fila vazia) e estados de erro com botão "Tentar de novo".
- Acessibilidade: `accessibilityLabel` nos botões de ícone; alvos de toque ≥ 44 pt.

---

## 7. QUALIDADE, SEGURANÇA E TESTES

- **Segredos**: token só no Keychain (app) e em variável de ambiente (backend). Crie `.env.example`; `.env` no `.gitignore`.
- **Validação**: o app valida a URL antes de enviar; o backend valida de novo (nunca confie no cliente). Sem execução de shell com entrada do usuário; use a API Python do yt-dlp, não `subprocess` com string concatenada.
- **Backend (pytest)**: auth (401 sem token), validação de URL, mapeamento de presets, ciclo de vida do job, TTL de limpeza, suporte a `Range`.
- **iOS (Swift Testing)**: `DownloadState` (transições), `APIClient` com `URLProtocol` mockado, parsing das respostas, `VideoStore`, formatação de duração/tamanho.
- **UI (XCUITest)**: 1 teste do fluxo "colar URL → resolver → baixar" usando um servidor/mocks locais.
- Compilação limpa: **zero warnings** em `xcodebuild`.
- Comando de build e teste (documente no README):
  ```
  cd ios && xcodegen generate
  xcodebuild -scheme VideoGrabber -destination 'platform=iOS Simulator,name=iPhone 16' test
  cd ../backend && pytest
  ```

---

## 8. PLANO DE EXECUÇÃO POR FASES

Cada fase termina com: build verde → testes verdes → commit.

**Fase 1 — Backend funcional**
Estrutura do `backend/`, rotas da seção 5, auth, jobs com TTL, Dockerfile/compose, testes, `docs/API.md`.
*Critério de aceite:* `docker compose up` e, com `curl`, resolver uma URL real de teste, criar job, acompanhar o status e baixar o arquivo com `Range`.

**Fase 2 — Esqueleto do app iOS**
`project.yml`, targets (app, extensão, testes), navegação em abas, `AppSettings` + Keychain, tela de Ajustes com "Testar conexão" (`/health`).
*Critério de aceite:* o app abre no simulador, salva URL/token e mostra "Conectado" ou o erro correto.

**Fase 3 — Resolver e baixar (primeiro-plano)**
`APIClient`, `AddLinkView`, `DownloadManager` com polling e download simples, modelos SwiftData, `QueueView`.
*Critério de aceite:* colar link → ver metadados → baixar → arquivo aparece em `VideoItem`.

**Fase 4 — Biblioteca e Player**
`LibraryView`, miniaturas, `PlayerView` com PiP e áudio em segundo plano, apagar, salvar em Fotos, compartilhar.
*Critério de aceite:* reproduzir um item baixado, entrar em PiP, salvar em Fotos.

**Fase 5 — Robustez**
Sessão em background, retomada com `resumeData`, retentativas, fila com limite de 2, notificação local, tratamento de todos os erros de `APIError`.
*Critério de aceite:* iniciar download, sair do app, receber notificação ao concluir; matar a rede no meio e retomar.

**Fase 6 — Share Extension**
App Group, extensão, URL scheme, abertura direta na aba Adicionar.
*Critério de aceite:* compartilhar um link do Safari → o app abre e resolve o vídeo.

**Fase 7 — Acabamento e documentação**
Estados vazios, acessibilidade, Dark Mode, ícone do app (placeholder simples), `README.md` com instalação (backend + app), solução de problemas e limites conhecidos.

---

## 9. RESTRIÇÕES LEGAIS E DE DISTRIBUIÇÃO (inclua no README)

- Este projeto é para **uso pessoal**, para conteúdo que o usuário tem direito de baixar (próprio, licenciado ou com permissão). Baixar vídeos do YouTube pode violar os Termos de Serviço da plataforma e direitos autorais. Inclua esse aviso na tela de Ajustes e no README.
- **Não** será enviado à App Store: a Apple e o YouTube não permitem apps desse tipo. Distribuição prevista: instalação direta pelo Xcode no próprio aparelho (conta de desenvolvedor gratuita; o app expira em 7 dias) ou assinatura pessoal.
- Não implemente nenhum mecanismo de contorno de DRM nem acesso a conteúdo privado/pago.
- O `yt-dlp` quebra com frequência quando o YouTube muda; documente no README como atualizar (`pip install -U yt-dlp` / rebuild da imagem) e deixe a versão visível em `/health` e na tela de Ajustes ("Testar conexão").

---

## 10. DEFINIÇÃO DE PRONTO (checklist final)

- [ ] `docker compose up` sobe o backend; `pytest` passa.
- [ ] `xcodegen generate` + `xcodebuild test` passam sem warnings.
- [ ] Fluxo completo funciona no simulador **e** em um iPhone físico: colar link → resolver → baixar (com app em segundo plano) → biblioteca → player/PiP → salvar em Fotos.
- [ ] Share Extension funcional.
- [ ] Nenhum segredo no repositório; token no Keychain.
- [ ] `README.md`, `docs/API.md` e `docs/DECISIONS.md` completos.
- [ ] Histórico git com um commit por fase.

---

## 11. SKILLS E FERRAMENTAS PARA DESENVOLVIMENTO iOS

Skills são pastas com um `SKILL.md` que o agente carrega sob demanda. Instale as abaixo **na Fase 0**, antes de escrever código Swift.

### 11.1 Instalação

Requer Node (`brew install node`). Para cada skill, rode o comando na raiz do projeto (instala em `.claude/skills/`, que deve ir para o git):

```bash
# SwiftUI — erros típicos de LLM, APIs depreciadas, navegação, estado, acessibilidade
npx skills add https://github.com/twostraws/swiftui-agent-skill --skill swiftui-pro

# SwiftData — modelagem, @Query, predicates, concorrência (@ModelActor), migrações
npx skills add https://github.com/vanab/SwiftData-agent-skill --skill swiftdata-expert-skill

# Swift Concurrency — actors, Sendable, Swift 6 (essencial para o DownloadManager)
openskills install avdlee/Swift-Concurrency-Agent-Skill
```

Alternativa para Claude Code (marketplace de plugins), para o SwiftUI Pro:
```
/plugin marketplace add twostraws/SwiftUI-Agent-Skill
/plugin install swiftui-pro@swiftui-agent-skill
```

### 11.2 Repositórios de referência

| Repositório | Para que serve | Prioridade |
|---|---|---|
| https://github.com/twostraws/Swift-Agent-Skills | Lista curada de skills Swift/Apple (SwiftUI, SwiftData, Concurrency, Testing, Acessibilidade, Segurança, Performance, App Store). Use para localizar **Swift Testing Pro**, **Swift Concurrency Pro** e **SwiftData Pro**, do Paul Hudson | Alta |
| https://github.com/twostraws/SwiftUI-Agent-Skill | SwiftUI Pro (comando `/swiftui-pro`) | Alta |
| https://github.com/AvdLee/Swift-Concurrency-Agent-Skill | Swift Concurrency: árvores de decisão, Sendable, cancelamento, migração Swift 6 | Alta |
| https://github.com/vanab/SwiftData-agent-skill | SwiftData: container/contexto, concorrência, migrações | Média |
| https://github.com/daneden/agent-skills | `swiftui-gotchas`: antipadrões de SwiftUI/Concurrency/SwiftData sob Swift 6 | Média |
| https://github.com/troyjthomas/ios-agent-skills | 18 skills do ciclo completo (spec → scaffold → build → teste → polimento) e personas de revisão | Opcional |
| https://github.com/ApptitudeLabs/claude-code-ios-dev-setup | Guia de setup de Claude Code para iOS: skills Axiom, XcodeBuildMCP, hooks | Opcional |
| https://github.com/FloWritesCode/fwc-swiftui-skills | Liquid Glass (iOS 26+). **Só** use se decidir elevar o alvo mínimo | Opcional |

### 11.3 MCP servers recomendados

```bash
# Documentação oficial da Apple (Swift, SwiftUI, AVFoundation, etc.)
claude mcp add --transport http sosumi https://sosumi.ai/mcp
```
O **XcodeBuildMCP** (build, testes e simulador pelo agente) está descrito no repositório `ApptitudeLabs/claude-code-ios-dev-setup`; instale conforme as instruções de lá se quiser que o agente opere o simulador sozinho.

### 11.4 Quando usar cada skill (regra para o agente)

| Fase | Skill / ferramenta |
|---|---|
| 2, 3, 4 (UI) | `swiftui-pro` ao criar ou revisar qualquer View; `swiftui-gotchas` como checklist |
| 3, 4 (dados) | `swiftdata-expert-skill` antes de definir `VideoItem` e `DownloadJob` |
| 3, 5 (downloads) | Swift Concurrency (AvdLee): obrigatório ao implementar `DownloadManager` e `APIClient` |
| 1–7 (testes) | Swift Testing Pro (via lista do Paul Hudson), se instalada |
| 7 (acabamento) | Skills de acessibilidade da lista curada; `/swiftui-pro` em revisão final de todo o projeto |
| Qualquer dúvida de API | MCP `sosumi` antes de adivinhar |

### 11.5 Regras de uso

- **Leia o `SKILL.md` de cada skill antes de confiar nela** e confirme a licença. São conteúdo de terceiros: não execute scripts que elas tragam sem entender o que fazem.
- As skills de SwiftUI mirram **iOS 26 / Swift 6.2**. O alvo deste projeto continua **iOS 17+**: ignore recomendações que exijam APIs mais novas (ex.: Liquid Glass) ou proteja-as com `#available`.
- Em caso de conflito entre uma skill e este documento, **este documento vence**; registre a divergência em `docs/DECISIONS.md`.
- Se algum link ou comando de instalação falhar, não trave: siga o desenvolvimento com as demais e registre a falha em `docs/DECISIONS.md`.
- Commite `.claude/skills/` junto ao repositório para que as skills acompanhem o projeto.

---

**Comece agora pela Fase 0:** verifique os pré-requisitos (seção 3), inicialize o repositório git, instale as skills e o MCP da seção 11, crie `CLAUDE.md` com as seções 1–11 e a estrutura de pastas da seção 4, e então siga para a Fase 1.