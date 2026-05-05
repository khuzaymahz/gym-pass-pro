from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.db.enums import NotificationType


class NotificationRead(BaseModel):
    id: UUID
    type: NotificationType
    title_en: str = Field(alias="titleEn")
    title_ar: str = Field(alias="titleAr")
    body_en: str = Field(alias="bodyEn")
    body_ar: str = Field(alias="bodyAr")
    deep_link: str | None = Field(alias="deepLink", default=None)
    read_at: datetime | None = Field(alias="readAt", default=None)
    created_at: datetime = Field(alias="createdAt")

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)
