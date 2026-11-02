import secrets

from fastapi import Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.errors import APIError, error_response

_bearer = HTTPBearer(auto_error=False)

# As requisições do app têm menos de 1 KB.
MAX_BODY_BYTES = 64 * 1024


async def require_token(request: Request) -> None:
    credentials: HTTPAuthorizationCredentials | None = await _bearer(request)
    expected = request.app.state.settings.api_token
    if credentials is None or not secrets.compare_digest(
        credentials.credentials.encode(), expected.encode()
    ):
        raise APIError(401, "unauthorized", "Token ausente ou inválido.")


class BodySizeLimitMiddleware:
    """Recusa corpos grandes sem carregá-los inteiros na memória.

    O FastAPI lê o corpo antes de rodar as dependências (inclusive a do token), então sem
    isto qualquer aparelho da rede faria o servidor guardar um corpo enorme na memória.
    """

    def __init__(self, app: ASGIApp, max_bytes: int = MAX_BODY_BYTES) -> None:
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        length = dict(scope["headers"]).get(b"content-length")
        if length is not None:
            if not length.isdigit() or int(length) > self.max_bytes:
                await self._reject(scope, receive, send)
                return
            await self.app(scope, receive, send)
            return

        # Sem Content-Length (corpo em partes, ex.: atrás de um proxy): lê até o limite e repassa.
        body = bytearray()
        while True:
            message = await receive()
            if message["type"] != "http.request":
                return  # cliente desconectou
            body += message.get("body", b"")
            if len(body) > self.max_bytes:
                await self._reject(scope, receive, send)
                return
            if not message.get("more_body", False):
                break

        delivered = False

        async def replay() -> Message:
            nonlocal delivered
            if not delivered:
                delivered = True
                return {"type": "http.request", "body": bytes(body), "more_body": False}
            return await receive()

        await self.app(scope, replay, send)

    @staticmethod
    async def _reject(scope: Scope, receive: Receive, send: Send) -> None:
        await error_response(413, "payload_too_large", "Requisição grande demais.")(scope, receive, send)
