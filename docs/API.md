# Contrato da API — VideoGrabber Backend

Fonte da verdade para o backend (`backend/`) e para o `APIClient` do app iOS.

- Base: `http(s)://<servidor>:8080`
- Todas as rotas, exceto `GET /health`, exigem `Authorization: Bearer <API_TOKEN>`.
- Corpo de requisição e de resposta em JSON (UTF-8).
- `job_id` é sempre um UUID; outro formato devolve `400 invalid_request`.

## Formato de erro

Todas as respostas de erro têm o mesmo corpo:

```json
{ "error_code": "invalid_url", "message": "Apenas links do YouTube são aceitos." }
```

| HTTP | `error_code` | Quando |
|---|---|---|
| 400 | `invalid_request` | Corpo ausente/malformado ou `job_id` que não é UUID |
| 400 | `invalid_url` | URL vazia, longa demais (> 2048) ou fora de youtube.com / youtu.be |
| 400 | `invalid_preset` | `preset_id` desconhecido |
| 401 | `unauthorized` | Token ausente ou inválido |
| 404 | `video_unavailable` | Vídeo removido, privado, com login ou só para membros |
| 404 | `job_not_found` | Job inexistente ou já removido |
| 409 | `job_not_ready` | Pediu o arquivo antes de `status = ready` |
| 422 | `unsupported_content` | Playlist, canal, live (inclusive agendada) ou DRM |
| 500 | `internal_error` | Falha inesperada ao preparar o arquivo (aparece em `error_code` do job) |
| 502 | `extractor_failed` | O yt-dlp falhou (geralmente precisa atualizar) |
| 502 | `youtube_blocked` | O YouTube bloqueou o IP do servidor ("confirm you're not a bot"); o vídeo em si está disponível. Comum em VPS |

## `GET /health`

Sem autenticação.

`200` → `{ "status": "ok", "ytdlp_version": "2026.10.26" }`

## `POST /v1/resolve`

Body: `{ "url": "https://www.youtube.com/watch?v=..." }`

`200` →

```json
{
  "video_id": "jNQXAC9IVRw",
  "title": "Me at the zoo",
  "channel": "jawed",
  "duration_seconds": 19,
  "thumbnail_url": "https://i.ytimg.com/vi/jNQXAC9IVRw/hqdefault.jpg",
  "presets": [
    { "id": "best_mp4",  "label": "Melhor qualidade (até 1080p)", "kind": "video", "estimated_bytes": 1009829 },
    { "id": "mp4_720",   "label": "720p",                          "kind": "video", "estimated_bytes": 1009829 },
    { "id": "audio_m4a", "label": "Somente áudio (M4A)",           "kind": "audio", "estimated_bytes": 309288 }
  ]
}
```

- `thumbnail_url` e `estimated_bytes` podem ser `null`.
- `estimated_bytes` é aproximado. Quando o formato não informa tamanho, é estimado por taxa de bits × duração.
- Os três presets sempre aparecem, nesta ordem.

Erros: `400 invalid_url`, `404 video_unavailable`, `422 unsupported_content`, `502 extractor_failed`, `502 youtube_blocked`.

## `POST /v1/jobs`

Body: `{ "url": "...", "preset_id": "best_mp4" }`

`202` → `{ "job_id": "8b6f0d1e-7a51-4f0e-9a43-2a4d3f1b9c10" }`

Erros: `400 invalid_url`, `400 invalid_preset`. Erros de extração (vídeo indisponível, live etc.) não são devolvidos aqui: o job termina com `status = failed` e o `error_code` correspondente.

## `GET /v1/jobs/{job_id}`

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

- `progress` vai de 0.0 a 1.0 e mede o preparo no servidor (download no servidor até 0.95; merge/remux até 1.0).
- `file_size_bytes` e `file_name` são preenchidos quando `status = ready`. `file_name` é o título do vídeo, saneado, com extensão `.mp4` ou `.m4a`.
- `error_code` e `error_message` são preenchidos quando `status = failed`.

Erros: `404 job_not_found`.

## `GET /v1/jobs/{job_id}/file`

Serve o arquivo final.

- `200` com `Content-Length`, `Accept-Ranges: bytes`, `Content-Type` (`video/mp4` ou `audio/mp4`) e `Content-Disposition` (nome do arquivo em RFC 5987).
- Com o header `Range: bytes=início-[fim]`, responde `206 Partial Content` com `Content-Range` (é o que permite retomar).
- `409 job_not_ready` se o job não estiver `ready`; `404 job_not_found` se não existir.

## `DELETE /v1/jobs/{job_id}`

`204`. Remove o arquivo e o registro. Se o job ainda estiver preparando, o preparo é cancelado. É idempotente: um job inexistente também devolve `204`.

## Limpeza automática

Jobs `ready` ou `failed` são removidos `JOB_TTL_SECONDS` (padrão 7200 s) depois de terminar. Ao iniciar, o servidor apaga pastas de jobs que sobraram de execuções anteriores.

## Configuração (variáveis de ambiente)

| Variável | Padrão | Descrição |
|---|---|---|
| `API_TOKEN` | — (obrigatório, ≥ 16 caracteres) | Token Bearer. Sem ele o servidor não sobe |
| `DOWNLOAD_DIR` | `/data/downloads` | Pasta dos arquivos preparados |
| `JOB_TTL_SECONDS` | `7200` | Tempo de vida de um job terminado |
| `MAX_CONCURRENT_JOBS` | `2` | Jobs preparados ao mesmo tempo; os demais ficam `queued` |
