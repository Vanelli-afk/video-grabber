# Decisões

Uma linha por decisão não especificada no roteiro (ou divergência dele).

## Fase 0 — Ambiente

- 2026-11-01 — O ambiente de desenvolvimento atual é **Windows 10**, sem Xcode, XcodeGen, Docker nem ffmpeg. As fases iOS (2–7) e o critério de aceite com `docker compose up` da Fase 1 precisam ser executados num Mac com Xcode e Docker.
- 2026-11-01 — Python local é 3.14 (não 3.12). Os testes rodam em 3.14; a imagem Docker usa `python:3.12-slim`, conforme o roteiro.
- 2026-11-01 — Skills da seção 11 **não instaladas**: o comando `npx skills add ...` foi bloqueado pela política de permissões desta sessão. Instalar manualmente no Mac antes da Fase 2. O MCP `sosumi` também ficou para o Mac.

## Fase 1 — Backend

- 2026-11-01 — Corpo de erro padronizado: `{ "error_code", "message" }` (o roteiro só listava os códigos).
- 2026-11-01 — Erros de validação do FastAPI (422 padrão) viram `400 invalid_request`, para não colidir com `422 unsupported_content`.
- 2026-11-01 — Contra SSRF por diferença entre parsers de URL: `validate_url` rejeita `\`, espaços e caracteres de controle, usuário/senha e porta, e devolve uma URL **reconstruída** (`https://<host validado><path>?<query>`); o yt-dlp carrega só os extratores `youtube` e `youtube:tab` (`allowed_extractors`), sem o genérico.
- 2026-11-01 — `job_id` é tipado como UUID nas rotas e no registro, o que impede path traversal no `DELETE`.
- 2026-11-01 — `DELETE /v1/jobs/{id}` é idempotente (204 mesmo para job inexistente), para simplificar a limpeza pelo app.
- 2026-11-01 — Novos códigos `409 job_not_ready`, `404 job_not_found`, `400 invalid_preset` e `500 internal_error`, além dos do roteiro.
- 2026-11-01 — TTL contado a partir do término do job (`ready`/`failed`); jobs em preparo não expiram.
- 2026-11-01 — Cada job usa a pasta `DOWNLOAD_DIR/<uuid>`; na inicialização só são apagadas pastas com nome UUID (nunca outros arquivos do diretório).
- 2026-11-01 — Seletores de formato preferem `avc1` + `m4a`; fallback para outros codecs com remux para MP4 (`FFmpegVideoRemuxer`), sem transcodificar. Na prática o YouTube oferece H.264 até 1080p.
- 2026-11-01 — Áudio: `ba[ext=m4a]` com `FFmpegExtractAudio` para `m4a` (copia o stream quando já é AAC).
- 2026-11-01 — `estimated_bytes` pode ser `null`; quando o formato não traz tamanho (HLS), estima por `tbr × duração`.
- 2026-11-01 — Progresso do servidor: partes baixadas (vídeo + áudio) somam até 0.95; 1.0 ao ficar `ready`.
- 2026-11-01 — Lives agendadas (`is_upcoming`) e recém-encerradas (`post_live`) também são `unsupported_content`.
- 2026-11-01 — `music.youtube.com` e `m.youtube.com` são aceitos além de `youtube.com`, `www.youtube.com` e `youtu.be`.
- 2026-11-01 — Páginas `/docs` e `/openapi.json` desativadas (servidor pessoal, sem superfície pública desnecessária).
- 2026-11-01 — `API_TOKEN` exige no mínimo 16 caracteres.
- 2026-11-01 — Desde o fim de 2025 o yt-dlp precisa de um runtime JavaScript para o YouTube; `requirements.txt` usa `yt-dlp[default,deno]`, que instala `yt-dlp-ejs` e o Deno via pip.
- 2026-11-01 — Testes usam `httpx` (pedido no roteiro); o aviso do Starlette 1.x que sugere `httpx2` é filtrado em `pyproject.toml`.
- 2026-11-01 — App FastAPI criado por fábrica (`create_app`, `uvicorn --factory`), para os testes injetarem `Settings`.

## Inspeção pós-Fase 2

- 2026-11-01 — Erro do yt-dlp "Sign in to confirm you're not a bot" (bloqueio do IP do servidor) agora é `502 youtube_blocked`, não `404 video_unavailable`; novo código documentado em docs/API.md.
- 2026-11-01 — Detecção de DRM procura a frase "drm protected": antes, `"drm"` solto casava com IDs de vídeo como `aBdRm7xYz12`.
- 2026-11-01 — "Requested format is not available" vira `extractor_failed` (todos os presets têm fallback, então é falha do extrator).
- 2026-11-01 — Downloads rodam em threads **daemon** limitadas por `BoundedSemaphore(MAX_CONCURRENT_JOBS)` em vez de `ThreadPoolExecutor`: o executor faz o Python esperar downloads/ffmpeg em andamento ao desligar. Sobras são apagadas na inicialização seguinte.
- 2026-11-01 — iOS: timeout por endpoint (`Endpoint.timeout`, 15 s para `/health` e consulta de job) em vez dos 60 s padrão do URLSession.

## Fase 2 — Esqueleto iOS

- 2026-11-01 — Sem Mac: o app é compilado e testado no **GitHub Actions** (`macos-latest`, repositório público) e instalado no iPhone pelo **Sideloadly** a partir de um `.ipa` sem assinatura gerado pelo CI.
- 2026-11-01 — O CI escolhe o simulador de iPhone mais recente disponível no runner, em vez de fixar "iPhone 16" (o nome muda entre versões do Xcode).
- 2026-11-01 — Builds do CI usam `CODE_SIGNING_ALLOWED=NO`; quem assina é o Sideloadly com o Apple ID do usuário.
- 2026-11-01 — Bundle ID `com.vanelliafk.videograbber` (extensão `.share`).
- 2026-11-01 — `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` em todos os targets, para garantir "zero warnings".
- 2026-11-01 — O projeto `.xcodeproj` e os `Info.plist` são gerados pelo XcodeGen e ficam fora do git.
- 2026-11-01 — "Testar conexão" chama `/health` (que é público) **e** `GET /v1/jobs/00000000-0000-0000-0000-000000000000`: 404 `job_not_found` prova que o token foi aceito; 401 mostra "Token de acesso inválido". Assim não foi preciso mudar o contrato da API.
- 2026-11-01 — O endereço do servidor aceita `192.168.0.10:8080` sem esquema (assume `http://`).
- 2026-11-01 — Token no Keychain com `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (necessário para downloads em segundo plano com a tela bloqueada).
- 2026-11-01 — Dependências passadas por inicializador (`AppDependencies`) em vez de `Environment`, por ora; o `DownloadManager` da Fase 3 irá para o `Environment`, como pede o roteiro.
- 2026-11-01 — Ícone do app fica para a Fase 7 (o roteiro prevê um placeholder lá).
