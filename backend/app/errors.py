class APIError(Exception):
    """Erro de negócio convertido em resposta JSON `{error_code, message}`."""

    def __init__(self, status_code: int, error_code: str, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.error_code = error_code
        self.message = message
