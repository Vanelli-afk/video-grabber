import copy
import threading
import time
from pathlib import Path
from typing import Any

import pytest
import yt_dlp
from fastapi.testclient import TestClient
from yt_dlp.utils import DownloadError

from app.config import Settings
from app.main import create_app
from app.models import JobStatus

TOKEN = "test-token-0123456789"
VIDEO_URL = "https://www.youtube.com/watch?v=abc123"

SAMPLE_INFO: dict[str, Any] = {
    "id": "abc123",
    "title": "Vídeo de teste: parte 1/2",
    "channel": "Canal de Teste",
    "duration": 213,
    "thumbnail": "https://i.ytimg.com/vi/abc123/hqdefault.jpg",
    "formats": [
        {"format_id": "140", "ext": "m4a", "vcodec": "none", "acodec": "mp4a.40.2", "abr": 128, "filesize": 3_000_000},
        {"format_id": "251", "ext": "webm", "vcodec": "none", "acodec": "opus", "abr": 160, "filesize": 3_500_000},
        {"format_id": "137", "ext": "mp4", "vcodec": "avc1.640028", "acodec": "none", "height": 1080, "tbr": 4000, "filesize": 100_000_000},
        {"format_id": "248", "ext": "webm", "vcodec": "vp9", "acodec": "none", "height": 1080, "tbr": 3000, "filesize": 80_000_000},
        {"format_id": "136", "ext": "mp4", "vcodec": "avc1.4d401f", "acodec": "none", "height": 720, "tbr": 2000, "filesize_approx": 50_000_000},
        {"format_id": "313", "ext": "webm", "vcodec": "vp9", "acodec": "none", "height": 2160, "tbr": 15000, "filesize": 500_000_000},
    ],
}

FILE_CONTENT = bytes(range(256)) * 40  # 10 240 bytes


class Scenario:
    """Controla o comportamento do YoutubeDL falso em cada teste."""

    def __init__(self) -> None:
        self.info: dict[str, Any] = copy.deepcopy(SAMPLE_INFO)
        self.extract_error: str | None = None
        self.download_error: str | None = None
        self.release = threading.Event()
        self.release.set()
        self.options: list[dict[str, Any]] = []


class FakeYoutubeDL:
    scenario: Scenario

    def __init__(self, options: dict[str, Any]) -> None:
        self.options = options
        self.scenario.options.append(options)

    def __enter__(self) -> "FakeYoutubeDL":
        return self

    def __exit__(self, *_: object) -> None:
        return None

    def extract_info(self, url: str, download: bool = True) -> dict[str, Any]:
        if self.scenario.extract_error:
            raise DownloadError(self.scenario.extract_error)
        return copy.deepcopy(self.scenario.info)

    def process_ie_result(self, info: dict[str, Any], download: bool = True) -> dict[str, Any]:
        self.scenario.release.wait(timeout=5)
        if self.scenario.download_error:
            raise DownloadError(self.scenario.download_error)
        job_dir = Path(self.options["paths"]["home"])
        total = len(FILE_CONTENT)
        for hook in self.options["progress_hooks"]:
            hook({"status": "downloading", "filename": str(job_dir / "part"), "downloaded_bytes": total // 2, "total_bytes": total})
            hook({"status": "finished", "filename": str(job_dir / "part")})
        extension = "mp4" if "merge_output_format" in self.options else "m4a"
        (job_dir / f"media.{extension}").write_bytes(FILE_CONTENT)
        return info


@pytest.fixture
def scenario(monkeypatch: pytest.MonkeyPatch) -> Scenario:
    current = Scenario()
    monkeypatch.setattr(FakeYoutubeDL, "scenario", current, raising=False)
    monkeypatch.setattr(yt_dlp, "YoutubeDL", FakeYoutubeDL)
    return current


@pytest.fixture
def settings(tmp_path: Path) -> Settings:
    return Settings(api_token=TOKEN, download_dir=tmp_path / "downloads", job_ttl_seconds=60)


@pytest.fixture
def client(settings: Settings, scenario: Scenario):
    with TestClient(create_app(settings)) as test_client:
        yield test_client
    scenario.release.set()


@pytest.fixture
def auth() -> dict[str, str]:
    return {"Authorization": f"Bearer {TOKEN}"}


def wait_for_job(client: TestClient, job_id: str, auth: dict[str, str], timeout: float = 5.0) -> dict[str, Any]:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        body = client.get(f"/v1/jobs/{job_id}", headers=auth).json()
        if body["status"] in (JobStatus.READY, JobStatus.FAILED):
            return body
        time.sleep(0.02)
    raise AssertionError(f"job {job_id} não terminou a tempo")
