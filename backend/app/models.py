from enum import StrEnum
from typing import Literal

from pydantic import BaseModel


class JobStatus(StrEnum):
    QUEUED = "queued"
    PREPARING = "preparing"
    READY = "ready"
    FAILED = "failed"


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    ytdlp_version: str


class ResolveRequest(BaseModel):
    url: str


class Preset(BaseModel):
    id: str
    label: str
    kind: Literal["video", "audio"]
    estimated_bytes: int | None


class ResolveResponse(BaseModel):
    video_id: str
    title: str
    channel: str
    duration_seconds: int
    thumbnail_url: str | None
    presets: list[Preset]


class CreateJobRequest(BaseModel):
    url: str
    preset_id: str


class CreateJobResponse(BaseModel):
    job_id: str


class JobResponse(BaseModel):
    job_id: str
    status: JobStatus
    progress: float
    file_size_bytes: int | None
    file_name: str | None
    error_code: str | None
    error_message: str | None
