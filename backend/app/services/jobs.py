import shutil
import threading
import time
import uuid
from collections.abc import Callable
from dataclasses import dataclass, field, replace
from pathlib import Path

from app.models import JobStatus

TERMINAL_STATUSES = {JobStatus.READY, JobStatus.FAILED}


@dataclass
class Job:
    id: str
    url: str
    preset_id: str
    created_at: float
    status: JobStatus = JobStatus.QUEUED
    progress: float = 0.0
    file_path: Path | None = None
    file_size_bytes: int | None = None
    file_name: str | None = None
    error_code: str | None = None
    error_message: str | None = None
    finished_at: float | None = field(default=None)


class JobRegistry:
    """Registro de jobs em memória, seguro entre threads.

    Cada job usa a pasta `download_dir/<job_id>`. Jobs terminados (ready/failed)
    são removidos `ttl_seconds` depois de terminar.
    """

    def __init__(self, download_dir: Path, ttl_seconds: int, clock: Callable[[], float] = time.monotonic) -> None:
        self.download_dir = download_dir
        self.ttl_seconds = ttl_seconds
        self._clock = clock
        self._jobs: dict[str, Job] = {}
        self._lock = threading.Lock()

    def job_dir(self, job_id: str) -> Path:
        return self.download_dir / job_id

    def create(self, url: str, preset_id: str) -> Job:
        job = Job(id=str(uuid.uuid4()), url=url, preset_id=preset_id, created_at=self._clock())
        with self._lock:
            self._jobs[job.id] = job
            return replace(job)

    def get(self, job_id: str) -> Job | None:
        with self._lock:
            job = self._jobs.get(job_id)
            return replace(job) if job else None

    def exists(self, job_id: str) -> bool:
        with self._lock:
            return job_id in self._jobs

    def mark_preparing(self, job_id: str) -> None:
        self._update(job_id, status=JobStatus.PREPARING)

    def set_progress(self, job_id: str, progress: float) -> None:
        self._update(job_id, progress=max(0.0, min(progress, 1.0)))

    def mark_ready(self, job_id: str, file_path: Path, file_name: str) -> None:
        self._update(
            job_id,
            status=JobStatus.READY,
            progress=1.0,
            file_path=file_path,
            file_name=file_name,
            file_size_bytes=file_path.stat().st_size,
            finished_at=self._clock(),
        )

    def mark_failed(self, job_id: str, error_code: str, error_message: str) -> None:
        self._update(
            job_id,
            status=JobStatus.FAILED,
            error_code=error_code,
            error_message=error_message,
            finished_at=self._clock(),
        )

    def delete(self, job_id: str) -> bool:
        if not _is_uuid(job_id):
            return False
        with self._lock:
            removed = self._jobs.pop(job_id, None) is not None
        shutil.rmtree(self.job_dir(job_id), ignore_errors=True)
        return removed

    def purge_expired(self) -> int:
        now = self._clock()
        with self._lock:
            expired = [
                job.id for job in self._jobs.values()
                if job.status in TERMINAL_STATUSES
                and job.finished_at is not None
                and now - job.finished_at >= self.ttl_seconds
            ]
        for job_id in expired:
            self.delete(job_id)
        return len(expired)

    def remove_orphan_dirs(self) -> None:
        """Na inicialização, apaga pastas de jobs de execuções anteriores (só nomes UUID)."""
        if not self.download_dir.is_dir():
            return
        for path in self.download_dir.iterdir():
            if path.is_dir() and _is_uuid(path.name) and not self.exists(path.name):
                shutil.rmtree(path, ignore_errors=True)

    def _update(self, job_id: str, **changes: object) -> None:
        with self._lock:
            job = self._jobs.get(job_id)
            if job is None:
                return
            for key, value in changes.items():
                setattr(job, key, value)


def _is_uuid(value: str) -> bool:
    try:
        return str(uuid.UUID(value)) == value
    except ValueError:
        return False
