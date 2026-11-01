import uuid

from app.models import JobStatus
from app.services.jobs import JobRegistry


class FakeClock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


def make_registry(tmp_path, ttl=60):
    clock = FakeClock()
    return JobRegistry(tmp_path, ttl_seconds=ttl, clock=clock), clock


def ready_job(registry, tmp_path):
    job = registry.create("https://youtu.be/abc", "best_mp4")
    job_dir = registry.job_dir(job.id)
    job_dir.mkdir()
    (job_dir / "media.mp4").write_bytes(b"data")
    registry.mark_ready(job.id, job_dir / "media.mp4", "video.mp4")
    return job.id


def test_ttl_purges_finished_jobs_and_files(tmp_path):
    registry, clock = make_registry(tmp_path, ttl=60)
    job_id = ready_job(registry, tmp_path)

    clock.now += 59
    assert registry.purge_expired() == 0
    assert registry.get(job_id) is not None

    clock.now += 1
    assert registry.purge_expired() == 1
    assert registry.get(job_id) is None
    assert not registry.job_dir(job_id).exists()


def test_ttl_keeps_jobs_still_preparing(tmp_path):
    registry, clock = make_registry(tmp_path, ttl=60)
    job = registry.create("https://youtu.be/abc", "best_mp4")
    registry.mark_preparing(job.id)
    clock.now += 10_000
    assert registry.purge_expired() == 0
    assert registry.get(job.id).status == JobStatus.PREPARING


def test_ttl_purges_failed_jobs(tmp_path):
    registry, clock = make_registry(tmp_path, ttl=60)
    job = registry.create("https://youtu.be/abc", "best_mp4")
    registry.mark_failed(job.id, "extractor_failed", "falhou")
    clock.now += 60
    assert registry.purge_expired() == 1


def test_get_returns_snapshot(tmp_path):
    registry, _ = make_registry(tmp_path)
    job = registry.create("https://youtu.be/abc", "best_mp4")
    snapshot = registry.get(job.id)
    snapshot.progress = 0.9
    assert registry.get(job.id).progress == 0.0


def test_progress_is_clamped(tmp_path):
    registry, _ = make_registry(tmp_path)
    job = registry.create("https://youtu.be/abc", "best_mp4")
    registry.set_progress(job.id, 1.7)
    assert registry.get(job.id).progress == 1.0


def test_remove_orphan_dirs_only_touches_uuid_folders(tmp_path):
    registry, _ = make_registry(tmp_path)
    orphan = tmp_path / str(uuid.uuid4())
    orphan.mkdir()
    keep = tmp_path / "nao-apagar"
    keep.mkdir()
    active = registry.create("https://youtu.be/abc", "best_mp4")
    registry.job_dir(active.id).mkdir()

    registry.remove_orphan_dirs()

    assert not orphan.exists()
    assert keep.exists()
    assert registry.job_dir(active.id).exists()


def test_delete_ignores_non_uuid_ids(tmp_path):
    registry, _ = make_registry(tmp_path)
    assert registry.delete("..") is False
    assert tmp_path.exists()
