import logging
import re
import shutil
from typing import Any

import yt_dlp
from yt_dlp.utils import DownloadCancelled, DownloadError

from app.errors import APIError
from app.services.jobs import JobRegistry
from app.services.resolver import BASE_YDL_OPTIONS, PRESETS, PresetSpec, ensure_supported, map_ytdlp_error

logger = logging.getLogger("videograbber.downloader")

# O progresso de download vai até este teto; o restante fica para merge/remux.
DOWNLOAD_PROGRESS_CAP = 0.95
_INVALID_FILENAME_CHARS = re.compile(r'[\\/:*?"<>|\x00-\x1f]')


class ProgressTracker:
    """Combina o progresso das partes baixadas (vídeo + áudio) num único valor 0...1."""

    def __init__(self, expected_parts: int) -> None:
        self.expected_parts = expected_parts
        self._finished_parts = 0
        self._current_file: str | None = None

    def update(self, event: dict[str, Any]) -> float:
        filename = event.get("filename")
        if self._current_file is not None and filename != self._current_file:
            self._finished_parts += 1
        self._current_file = filename
        total = event.get("total_bytes") or event.get("total_bytes_estimate")
        fraction = min(event.get("downloaded_bytes", 0) / total, 1.0) if total else 0.0
        parts_done = min(self._finished_parts, self.expected_parts - 1)
        return (parts_done + fraction) / self.expected_parts * DOWNLOAD_PROGRESS_CAP


def ydl_options(spec: PresetSpec, job_dir: str, hook: Any) -> dict[str, Any]:
    options: dict[str, Any] = {
        **BASE_YDL_OPTIONS,
        "format": spec.format,
        "paths": {"home": job_dir},
        "outtmpl": "media.%(ext)s",
        "progress_hooks": [hook],
    }
    if spec.kind == "video":
        options["merge_output_format"] = "mp4"
        # Garante contêiner MP4 sem transcodificar quando o fallback trouxer outro contêiner.
        options["postprocessors"] = [{"key": "FFmpegVideoRemuxer", "preferedformat": "mp4"}]
    else:
        options["postprocessors"] = [{"key": "FFmpegExtractAudio", "preferredcodec": "m4a"}]
    return options


def display_file_name(title: str, video_id: str, extension: str) -> str:
    base = _INVALID_FILENAME_CHARS.sub("_", title).strip(" .")[:150] or video_id or "video"
    return f"{base}.{extension}"


def run_download(job_id: str, registry: JobRegistry) -> None:
    """Bloqueante: executado no pool de threads. Atualiza o job no registro."""
    job = registry.get(job_id)
    if job is None:
        return
    spec = PRESETS[job.preset_id]
    job_dir = registry.job_dir(job_id)
    job_dir.mkdir(parents=True, exist_ok=True)
    registry.mark_preparing(job_id)
    tracker = ProgressTracker(expected_parts=2 if spec.kind == "video" else 1)

    def hook(event: dict[str, Any]) -> None:
        if not registry.exists(job_id):
            raise DownloadCancelled()
        if event.get("status") == "downloading":
            registry.set_progress(job_id, tracker.update(event))

    try:
        with yt_dlp.YoutubeDL(ydl_options(spec, str(job_dir), hook)) as ydl:
            info = ydl.extract_info(job.url, download=False)
            ensure_supported(info)
            ydl.process_ie_result(info, download=True)
    except DownloadCancelled:
        shutil.rmtree(job_dir, ignore_errors=True)
        return
    except APIError as exc:
        _fail(registry, job_id, exc)
        return
    except DownloadError as exc:
        _fail(registry, job_id, map_ytdlp_error(exc))
        return
    except Exception:
        logger.exception("Falha inesperada no job %s", job_id)
        _fail(registry, job_id, APIError(500, "internal_error", "Erro interno ao preparar o arquivo."))
        return

    extension = "mp4" if spec.kind == "video" else "m4a"
    file_path = job_dir / f"media.{extension}"
    if not registry.exists(job_id):
        shutil.rmtree(job_dir, ignore_errors=True)
        return
    if not file_path.is_file():
        logger.error("Job %s terminou sem gerar %s", job_id, file_path.name)
        _fail(registry, job_id, APIError(500, "internal_error", "O servidor não gerou o arquivo esperado."))
        return
    registry.mark_ready(job_id, file_path, display_file_name(info.get("title") or "", info.get("id") or "", extension))


def _fail(registry: JobRegistry, job_id: str, error: APIError) -> None:
    registry.mark_failed(job_id, error.error_code, error.message)
    shutil.rmtree(registry.job_dir(job_id), ignore_errors=True)
