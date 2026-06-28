from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.db.enums import CheckinStatus


class CheckinScanRequest(BaseModel):
    qr_payload: str = Field(alias="qrPayload", min_length=1, max_length=2048)

    model_config = ConfigDict(populate_by_name=True)


class CheckinResult(BaseModel):
    status: CheckinStatus
    checkin_id: UUID | None = Field(alias="checkinId", default=None)
    gym_id: UUID | None = Field(alias="gymId", default=None)
    gym_name_en: str | None = Field(alias="gymNameEn", default=None)
    scanned_at: datetime | None = Field(alias="scannedAt", default=None)
    remaining_visits: int | None = Field(alias="remainingVisits", default=None)
    reason: str | None = None

    model_config = ConfigDict(populate_by_name=True)


class CheckinHistoryItem(BaseModel):
    id: UUID
    gym_id: UUID = Field(alias="gymId")
    gym_name_en: str = Field(alias="gymNameEn")
    scanned_at: datetime = Field(alias="scannedAt")
    status: CheckinStatus

    model_config = ConfigDict(populate_by_name=True)
