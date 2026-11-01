from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuração lida das variáveis de ambiente. API_TOKEN é obrigatório."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    api_token: str = Field(min_length=16)
    download_dir: Path = Path("/data/downloads")
    job_ttl_seconds: int = Field(default=7200, gt=0)
    max_concurrent_jobs: int = Field(default=2, gt=0)
    cleanup_interval_seconds: int = Field(default=60, gt=0)
