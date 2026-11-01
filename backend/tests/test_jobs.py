import threading
import time
import uuid

import pytest

from tests.conftest import FILE_CONTENT, VIDEO_URL, wait_for_job


def create_job(client, auth, preset_id="best_mp4"):
    response = client.post("/v1/jobs", json={"url": VIDEO_URL, "preset_id": preset_id}, headers=auth)
    assert response.status_code == 202
    return response.json()["job_id"]


def test_job_lifecycle_video(client, auth, settings):
    job_id = create_job(client, auth)
    assert uuid.UUID(job_id)

    body = wait_for_job(client, job_id, auth)
    assert body["status"] == "ready"
    assert body["progress"] == 1.0
    assert body["file_size_bytes"] == len(FILE_CONTENT)
    assert body["file_name"] == "Vídeo de teste_ parte 1_2.mp4"
    assert body["error_code"] is None

    response = client.get(f"/v1/jobs/{job_id}/file", headers=auth)
    assert response.status_code == 200
    assert response.content == FILE_CONTENT
    assert response.headers["content-type"] == "video/mp4"
    assert response.headers["content-length"] == str(len(FILE_CONTENT))
    assert response.headers["accept-ranges"] == "bytes"

    assert client.delete(f"/v1/jobs/{job_id}", headers=auth).status_code == 204
    assert client.get(f"/v1/jobs/{job_id}", headers=auth).status_code == 404
    assert not (settings.download_dir / job_id).exists()


def test_job_audio_preset_serves_m4a(client, auth, scenario):
    job_id = create_job(client, auth, "audio_m4a")
    body = wait_for_job(client, job_id, auth)
    assert body["status"] == "ready"
    assert body["file_name"].endswith(".m4a")
    options = scenario.options[-1]
    assert options["postprocessors"] == [{"key": "FFmpegExtractAudio", "preferredcodec": "m4a"}]
    response = client.get(f"/v1/jobs/{job_id}/file", headers=auth)
    assert response.headers["content-type"] == "audio/mp4"


def test_video_job_uses_mp4_merge(client, auth, scenario):
    job_id = create_job(client, auth, "mp4_720")
    wait_for_job(client, job_id, auth)
    options = scenario.options[-1]
    assert options["merge_output_format"] == "mp4"
    assert options["noplaylist"] is True
    assert "[height<=720]" in options["format"]


def test_file_supports_range(client, auth):
    job_id = create_job(client, auth)
    wait_for_job(client, job_id, auth)

    response = client.get(f"/v1/jobs/{job_id}/file", headers={**auth, "Range": "bytes=100-199"})
    assert response.status_code == 206
    assert response.content == FILE_CONTENT[100:200]
    assert response.headers["content-range"] == f"bytes 100-199/{len(FILE_CONTENT)}"
    assert response.headers["content-length"] == "100"

    response = client.get(f"/v1/jobs/{job_id}/file", headers={**auth, "Range": "bytes=10000-"})
    assert response.status_code == 206
    assert response.content == FILE_CONTENT[10000:]


def test_file_returns_409_while_preparing(client, auth, scenario):
    scenario.release.clear()
    job_id = create_job(client, auth)
    try:
        status = client.get(f"/v1/jobs/{job_id}", headers=auth).json()["status"]
        assert status in ("queued", "preparing")
        response = client.get(f"/v1/jobs/{job_id}/file", headers=auth)
        assert response.status_code == 409
        assert response.json()["error_code"] == "job_not_ready"
    finally:
        scenario.release.set()
    assert wait_for_job(client, job_id, auth)["status"] == "ready"


def test_delete_while_preparing_cancels_job(client, auth, scenario, settings):
    scenario.release.clear()
    job_id = create_job(client, auth)
    assert client.delete(f"/v1/jobs/{job_id}", headers=auth).status_code == 204
    scenario.release.set()
    assert client.get(f"/v1/jobs/{job_id}", headers=auth).status_code == 404


def test_download_threads_are_daemon_so_shutdown_never_waits(client, auth, scenario):
    scenario.release.clear()
    try:
        job_id = create_job(client, auth)
        thread = next(t for t in threading.enumerate() if t.name == f"download-{job_id}")
        assert thread.daemon
    finally:
        scenario.release.set()


def test_at_most_max_concurrent_jobs_prepare_at_once(client, auth, scenario, settings):
    assert settings.max_concurrent_jobs == 2
    scenario.release.clear()
    try:
        job_ids = [create_job(client, auth) for _ in range(3)]
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            statuses = [client.get(f"/v1/jobs/{j}", headers=auth).json()["status"] for j in job_ids]
            if statuses.count("preparing") == 2:
                break
            time.sleep(0.02)
        assert sorted(statuses) == ["preparing", "preparing", "queued"]
    finally:
        scenario.release.set()
    assert all(wait_for_job(client, j, auth)["status"] == "ready" for j in job_ids)


def test_failed_download_reports_error(client, auth, scenario, settings):
    scenario.download_error = "ERROR: [youtube] abc123: Video unavailable"
    job_id = create_job(client, auth)
    body = wait_for_job(client, job_id, auth)
    assert body["status"] == "failed"
    assert body["error_code"] == "video_unavailable"
    assert body["error_message"]
    assert client.get(f"/v1/jobs/{job_id}/file", headers=auth).status_code == 409
    assert not (settings.download_dir / job_id).exists()


def test_live_video_job_fails_as_unsupported(client, auth, scenario):
    scenario.info["is_live"] = True
    body = wait_for_job(client, create_job(client, auth), auth)
    assert body["status"] == "failed"
    assert body["error_code"] == "unsupported_content"


def test_create_job_rejects_unknown_preset(client, auth):
    response = client.post("/v1/jobs", json={"url": VIDEO_URL, "preset_id": "4k"}, headers=auth)
    assert response.status_code == 400
    assert response.json()["error_code"] == "invalid_preset"


def test_create_job_rejects_invalid_url(client, auth):
    response = client.post("/v1/jobs", json={"url": "https://example.com", "preset_id": "best_mp4"}, headers=auth)
    assert response.status_code == 400
    assert response.json()["error_code"] == "invalid_url"


def test_unknown_job_returns_404(client, auth):
    response = client.get(f"/v1/jobs/{uuid.uuid4()}", headers=auth)
    assert response.status_code == 404
    assert response.json()["error_code"] == "job_not_found"


@pytest.mark.parametrize("job_id", ["..", "not-a-uuid", "%2E%2E"])
def test_non_uuid_job_id_is_rejected(client, auth, settings, job_id):
    response = client.delete(f"/v1/jobs/{job_id}", headers=auth)
    assert response.status_code in (400, 404)
    assert settings.download_dir.exists()


def test_delete_unknown_job_is_idempotent(client, auth):
    assert client.delete(f"/v1/jobs/{uuid.uuid4()}", headers=auth).status_code == 204
