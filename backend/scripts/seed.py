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

# Dev seed gym network — real Jordan locations + plausible gym
# names following local naming conventions. Lat/lng are accurate
# for the AREA centre (verify the exact coordinate against a real
# venue when a partner actually onboards). Areas span:
#   Amman (10) · Zarqa (2) · Irbid (2) · Aqaba (1)
# Tier mix: 5 silver / 5 gold / 4 platinum / 2 diamond.
# Category mix: 8 gym / 3 crossfit / 3 yoga / 2 martial.
#
# Tuple shape: (slug, name_en, name_ar, area, city, category, tier, lat, lng)
GYMS: list[tuple[str, str, str, str, str, "Category", "Tier", float, float]] = [
    # ── Amman: upscale (Abdoun, Dabouq, 5th Circle) ──
    ("iron-forge",      "Iron Forge",         "آيرون فورج",          "Abdoun",       "Amman", Category.GYM,      Tier.SILVER,   31.9560, 35.8786),
    ("halo-studio",     "Halo Studio",        "هالو ستوديو",          "Abdoun",       "Amman", Category.YOGA,     Tier.SILVER,   31.9582, 35.8801),
    ("core-athletic",   "Core Athletic",      "كور أثلتك",           "Dabouq",       "Amman", Category.GYM,      Tier.DIAMOND,  32.0083, 35.8200),
    ("apex-crossfit",   "Apex CrossFit",      "إيبكس كروسفت",        "Khalda",       "Amman", Category.CROSSFIT, Tier.GOLD,     31.9882, 35.8307),
    ("pulse-fitness",   "Pulse Fitness",      "بَلْس فِتنِس",          "5th Circle",   "Amman", Category.GYM,      Tier.PLATINUM, 31.9550, 35.9050),
    ("zen-yoga",        "Zen Yoga House",     "زن لليوغا",            "Jabal Webdeh", "Amman", Category.YOGA,     Tier.GOLD,     31.9580, 35.9128),

    # ── Amman: residential / family-friendly ──
    ("bedford-yoga",    "Bedford Yoga",       "بدفورد لليوغا",        "Sweifieh",     "Amman", Category.YOGA,     Tier.GOLD,     31.9693, 35.8688),
    ("body-master",     "Body Master Gym",    "بودي ماستر",          "Tlaa al-Ali",  "Amman", Category.GYM,      Tier.SILVER,   31.9836, 35.8500),
    ("nordic-fit",      "Nordic Fitness",     "نوردك فتنس",          "Jubeiha",      "Amman", Category.GYM,      Tier.SILVER,   32.0167, 35.8806),
    ("fortis-boxing",   "Fortis Boxing Club", "فورتس للملاكمة",      "Jabal Amman",  "Amman", Category.MARTIAL,  Tier.PLATINUM, 31.9540, 35.9319),

    # ── Amman: north / sweileh / shmeisani ──
    ("the-floor",       "The Floor CrossFit", "ذا فلور كروسفت",      "Sweileh",      "Amman", Category.CROSSFIT, Tier.GOLD,     32.0367, 35.8400),
    ("royal-pilates",   "Royal Pilates",      "رويال للبيلاتيس",      "Shmeisani",    "Amman", Category.YOGA,     Tier.PLATINUM, 31.9682, 35.9046),
    ("strength-academy","Strength Academy",   "أكاديمية القوة",       "Wasfi al-Tal", "Amman", Category.GYM,      Tier.GOLD,     31.9893, 35.8783),

    # ── Zarqa ──
    ("zarqa-power",     "Zarqa Power Gym",    "نادي الزرقاء للقوة",   "Zarqa Centre", "Zarqa", Category.GYM,      Tier.SILVER,   32.0728, 36.0876),
    ("phoenix-mma",     "Phoenix MMA",        "فينكس للفنون القتالية","Zarqa New",    "Zarqa", Category.MARTIAL,  Tier.GOLD,     32.0850, 36.1010),

    # ── Irbid ──
    ("irbid-athletic",  "Irbid Athletic",     "إربد الرياضي",         "Hashmi",       "Irbid", Category.GYM,      Tier.GOLD,     32.5556, 35.8500),
    ("northern-crossfit","Northern CrossFit", "الشمال كروسفت",        "Yarmouk",      "Irbid", Category.CROSSFIT, Tier.PLATINUM, 32.5430, 35.8650),

    # ── Aqaba ──
    ("ayla-wellness",   "Ayla Wellness Club", "آيلا للعافية",        "Tala Bay",     "Aqaba", Category.GYM,      Tier.DIAMOND,  29.5267, 35.0019),
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
    "pulse-fitness": [
        ("https://images.unsplash.com/photo-1605296867424-35fc25c9212a?w=1200", "Cardio floor", "صالة الكارديو"),
        ("https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=1200", "Functional zone", "منطقة التدريب الوظيفي"),
    ],
    "zen-yoga": [
        ("https://images.unsplash.com/photo-1545205597-3d9d02c29597?w=1200", "Main studio", "الاستوديو الرئيسي"),
        ("https://images.unsplash.com/photo-1591291621164-2c6367723315?w=1200", "Meditation room", "غرفة التأمل"),
    ],
    "body-master": [
        ("https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=1200", "Strength floor", "أرضية القوة"),
    ],
    "nordic-fit": [
        ("https://images.unsplash.com/photo-1576678927484-cc907957088c?w=1200", "Group class", "صف جماعي"),
    ],
    "the-floor": [
        ("https://images.unsplash.com/photo-1526506118085-60ce8714f8c5?w=1200", "Rig + rowers", "المنصة والمجاديف"),
        ("https://images.unsplash.com/photo-1517466787929-bc90951d0974?w=1200", "Olympic platforms", "منصات الرفع"),
    ],
    "royal-pilates": [
        ("https://images.unsplash.com/photo-1601925260368-ae2f83cf8b7f?w=1200", "Reformer studio", "استوديو الريفورمر"),
    ],
    "strength-academy": [
        ("https://images.unsplash.com/photo-1583500178690-f7ddeae9b1b9?w=1200", "Powerlifting", "رفع الأثقال"),
    ],
    "zarqa-power": [
        ("https://images.unsplash.com/photo-1574680178050-55c6a6a96e0a?w=1200", "Main hall", "الصالة الرئيسية"),
    ],
    "phoenix-mma": [
        ("https://images.unsplash.com/photo-1517438476312-10d79c5f25a9?w=1200", "Mat area", "منطقة الحصير"),
    ],
    "irbid-athletic": [
        ("https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1200", "Training floor", "أرضية التدريب"),
    ],
    "northern-crossfit": [
        ("https://images.unsplash.com/photo-1518611012118-696072aa579a?w=1200", "Box", "القاعة"),
    ],
    "ayla-wellness": [
        ("https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=1200", "Cardio overlook", "إطلالة الكارديو"),
        ("https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=1200", "Pool deck", "حافة المسبح"),
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

        # Arabic city name lookup so addresses render natively in the
        # mobile app's AR locale.
        ar_city = {
            "Amman": "عمّان",
            "Zarqa": "الزرقاء",
            "Irbid": "إربد",
            "Aqaba": "العقبة",
        }
        # Gyms — idempotent per slug. A previous version of this seed
        # short-circuited if ANY gym existed, which made it impossible
        # to grow the dev network in-place when this list was expanded
        # to cover the full Jordan footprint. Now we insert any slug
        # that isn't already present and leave existing rows (with
        # their checkins / photos / payouts) untouched.
        existing_gyms = (await session.execute(select(Gym))).scalars().all()
        existing_slugs = {g.slug for g in existing_gyms}
        for slug, name_en, name_ar, area, city, category, tier, lat, lng in GYMS:
            if slug in existing_slugs:
                continue
            gym = Gym(
                id=uuid7(),
                slug=slug,
                name_en=name_en,
                name_ar=name_ar,
                address_en=f"{area}, {city}",
                address_ar=f"{area}, {ar_city.get(city, city)}",
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
