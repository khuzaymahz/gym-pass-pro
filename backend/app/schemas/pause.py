from __future__ import annotations

from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class PauseRead(BaseModel):
    """One pause window. `endedAt` distinguishes finalised rows from
    open ones; `daysConsumed` is set on finalisation and is what the
    parent subscription's `expires_at` was shifted by."""

    id: UUID
    subscription_id: UUID = Field(alias="subscriptionId")
    starts_on: date = Field(alias="startsOn")
    ends_on: date = Field(alias="endsOn")
    ended_at: datetime | None = Field(alias="endedAt", default=None)
    days_consumed: int = Field(alias="daysConsumed")
    created_at: datetime = Field(alias="createdAt")

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class PauseCreate(BaseModel):
    starts_on: date = Field(alias="startsOn")
    ends_on: date = Field(alias="endsOn")

    model_config = ConfigDict(populate_by_name=True)
