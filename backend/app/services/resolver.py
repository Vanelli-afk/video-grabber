import logging
from dataclasses import dataclass
from typing import Any, Literal
from urllib.parse import urlsplit

import yt_dlp
from yt_dlp.utils import DownloadError

from app.errors import APIError
from app.models import Preset, ResolveResponse

ALLOWED_HOSTS = {"youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be"}
MAX_URL_LENGTH = 2048
UNSUPPORTED_LIVE_STATUSES = {"is_live", "is_upcoming", "post_live"}

BASE_YDL_OPTIONS: dict[str, Any] = {
    "quiet": True,
    "no_warnings": True,
    "noprogress": True,
    "noplaylist": True,
    "logger": logging.getLogger("videograbber.ytdlp"),
}


def _video_format(max_height: int) -> str:
    # Prefere H.264 + AAC (tocam no AVPlayer sem transcodificar); o resto é fallback.
    return (
        f"bv*[vcodec^=avc1][height<={max_height}]+ba[ext=m4a]"
        f"/b[vcodec^=avc1][acodec^=mp4a][height<={max_height}]"
        f"/bv*[height<={max_height}]+ba"
        f"/b[height<={max_height}]"
    )


@dataclass(frozen=True)
class PresetSpec:
    id: str
    label: str
    kind: Literal["video", "audio"]
    format: str
    max_height: int | None = None


PRESETS: dict[str, PresetSpec] = {
    spec.id: spec
    for spec in (
        PresetSpec("best_mp4", "Melhor qualidade (até 1080p)", "video", _video_format(1080), 1080),
        PresetSpec("mp4_720", "720p", "video", _video_format(720), 720),
        PresetSpec("audio_m4a", "Somente áudio (M4A)", "audio", "ba[ext=m4a]/ba[acodec^=mp4a]/ba"),
    )
}


def validate_url(url: str) -> str:
    """Aceita apenas http(s) de youtube.com / youtu.be. Devolve a URL sem espaços."""
    url = url.strip()
    if not url or len(url) > MAX_URL_LENGTH:
        raise APIError(400, "invalid_url", "URL inválida.")
    try:
        parts = urlsplit(url)
        host = (parts.hostname or "").lower()
    except ValueError:
        raise APIError(400, "invalid_url", "URL inválida.") from None
    if parts.scheme not in ("http", "https") or host not in ALLOWED_HOSTS:
        raise APIError(400, "invalid_url", "Apenas links do YouTube são aceitos.")
    if parts.path.rstrip("/") == "/playlist":
        raise APIError(422, "unsupported_content", "Playlists não são suportadas.")
    return url


def ensure_supported(info: dict[str, Any]) -> None:
    if info.get("_type") in ("playlist", "multi_video"):
        raise APIError(422, "unsupported_content", "Playlists e canais não são suportados.")
    if info.get("is_live") or info.get("live_status") in UNSUPPORTED_LIVE_STATUSES:
        raise APIError(422, "unsupported_content", "Transmissões ao vivo não são suportadas.")
    formats = info.get("formats") or []
    if formats and all(f.get("has_drm") for f in formats):
        raise APIError(422, "unsupported_content", "Conteúdo protegido por DRM não é suportado.")


def map_ytdlp_error(exc: Exception) -> APIError:
    text = str(exc).lower()
    if "drm" in text:
        return APIError(422, "unsupported_content", "Conteúdo protegido por DRM não é suportado.")
    unavailable_markers = (
        "video unavailable",
        "private video",
        "has been removed",
        "not available",
        "sign in",
        "members-only",
        "join this channel",
    )
    if any(marker in text for marker in unavailable_markers):
        return APIError(404, "video_unavailable", "Vídeo indisponível, privado ou com restrição de acesso.")
    return APIError(502, "extractor_failed", "Falha ao extrair o vídeo. Tente atualizar o yt-dlp no servidor.")


def _size(fmt: dict[str, Any] | None, duration: float) -> int | None:
    if not fmt:
        return None
    size = fmt.get("filesize") or fmt.get("filesize_approx")
    if not size and fmt.get("tbr") and duration:
        # Formatos HLS não informam tamanho: estima pela taxa média (kbit/s) × duração.
        size = fmt["tbr"] * 1000 / 8 * duration
    return int(size) if size else None


def _best_audio(formats: list[dict[str, Any]]) -> dict[str, Any] | None:
    audios = [
        f for f in formats
        if f.get("vcodec") == "none" and f.get("acodec") not in (None, "none") and not f.get("has_drm")
    ]
    pool = [f for f in audios if f.get("ext") == "m4a"] or audios
    return max(pool, key=lambda f: f.get("abr") or f.get("tbr") or 0, default=None)


def _best_video(formats: list[dict[str, Any]], max_height: int) -> dict[str, Any] | None:
    videos = [
        f for f in formats
        if f.get("vcodec") not in (None, "none") and (f.get("height") or 0) <= max_height and not f.get("has_drm")
    ]
    pool = [f for f in videos if str(f.get("vcodec")).startswith("avc1")] or videos
    return max(pool, key=lambda f: (f.get("height") or 0, f.get("tbr") or 0), default=None)


def estimate_bytes(spec: PresetSpec, formats: list[dict[str, Any]], duration: float = 0) -> int | None:
    audio = _best_audio(formats)
    if spec.kind == "audio":
        return _size(audio, duration)
    video = _best_video(formats, spec.max_height or 0)
    if video is None:
        return None
    if video.get("acodec") not in (None, "none"):
        return _size(video, duration)
    video_size, audio_size = _size(video, duration), _size(audio, duration)
    if video_size is None or audio_size is None:
        return None
    return video_size + audio_size


def build_response(info: dict[str, Any]) -> ResolveResponse:
    formats = info.get("formats") or []
    duration = info.get("duration") or 0
    return ResolveResponse(
        video_id=str(info.get("id", "")),
        title=info.get("title") or "",
        channel=info.get("channel") or info.get("uploader") or "",
        duration_seconds=int(duration),
        thumbnail_url=info.get("thumbnail"),
        presets=[
            Preset(
                id=spec.id, label=spec.label, kind=spec.kind, estimated_bytes=estimate_bytes(spec, formats, duration)
            )
            for spec in PRESETS.values()
        ],
    )


def resolve(url: str) -> ResolveResponse:
    """Bloqueante: chame fora do event loop (asyncio.to_thread)."""
    try:
        with yt_dlp.YoutubeDL(BASE_YDL_OPTIONS) as ydl:
            info = ydl.extract_info(url, download=False)
    except DownloadError as exc:
        raise map_ytdlp_error(exc) from None
    ensure_supported(info)
    return build_response(info)
