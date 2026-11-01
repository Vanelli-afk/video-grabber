import pytest

from app.errors import APIError
from app.services.resolver import PRESETS, estimate_bytes, validate_url
from tests.conftest import SAMPLE_INFO, VIDEO_URL


@pytest.mark.parametrize(
    "url",
    [
        "https://www.youtube.com/watch?v=abc123",
        "https://youtube.com/watch?v=abc123&list=PL123",
        "https://m.youtube.com/watch?v=abc123",
        "https://youtu.be/abc123",
        "http://www.youtube.com/shorts/abc123",
        "  https://youtu.be/abc123  ",
    ],
)
def test_validate_url_accepts_youtube_links(url):
    assert validate_url(url) == url.strip()


@pytest.mark.parametrize(
    "url",
    [
        "",
        "not a url",
        "ftp://www.youtube.com/watch?v=abc123",
        "https://vimeo.com/123",
        "https://youtube.com.evil.example/watch?v=abc123",
        "https://evil.example/?u=https://youtube.com",
        "file:///etc/passwd",
        "https://www.youtube.com/watch?v=" + "a" * 3000,
    ],
)
def test_validate_url_rejects_other_urls(url):
    with pytest.raises(APIError) as error:
        validate_url(url)
    assert error.value.status_code == 400
    assert error.value.error_code == "invalid_url"


def test_validate_url_rejects_playlist_page():
    with pytest.raises(APIError) as error:
        validate_url("https://www.youtube.com/playlist?list=PL123")
    assert error.value.error_code == "unsupported_content"


def test_presets_map_to_h264_aac_mp4_and_m4a():
    assert list(PRESETS) == ["best_mp4", "mp4_720", "audio_m4a"]
    assert PRESETS["best_mp4"].format.startswith("bv*[vcodec^=avc1][height<=1080]+ba[ext=m4a]")
    assert PRESETS["mp4_720"].format.startswith("bv*[vcodec^=avc1][height<=720]+ba[ext=m4a]")
    assert PRESETS["audio_m4a"].format.startswith("ba[ext=m4a]")


def test_estimate_bytes_prefers_avc1_and_m4a():
    formats = SAMPLE_INFO["formats"]
    assert estimate_bytes(PRESETS["best_mp4"], formats) == 103_000_000
    assert estimate_bytes(PRESETS["mp4_720"], formats) == 53_000_000
    assert estimate_bytes(PRESETS["audio_m4a"], formats) == 3_000_000


def test_estimate_bytes_falls_back_to_bitrate_times_duration():
    formats = [
        {"vcodec": "avc1", "acodec": "none", "height": 720, "tbr": 800, "protocol": "m3u8_native"},
        {"vcodec": "none", "acodec": "mp4a", "ext": "m4a", "abr": 128, "filesize": 1_000},
    ]
    assert estimate_bytes(PRESETS["mp4_720"], formats, duration=10) == 1_000_000 + 1_000


def test_estimate_bytes_unknown_size_returns_none():
    formats = [{"vcodec": "avc1", "acodec": "none", "height": 720}, {"vcodec": "none", "acodec": "mp4a", "ext": "m4a"}]
    assert estimate_bytes(PRESETS["mp4_720"], formats) is None


def test_resolve_returns_metadata_and_presets(client, auth, scenario):
    response = client.post("/v1/resolve", json={"url": VIDEO_URL}, headers=auth)
    assert response.status_code == 200
    body = response.json()
    assert body["video_id"] == "abc123"
    assert body["title"] == "Vídeo de teste: parte 1/2"
    assert body["channel"] == "Canal de Teste"
    assert body["duration_seconds"] == 213
    assert body["thumbnail_url"].startswith("https://")
    assert [p["id"] for p in body["presets"]] == ["best_mp4", "mp4_720", "audio_m4a"]
    assert [p["kind"] for p in body["presets"]] == ["video", "video", "audio"]
    assert scenario.options[0]["noplaylist"] is True


def test_resolve_invalid_url_returns_400(client, auth):
    response = client.post("/v1/resolve", json={"url": "https://vimeo.com/1"}, headers=auth)
    assert response.status_code == 400
    assert response.json()["error_code"] == "invalid_url"


def test_resolve_missing_body_returns_400(client, auth):
    response = client.post("/v1/resolve", json={}, headers=auth)
    assert response.status_code == 400
    assert response.json()["error_code"] == "invalid_request"


@pytest.mark.parametrize(
    ("message", "status", "code"),
    [
        ("ERROR: [youtube] abc123: Video unavailable", 404, "video_unavailable"),
        ("ERROR: [youtube] abc123: Private video. Sign in if you've been granted access", 404, "video_unavailable"),
        ("ERROR: [youtube] abc123: This video is DRM protected", 422, "unsupported_content"),
        ("ERROR: [youtube] abc123: Unable to extract player response", 502, "extractor_failed"),
    ],
)
def test_resolve_maps_ytdlp_errors(client, auth, scenario, message, status, code):
    scenario.extract_error = message
    response = client.post("/v1/resolve", json={"url": VIDEO_URL}, headers=auth)
    assert response.status_code == status
    assert response.json()["error_code"] == code


@pytest.mark.parametrize(
    "extra",
    [
        {"is_live": True},
        {"live_status": "is_upcoming"},
        {"_type": "playlist"},
        {"formats": [{"vcodec": "avc1", "acodec": "mp4a", "has_drm": True}]},
    ],
)
def test_resolve_rejects_unsupported_content(client, auth, scenario, extra):
    scenario.info.update(extra)
    response = client.post("/v1/resolve", json={"url": VIDEO_URL}, headers=auth)
    assert response.status_code == 422
    assert response.json()["error_code"] == "unsupported_content"
