import secrets

from fastapi import Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.errors import APIError

_bearer = HTTPBearer(auto_error=False)


async def require_token(request: Request) -> None:
    credentials: HTTPAuthorizationCredentials | None = await _bearer(request)
    expected = request.app.state.settings.api_token
    if credentials is None or not secrets.compare_digest(
        credentials.credentials.encode(), expected.encode()
    ):
        raise APIError(401, "unauthorized", "Token ausente ou inválido.")
