from fastapi.responses import JSONResponse


class APIError(Exception):
    """Erro de negócio convertido em resposta JSON `{error_code, message}`."""

    def __init__(self, status_code: int, error_code: str, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.error_code = error_code
        self.message = message


def error_response(status_code: int, error_code: str, message: str) -> JSONResponse:
    """Único formato de erro da API (docs/API.md)."""
    return JSONResponse(status_code=status_code, content={"error_code": error_code, "message": message})
