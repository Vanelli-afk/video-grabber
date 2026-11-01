import pytest

from app.services.downloader import DOWNLOAD_PROGRESS_CAP, ProgressTracker, display_file_name, ydl_options
from app.services.resolver import PRESETS


def event(filename, downloaded, total):
    return {"status": "downloading", "filename": filename, "downloaded_bytes": downloaded, "total_bytes": total}


def test_progress_tracker_combines_video_and_audio_parts():
    tracker = ProgressTracker(expected_parts=2)
    assert tracker.update(event("video", 50, 100)) == pytest.approx(0.25 * DOWNLOAD_PROGRESS_CAP)
    assert tracker.update(event("video", 100, 100)) == pytest.approx(0.5 * DOWNLOAD_PROGRESS_CAP)
    assert tracker.update(event("audio", 50, 100)) == pytest.approx(0.75 * DOWNLOAD_PROGRESS_CAP)
    assert tracker.update(event("audio", 100, 100)) == pytest.approx(DOWNLOAD_PROGRESS_CAP)


def test_progress_tracker_without_total_reports_zero_fraction():
    tracker = ProgressTracker(expected_parts=1)
    assert tracker.update({"status": "downloading", "filename": "a", "downloaded_bytes": 10}) == 0.0


def test_progress_tracker_uses_estimate_and_never_exceeds_cap():
    tracker = ProgressTracker(expected_parts=1)
    value = tracker.update({"filename": "a", "downloaded_bytes": 300, "total_bytes_estimate": 200})
    assert value == pytest.approx(DOWNLOAD_PROGRESS_CAP)


@pytest.mark.parametrize(
    ("title", "expected"),
    [
        ("Vídeo: parte 1/2", "Vídeo_ parte 1_2.mp4"),
        ("  ...  ", "abc.mp4"),
        ("a" * 300, "a" * 150 + ".mp4"),
    ],
)
def test_display_file_name_is_safe(title, expected):
    assert display_file_name(title, "abc", "mp4") == expected


def test_ydl_options_never_use_shell_and_disable_playlists():
    options = ydl_options(PRESETS["best_mp4"], "/tmp/job", hook=lambda _: None)
    assert options["noplaylist"] is True
    assert options["merge_output_format"] == "mp4"
    assert options["paths"] == {"home": "/tmp/job"}
    assert options["outtmpl"] == "media.%(ext)s"
    assert "exec" not in options
