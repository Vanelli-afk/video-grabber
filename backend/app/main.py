import asyncio
import contextlib
import logging
import uuid
from collections.abc import AsyncIterator
from concurrent.futures import ThreadPoolExecutor

from fastapi import APIRouter, Depends, FastAPI, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse, JSONResponse
from yt_dlp.version import __version__ as ytdlp_version

from app.config import Settings
from app.errors import APIError
from app.models import CreateJobRequest, CreateJobResponse, HealthResponse, JobResponse, JobStatus, ResolveRequest, ResolveResponse
from app.security import require_token
from app.services.downloader import run_download
from app.services.jobs import Job, JobRegistry
from app.services.resolver import PRESETS, resolve, validate_url

logger = logging.getLogger("videograbber")


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings()
    registry = JobRegistry(settings.download_dir, settings.job_ttl_seconds)

    @contextlib.asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        settings.download_dir.mkdir(parents=True, exist_ok=True)
        registry.remove_orphan_dirs()
        app.state.executor = ThreadPoolExecutor(
            max_workers=settings.max_concurrent_jobs, thread_name_prefix="download"
        )
        cleanup = asyncio.create_task(_cleanup_loop(registry, settings.cleanup_interval_seconds))
        yield
        cleanup.cancel()
        app.state.executor.shutdown(wait=False, cancel_futures=True)

    # Servidor pessoal: sem páginas de documentação públicas e sem CORS.
    app = FastAPI(title="VideoGrabber API", lifespan=lifespan, docs_url=None, redoc_url=None, openapi_url=None)
    app.state.settings = settings
    app.state.registry = registry

    @app.exception_handler(APIError)
    async def handle_api_error(_: Request, exc: APIError) -> JSONResponse:
        return JSONResponse(status_code=exc.status_code, content={"error_code": exc.error_code, "message": exc.message})

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(_: Request, __: RequestValidationError) -> JSONResponse:
        return JSONResponse(status_code=400, content={"error_code": "invalid_request", "message": "Requisição inválida."})

    @app.get("/health")
    async def health() -> HealthResponse:
        return HealthResponse(ytdlp_version=ytdlp_version)

    router = APIRouter(prefix="/v1", dependencies=[Depends(require_token)])

    @router.post("/resolve")
    async def resolve_url(body: ResolveRequest) -> ResolveResponse:
        url = validate_url(body.url)
        return await asyncio.to_thread(resolve, url)

    @router.post("/jobs", status_code=202)
    async def create_job(body: CreateJobRequest, request: Request) -> CreateJobResponse:
        url = validate_url(body.url)
        if body.preset_id not in PRESETS:
            raise APIError(400, "invalid_preset", "Preset desconhecido.")
        job = registry.create(url, body.preset_id)
        request.app.state.executor.submit(run_download, job.id, registry)
        return CreateJobResponse(job_id=job.id)

    @router.get("/jobs/{job_id}")
    async def job_status(job_id: uuid.UUID) -> JobResponse:
        job = _get_job(registry, job_id)
        return JobResponse(
            job_id=job.id,
            status=job.status,
            progress=round(job.progress, 4),
            file_size_bytes=job.file_size_bytes,
            file_name=job.file_name,
            error_code=job.error_code,
            error_message=job.error_message,
        )

    @router.get("/jobs/{job_id}/file")
    async def job_file(job_id: uuid.UUID) -> FileResponse:
        job = _get_job(registry, job_id)
        if job.status != JobStatus.READY or job.file_path is None or not job.file_path.is_file():
            raise APIError(409, "job_not_ready", "O arquivo ainda não está pronto.")
        media_type = "video/mp4" if PRESETS[job.preset_id].kind == "video" else "audio/mp4"
        # FileResponse já responde Range (206), Accept-Ranges e Content-Length.
        return FileResponse(job.file_path, media_type=media_type, filename=job.file_name)

    @router.delete("/jobs/{job_id}", status_code=204)
    async def delete_job(job_id: uuid.UUID) -> Response:
        registry.delete(str(job_id))
        return Response(status_code=204)

    app.include_router(router)
    return app


def _get_job(registry: JobRegistry, job_id: uuid.UUID) -> Job:
    job = registry.get(str(job_id))
    if job is None:
        raise APIError(404, "job_not_found", "Job não encontrado.")
    return job


async def _cleanup_loop(registry: JobRegistry, interval_seconds: int) -> None:
    while True:
        await asyncio.sleep(interval_seconds)
        removed = registry.purge_expired()
        if removed:
            logger.info("Limpeza por TTL removeu %d job(s)", removed)
