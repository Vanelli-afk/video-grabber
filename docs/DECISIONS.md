# Decisões

Uma linha por decisão não especificada no roteiro (ou divergência dele).

## Fase 0 — Ambiente

- 2026-11-01 — O ambiente de desenvolvimento atual é **Windows 10**, sem Xcode, XcodeGen, Docker nem ffmpeg. As fases iOS (2–7) e o critério de aceite com `docker compose up` da Fase 1 precisam ser executados num Mac com Xcode e Docker.
- 2026-11-01 — Python local é 3.14 (não 3.12). Os testes rodam em 3.14; a imagem Docker usa `python:3.12-slim`, conforme o roteiro.
- 2026-11-01 — Skills da seção 11 **não instaladas**: o comando `npx skills add ...` foi bloqueado pela política de permissões desta sessão. Instalar manualmente no Mac antes da Fase 2. O MCP `sosumi` também ficou para o Mac.

## Fase 1 — Backend

- 2026-11-01 — Corpo de erro padronizado: `{ "error_code", "message" }` (o roteiro só listava os códigos).
- 2026-11-01 — Erros de validação do FastAPI (422 padrão) viram `400 invalid_request`, para não colidir com `422 unsupported_content`.
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
