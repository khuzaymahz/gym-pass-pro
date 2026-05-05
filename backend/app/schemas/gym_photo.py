from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class GymPhotoRead(BaseModel):
    id: UUID
    url: str
    sort_order: int = Field(alias="sortOrder")
    alt_text_en: str | None = Field(alias="altTextEn", default=None)
    alt_text_ar: str | None = Field(alias="altTextAr", default=None)

    model_config = ConfigDict(populate_by_name=True, from_attributes=True)


class GymPhotoUpdate(BaseModel):
    """Partial update — reorder (drag-to-reorder in the admin panel) or
    correct alt text without replacing the image. The image file itself is
    replaced by uploading a new photo (and deleting the old one)."""

    sort_order: int | None = Field(alias="sortOrder", default=None, ge=0)
    alt_text_en: str | None = Field(alias="altTextEn", default=None, max_length=200)
    alt_text_ar: str | None = Field(alias="altTextAr", default=None, max_length=200)

    model_config = ConfigDict(populate_by_name=True)
