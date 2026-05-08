"""Dev seed script. Run with: `uv run python -m scripts.seed` inside the backend container."""

from __future__ import annotations

import asyncio
from decimal import Decimal

from sqlalchemy import select

from app.config import get_settings
from app.core.security import hash_password
from app.db.enums import Category, Locale, Role, Tier
from app.db.models import Gym, GymPhoto, Plan, User
from app.db.session import get_engine
from sqlalchemy.ext.asyncio import async_sessionmaker
from app.utils.ids import uuid7

GYMS = [
    ("iron-forge", "Iron Forge", "ايرون فورج", "Abdoun", Category.GYM, Tier.SILVER, 31.955, 35.877),
    ("bedford-yoga", "Bedford Yoga", "بدفورد لليوغا", "Sweifieh", Category.YOGA, Tier.GOLD, 31.969, 35.869),
    ("fortis-boxing", "Fortis Boxing", "فورتس للملاكمة", "Jabal Amman", Category.MARTIAL, Tier.PLATINUM, 31.954, 35.932),
    ("apex-crossfit", "Apex CrossFit", "إيبكس كروسفت", "Khalda", Category.CROSSFIT, Tier.GOLD, 31.988, 35.830),
    ("halo-studio", "Halo Studio", "هالو ستديو", "Abdoun", Category.YOGA, Tier.SILVER, 31.958, 35.880),
    ("core-athletic", "Core Athletic", "كور أثليتيك", "Dabouq", Category.GYM, Tier.DIAMOND, 32.010, 35.820),
]

TIER_MONTHLY_PRICE: dict[Tier, Decimal] = {
    Tier.SILVER: Decimal("25"),
    Tier.GOLD: Decimal("45"),
    Tier.PLATINUM: Decimal("75"),
    Tier.DIAMOND: Decimal("110"),
}
# All tiers share the same monthly visit cap; the tier differentiator is the
# *gym network* (entry / mid / premium / full), not the number of visits.
TIER_MONTHLY_VISITS: dict[Tier, int] = {
    Tier.SILVER: 30,
    Tier.GOLD: 30,
    Tier.PLATINUM: 30,
    Tier.DIAMOND: 30,
}
TIER_INCLUDED_GYMS: dict[Tier, int] = {
    Tier.SILVER: 10,
    Tier.GOLD: 25,
    Tier.PLATINUM: 45,
    Tier.DIAMOND: 80,
}
# Longer commitments earn a larger discount off the monthly rate. Any new
# duration added here is automatically seeded for every tier below.
DURATION_DISCOUNT: dict[int, Decimal] = {
    1: Decimal("0"),
    3: Decimal("5"),
    6: Decimal("10"),
    12: Decimal("15"),
}

PLANS: list[tuple[Tier, int]] = [
    (tier, months)
    for tier in (Tier.SILVER, Tier.GOLD, Tier.PLATINUM, Tier.DIAMOND)
    for months in (1, 3, 6, 12)
]


def _plan_price(tier: Tier, months: int) -> Decimal:
    monthly = TIER_MONTHLY_PRICE[tier]
    discount = DURATION_DISCOUNT[months] / Decimal("100")
    gross = monthly * months
    # Quantize to whole JOD so the checkout UI never renders fractional dinars.
    return (gross * (Decimal("1") - discount)).quantize(Decimal("1"))

# All tiers grant 30 visits/month; the differentiator is the gym network.
FEATURES_EN = {
    Tier.SILVER: ["10 entry-level gyms", "30 visits/mo"],
    Tier.GOLD: ["25 gyms · Silver + Gold", "30 visits/mo", "1 guest pass/mo"],
    Tier.PLATINUM: ["45 premium gyms", "30 visits/mo", "2 guest passes/mo"],
    Tier.DIAMOND: ["All 80 partner gyms", "30 visits/mo", "4 guest passes/mo"],
}
FEATURES_AR = {
    Tier.SILVER: ["10 أندية فئة البداية", "30 زيارة شهرياً"],
    Tier.GOLD: ["25 نادياً · الفضة + الذهب", "30 زيارة شهرياً", "دعوة ضيف/شهر"],
    Tier.PLATINUM: ["45 نادياً راقياً", "30 زيارة شهرياً", "دعوتا ضيف/شهر"],
    Tier.DIAMOND: ["جميع الـ80 نادياً شريكاً", "30 زيارة شهرياً", "4 دعوات ضيف/شهر"],
}

# NOTE: gyms intentionally seed with NO logo_url. A logo is a partner
# brand mark uploaded via the admin's POST /admin/gyms/{id}/logo flow
# during real onboarding. The mobile UI renders a tier-coloured
# circle with the gym's initials whenever logo_url is null, which is
# the right "no logo on file" state — re-using a gallery photo as a
# stand-in misleads members about what the gym's brand looks like.

GYM_PHOTOS: dict[str, list[tuple[str, str, str]]] = {
    "iron-forge": [
        ("https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1200", "Main floor", "الصالة الرئيسية"),
        ("https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=1200", "Free weights", "الأوزان الحرة"),
        ("https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=1200", "Squat racks", "حوامل القرفصاء"),
    ],
    "bedford-yoga": [
        ("https://images.unsplash.com/photo-1588286840104-8957b019727f?w=1200", "Studio", "الاستديو"),
        ("https://images.unsplash.com/photo-1599901860904-17e6ed7083a0?w=1200", "Mat room", "غرفة الحصر"),
    ],
    "fortis-boxing": [
        ("https://images.unsplash.com/photo-1549576490-b0b4831ef60a?w=1200", "Ring", "الحلبة"),
        ("https://images.unsplash.com/photo-1544717305-2782549b5136?w=1200", "Heavy bags", "أكياس الملاكمة"),
    ],
    "apex-crossfit": [
        ("https://images.unsplash.com/photo-1534367610401-9f5ed68180aa?w=1200", "Box", "القاعة"),
        ("https://images.unsplash.com/photo-1518611012118-696072aa579a?w=1200", "Rig", "المنصة"),
    ],
    "halo-studio": [
        ("https://images.unsplash.com/photo-1506629082955-511b1aa562c8?w=1200", "Main studio", "الاستديو الرئيسي"),
    ],
    "core-athletic": [
        ("https://images.unsplash.com/photo-1571902943202-507ec2618e8f?w=1200", "Training floor", "أرضية التدريب"),
        ("https://images.unsplash.com/photo-1593079831268-3381b0db4a77?w=1200", "Recovery zone", "منطقة التعافي"),
        ("https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=1200", "Cardio", "الكارديو"),
    ],
}


async def main() -> None:
    settings = get_settings()
    if not settings.is_dev:
        raise SystemExit(
            "seed.py refuses to run when APP_ENV is not 'development'. "
            "Production data must come through real signup/admin flows."
        )
    engine = get_engine()
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with factory() as session:
        # Plans
        # Insert only the (tier, duration) pairs not already seeded, so adding
        # a new duration later doesn't require wiping the plans table first.
        existing_plans = (await session.execute(select(Plan))).scalars().all()
        existing_keys = {(p.tier, p.duration_months) for p in existing_plans}
        for tier, months in PLANS:
            if (tier, months) in existing_keys:
                continue
            session.add(
                Plan(
                    id=uuid7(),
                    tier=tier,
                    duration_months=months,
                    price_jod=_plan_price(tier, months),
                    monthly_visits=TIER_MONTHLY_VISITS[tier],
                    included_gym_count=TIER_INCLUDED_GYMS[tier],
                    features_en=FEATURES_EN[tier],
                    features_ar=FEATURES_AR[tier],
                    discount_percent=DURATION_DISCOUNT[months],
                )
            )

        # Gyms
        existing_gyms = (await session.execute(select(Gym))).scalars().all()
        if not existing_gyms:
            for slug, name_en, name_ar, area, category, tier, lat, lng in GYMS:
                gym = Gym(
                    id=uuid7(),
                    slug=slug,
                    name_en=name_en,
                    name_ar=name_ar,
                    address_en=f"{area}, Amman",
                    address_ar=f"{area}, عمّان",
                    area=area,
                    lat=Decimal(str(lat)),
                    lng=Decimal(str(lng)),
                    category=category,
                    required_tier=tier,
                    per_visit_rate_jod=Decimal("2.00"),
                    amenities=["wifi", "parking", "showers"],
                    opening_hours={"24_7": True},
                )
                session.add(gym)
                await session.flush()
                for order, (url, alt_en, alt_ar) in enumerate(GYM_PHOTOS.get(slug, [])):
                    session.add(
                        GymPhoto(
                            id=uuid7(),
                            gym_id=gym.id,
                            url=url,
                            sort_order=order,
                            alt_text_en=alt_en,
                            alt_text_ar=alt_ar,
                        )
                    )

        # Cleanup: a previous version of this seed wrote unsplash
        # gallery URLs into `logo_url`, which mis-uses the field
        # (logos are partner brand marks, not interior photos).
        # Null any logo whose URL points at unsplash so dev DBs that
        # ran the older seed clear themselves. Real admin-uploaded
        # logos live under the API's media path and are left alone.
        rows = (await session.execute(select(Gym))).scalars().all()
        for row in rows:
            url = row.logo_url
            if url is not None and "unsplash.com" in url:
                row.logo_url = None

        # Admin bootstrap user. No demo member is seeded — real members sign
        # up via the mobile app. CLAUDE.md §4 / memory rule: only OTP + payment
        # are mocked in dev; no demo rows.
        if settings.admin_bootstrap_email and settings.admin_bootstrap_password:
            admin = (await session.execute(
                select(User).where(User.email == settings.admin_bootstrap_email)
            )).scalar_one_or_none()
            if admin is None:
                session.add(
                    User(
                        id=uuid7(),
                        email=settings.admin_bootstrap_email,
                        first_name="GymPass",
                        last_name="Admin",
                        # Mirror legacy `name` so admin list views that still
                        # read it stay coherent until the column is retired.
                        name="GymPass Admin",
                        password_hash=hash_password(settings.admin_bootstrap_password),
                        role=Role.ADMIN,
                        locale=Locale.EN,
                    )
                )

        # Dev partner bootstrap. ONE demo gym-owner linked to the demo
        # gym whose slug matches `partner_bootstrap_gym_slug`. This is
        # the minimum needed for a developer to log into the partner
        # portal without first creating a partner via admin. Fully
        # opt-in — leave any of the partner_bootstrap_* env vars unset
        # to skip. CLAUDE.md §12 rule 9: this is a *bootstrap*, not a
        # demo-data dump. The partner sees real (initially empty)
        # check-ins / payouts; nothing is faked downstream.
        if (
            settings.partner_bootstrap_phone
            and settings.partner_bootstrap_password
            and settings.partner_bootstrap_gym_slug
            and settings.partner_bootstrap_name
        ):
            target_gym = (
                await session.execute(
                    select(Gym).where(
                        Gym.slug == settings.partner_bootstrap_gym_slug
                    )
                )
            ).scalar_one_or_none()
            if target_gym is not None:
                existing_partner = (
                    await session.execute(
                        select(User).where(
                            User.phone == settings.partner_bootstrap_phone
                        )
                    )
                ).scalar_one_or_none()
                if existing_partner is None:
                    session.add(
                        User(
                            id=uuid7(),
                            phone=settings.partner_bootstrap_phone,
                            name=settings.partner_bootstrap_name,
                            password_hash=hash_password(
                                settings.partner_bootstrap_password
                            ),
                            role=Role.GYM_OWNER,
                            gym_id=target_gym.id,
                            locale=Locale.AR,
                        )
                    )

        await session.commit()
        print("Seed complete.")


if __name__ == "__main__":
    asyncio.run(main())
