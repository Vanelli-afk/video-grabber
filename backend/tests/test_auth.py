import pytest
from pydantic import ValidationError

from app.config import Settings
from tests.conftest import VIDEO_URL

PROTECTED_ROUTES = [
    ("post", "/v1/resolve", {"url": VIDEO_URL}),
    ("post", "/v1/jobs", {"url": VIDEO_URL, "preset_id": "best_mp4"}),
    ("get", "/v1/jobs/00000000-0000-0000-0000-000000000000", None),
    ("get", "/v1/jobs/00000000-0000-0000-0000-000000000000/file", None),
    ("delete", "/v1/jobs/00000000-0000-0000-0000-000000000000", None),
]


def test_health_is_public_and_reports_ytdlp_version(client):
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["ytdlp_version"]


@pytest.mark.parametrize(("method", "path", "body"), PROTECTED_ROUTES)
def test_routes_without_token_return_401(client, method, path, body):
    response = client.request(method, path, json=body)
    assert response.status_code == 401
    assert response.json()["error_code"] == "unauthorized"


@pytest.mark.parametrize(("method", "path", "body"), PROTECTED_ROUTES)
def test_routes_with_wrong_token_return_401(client, method, path, body):
    response = client.request(method, path, json=body, headers={"Authorization": "Bearer wrong-token-000000"})
    assert response.status_code == 401


def test_settings_require_api_token(monkeypatch, tmp_path):
    monkeypatch.delenv("API_TOKEN", raising=False)
    monkeypatch.chdir(tmp_path)  # garante que nenhum .env seja lido
    with pytest.raises(ValidationError):
        Settings()


def test_settings_reject_short_token():
    with pytest.raises(ValidationError):
        Settings(api_token="curto")


def test_docs_are_disabled(client):
    assert client.get("/docs").status_code == 404
    assert client.get("/openapi.json").status_code == 404
