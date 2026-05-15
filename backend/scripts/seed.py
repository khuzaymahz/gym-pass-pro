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

# OpenStreetMap-imported venues. Provenance is encoded in the slug
# (`<name>-<osm_id>` or `osm-<id>` when the name has no Latin glyphs)
# so an admin can trace a row back to its OSM source. Categories
# default to GYM because OSM's `sport` tag is sparse in Jordan; an
# admin should re-categorise these as part of real partner onboarding.
# Tier assignment is a deterministic scatter (osm_id % 9 weighted
# toward silver/gold) — it carries no claim about the venue's actual
# quality and exists only to make tier-filtering visible in dev.
#
# License: OSM data is © OpenStreetMap contributors, ODbL. The
# explore-map UI attributes both CARTO (tiles) and OSM (POIs).
#
# Data quality notes: a handful of OSM nodes in Jordan are
# mistagged (commercial complexes / tourism agencies wearing a
# `leisure=sports_centre` tag). They survive into the seed because
# fixing OSM upstream is the right place to clean them, not here.
# An admin can deactivate them via the gym list when they show up.
#
# Tuple shape matches GYMS above.
OSM_GYMS: list[tuple[str, str, str, str, str, "Category", "Tier", float, float]] = [
    ('fitness-masters-1932930595', 'Fitness Masters', 'Fitness Masters', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 32.026201, 35.855839),
    ('fitness-gym-2522315951', 'Fitness Gym', 'Fitness Gym', 'Amman', 'Amman', Category.GYM, Tier.DIAMOND, 31.955426, 35.928051),
    ('caucasian-club-4172942049', 'Caucasian Club', 'النادي القوقازي', 'Zarqa', 'Zarqa', Category.GYM, Tier.PLATINUM, 32.061387, 36.088014),
    ('wider-4220680924', 'Wider', 'ويدر', 'Zarqa', 'Zarqa', Category.GYM, Tier.SILVER, 32.064402, 36.09066),
    ('slim-gym-4306967706', 'Slim Gym للسيدات', 'Slim Gym للسيدات', 'Sukhna', 'Zarqa', Category.GYM, Tier.GOLD, 32.129825, 36.069527),
    ('power-fitness-center-5388251221', 'Power Fitness Center', 'مركز قوة اللياقة', 'Zarqa', 'Zarqa', Category.GYM, Tier.SILVER, 32.094656, 36.087657),
    ('spark-health-club-5624592021', 'Spark Health Club', 'نادي سبارك الصحي', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 31.9797, 35.895242),
    ('osm-6264279695', 'نادي بيت يافا الرياضي', 'نادي بيت يافا الرياضي', 'Irbid', 'Irbid', Category.GYM, Tier.SILVER, 32.519288, 35.782998),
    ('osm-6774433359', 'نادي الوقت المميز للياقة والسباحة', 'نادي الوقت المميز للياقة والسباحة', 'Amman', 'Amman', Category.GYM, Tier.PLATINUM, 31.916862, 35.937926),
    ('golds-gym-7205564385', "Gold's Gym", 'جولدز جم', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 31.97967, 35.840287),
    ('osm-7281810265', 'وقت اللياقه', 'وقت اللياقه', 'Irbid', 'Irbid', Category.GYM, Tier.GOLD, 32.532387, 35.854902),
    ('osm-7284362999', 'ابراج الرياضة', 'ابراج الرياضة', 'Irbid', 'Irbid', Category.GYM, Tier.GOLD, 32.540805, 35.851438),
    ('osm-7284664788', 'الأمل للسياحة والسفر', 'الأمل للسياحة والسفر', 'Irbid', 'Irbid', Category.GYM, Tier.PLATINUM, 32.54633, 35.855615),
    ('osm-7284778606', 'المستوى للسياحة والسفر', 'المستوى للسياحة والسفر', 'Irbid', 'Irbid', Category.GYM, Tier.SILVER, 32.547503, 35.85471),
    ('osm-7284992368', 'no name fation and more;بلعاوي', 'no name fation and more;بلعاوي', 'Irbid', 'Irbid', Category.GYM, Tier.GOLD, 32.548992, 35.85387),
    ('dr-protein-7287554673', 'Dr protein', 'Dr protein', 'Irbid', 'Irbid', Category.GYM, Tier.SILVER, 32.539314, 35.851489),
    ('sams-gym-7287602301', 'SAMS GYM', 'SAMS GYM', 'Irbid', 'Irbid', Category.GYM, Tier.SILVER, 32.539758, 35.851352),
    ('quicksand-9065749018', 'Quicksand', 'Quicksand', 'Amman', 'Amman', Category.GYM, Tier.GOLD, 31.942431, 35.889998),
    ('golds-gym-9065756717', "Gold's Gym", "Gold's Gym", 'Amman', 'Amman', Category.GYM, Tier.DIAMOND, 31.946136, 35.88628),
    ('osm-9655322251', 'مجمع أبقراط', 'مجمع أبقراط', 'Irbid', 'Irbid', Category.GYM, Tier.GOLD, 32.530413, 35.891554),
    ('osm-9655322255', 'مجمع زينب نجيب العبيد خريس', 'مجمع زينب نجيب العبيد خريس', 'Irbid', 'Irbid', Category.GYM, Tier.DIAMOND, 32.527135, 35.896156),
    ('osm-9655335327', 'مجمع الحاج سليم عبدالله خصاونة', 'مجمع الحاج سليم عبدالله خصاونة', 'Irbid', 'Irbid', Category.GYM, Tier.GOLD, 32.534935, 35.88522),
    ('osm-9655363168', 'مركز الحتامله', 'مركز الحتامله', 'Irbid', 'Irbid', Category.GYM, Tier.PLATINUM, 32.52852, 35.894284),
    ('smart-buy-9655374241', 'Smart Buy', 'Smart Buy', 'Irbid', 'Irbid', Category.GYM, Tier.SILVER, 32.523347, 35.877121),
    ('osm-9655389323', 'مجمع السيف التجاري', 'مجمع السيف التجاري', 'Irbid', 'Irbid', Category.GYM, Tier.DIAMOND, 32.520932, 35.872196),
    ('grams-gym-9716237862', 'Grams Gym', 'Grams Gym', 'Amman', 'Amman', Category.GYM, Tier.PLATINUM, 31.946136, 35.847183),
    ('hulk-gym-10000011949', 'Hulk GYM', 'Hulk GYM', 'Amman', 'Amman', Category.GYM, Tier.PLATINUM, 31.959848, 35.837461),
    ('badiya-by-barbedu-13267604827', 'Badiya By BarBedu', 'Badiya By BarBedu', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 31.955117, 35.924063),
    ('elite-one-gym-13288693100', 'Elite One Gym', 'Elite One Gym', 'Amman', 'Amman', Category.GYM, Tier.GOLD, 31.9501, 35.883959),
    ('we-fit-13371963022', 'We Fit', 'We Fit', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 31.955257, 35.927441),
    ('strong-arms-gym-13530375201', 'Strong Arms GYM', 'سترونق آرمز جيم', 'Zarqa', 'Zarqa', Category.GYM, Tier.GOLD, 32.100473, 36.097237),
    ('360-gym-13531438701', '360 GYM', '٣٦٠ جيم', 'Zarqa', 'Zarqa', Category.GYM, Tier.SILVER, 32.097442, 36.102675),
    ('safa-fitness-13684981801', 'Safa Fitness', 'سافا فتنيس', 'Zarqa', 'Zarqa', Category.GYM, Tier.GOLD, 32.099823, 36.091726),
    ('sunset-gym-13732688471', 'Sunset Gym', 'Sunset Gym', 'Amman', 'Amman', Category.GYM, Tier.GOLD, 31.918124, 35.956222),
    ('osm-168057589', 'صالة رياضة', 'صالة رياضة', 'Zarqa', 'Zarqa', Category.GYM, Tier.GOLD, 32.101707, 36.184123),
    ('osm-168057590', 'صالة عثمان بدير', 'صالة عثمان بدير', 'Zarqa', 'Zarqa', Category.GYM, Tier.GOLD, 32.101271, 36.184124),
    ('sport-activities-complex-180109487', 'Sport Activities Complex', 'مجمع النشاطات الرياضية', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 32.013364, 35.871605),
    ('abu-nuseir-club-185443120', 'Abu Nuseir Club', 'Abu Nuseir Club', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 32.061926, 35.885867),
    ('rizeup-gym-200004754', 'Rizeup Gym', 'Rizeup Gym', 'Amman', 'Amman', Category.GYM, Tier.GOLD, 31.971256, 35.832934),
    ('orthodox-club-265950065', 'Orthodox Club', 'النادي الأرثوذكسي', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 31.947619, 35.896588),
    ('dojo-285605748', 'Dojo', 'دوجو', 'Amman', 'Amman', Category.MARTIAL, Tier.SILVER, 31.986908, 35.909116),
    ('osm-396475220', 'النادي الرياضي', 'النادي الرياضي', 'Zarqa', 'Zarqa', Category.GYM, Tier.SILVER, 32.333105, 36.240846),
    ('osm-460954983', 'صالة رياضة', 'صالة رياضة', 'Zarqa', 'Zarqa', Category.GYM, Tier.GOLD, 32.100545, 36.184266),
    ('powerhut-522463750', 'PowerHut', 'PowerHut', 'Amman', 'Amman', Category.GYM, Tier.PLATINUM, 31.969271, 35.89882),
    ('jordan-taekwondo-federation-633909925', 'Jordan Taekwondo Federation', 'اتحاد التايكوندو الأردني', 'Amman', 'Amman', Category.MARTIAL, Tier.SILVER, 31.948386, 35.927185),
    ('revolution-ladies-gym-651686882', 'Revolution Ladies Gym', 'ريفولوشن جيم للسيدات', 'Amman', 'Amman', Category.GYM, Tier.GOLD, 32.01063, 35.862698),
    ('sports-hall-1098931426', 'Sports Hall', 'صالة رياضة', 'Madaba', 'Madaba', Category.GYM, Tier.PLATINUM, 31.777893, 35.799112),
]

# Merge: curated dev set takes priority; OSM additions fill out the
# rest of the Jordan footprint with real venues. De-dup by slug —
# curated wins if both sources somehow share a slug (none do today).
_curated_slugs = {g[0] for g in GYMS}
GYMS = GYMS + [g for g in OSM_GYMS if g[0] not in _curated_slugs]

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
            "Madaba": "مادبا",
            "Mafraq": "المفرق",
            "Salt": "السلط",
            "Jerash": "جرش",
            "Ajloun": "عجلون",
            "Karak": "الكرك",
            "Tafilah": "الطفيلة",
            "Ma'an": "معان",
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
