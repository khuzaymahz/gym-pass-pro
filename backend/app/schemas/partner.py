from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class PartnerDashboardMetrics(BaseModel):
    checkins_today: int = Field(alias="checkinsToday")
    checkins_this_month: int = Field(alias="checkinsThisMonth")
    checkins_last_30_days: int = Field(alias="checkinsLast30Days")
    unique_members_last_30_days: int = Field(alias="uniqueMembersLast30Days")
    revenue_mtd_jod: str = Field(alias="revenueMtdJod")
    pending_payout_total_jod: str = Field(alias="pendingPayoutTotalJod")
    paid_payout_mtd_jod: str = Field(alias="paidPayoutMtdJod")
    checkins_per_day: list[dict[str, Any]] = Field(alias="checkinsPerDay")
    revenue_per_day: list[dict[str, Any]] = Field(alias="revenuePerDay")
    tier_breakdown: dict[str, int] = Field(alias="tierBreakdown")
    hour_breakdown: list[dict[str, Any]] = Field(alias="hourBreakdown")
    recent_checkins: list[dict[str, Any]] = Field(alias="recentCheckins")

    model_config = ConfigDict(populate_by_name=True)


class CreatePartnerRequest(BaseModel):
    """Admin → create gym-owner login for an existing gym.

    Phone is the Jordanian mobile that becomes the partner's username;
    password is set immediately (no invite-link flow in v1, partners
    receive credentials out of band by their account manager).
    """

    phone: str = Field(min_length=8, max_length=32)
    name: str = Field(min_length=1, max_length=128)
    password: str = Field(min_length=8, max_length=128)

    model_config = ConfigDict(populate_by_name=True)


class PartnerOwnerRead(BaseModel):
    id: str
    phone: str
    name: str | None
    gym_id: str = Field(alias="gymId")

    model_config = ConfigDict(populate_by_name=True)
