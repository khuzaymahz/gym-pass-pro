"""Dev seed script. Run with: `uv run python -m scripts.seed` inside the backend container."""

from __future__ import annotations

import asyncio
from decimal import Decimal
from typing import Any

from sqlalchemy import func, select

from app.config import get_settings
from app.core.security import hash_password
from app.db.enums import AudienceGender, Category, Locale, Role, Tier
from app.db.models import Gym, GymPhoto, Plan, User
from app.db.session import get_engine
from sqlalchemy.ext.asyncio import async_sessionmaker
from app.utils.ids import uuid7

# Dev seed gym network — plausible Jordan-flavoured names. Lat/lng
# are area centres; tier + category are dev-only assignments.
# Audience mix here demonstrates the female-only / male-only feature
# end-to-end (Halo Studio + Royal Pilates female_only; Fortis Boxing
# male_only). The rest are mixed.
#
# Tuple shape: (slug, name_en, name_ar, area, city, category, tier, lat, lng, audience)
GymTuple = tuple[
    str, str, str, str, str, "Category", "Tier", float, float, "AudienceGender",
]
GYMS: list[GymTuple] = [
    # ── Amman: upscale (Abdoun, Dabouq, 5th Circle) ──
    ("iron-forge",      "Iron Forge",         "آيرون فورج",          "Abdoun",       "Amman", Category.GYM,      Tier.SILVER,   31.9560, 35.8786, AudienceGender.MIXED),
    ("halo-studio",     "Halo Studio",        "هالو ستوديو",          "Abdoun",       "Amman", Category.YOGA,     Tier.SILVER,   31.9582, 35.8801, AudienceGender.FEMALE_ONLY),
    ("core-athletic",   "Core Athletic",      "كور أثلتك",           "Dabouq",       "Amman", Category.GYM,      Tier.DIAMOND,  32.0083, 35.8200, AudienceGender.MIXED),
    ("apex-crossfit",   "Apex CrossFit",      "إيبكس كروسفت",        "Khalda",       "Amman", Category.CROSSFIT, Tier.GOLD,     31.9882, 35.8307, AudienceGender.MIXED),
    ("pulse-fitness",   "Pulse Fitness",      "بَلْس فِتنِس",          "5th Circle",   "Amman", Category.GYM,      Tier.PLATINUM, 31.9550, 35.9050, AudienceGender.MIXED),
    ("zen-yoga",        "Zen Yoga House",     "زن لليوغا",            "Jabal Webdeh", "Amman", Category.YOGA,     Tier.GOLD,     31.9580, 35.9128, AudienceGender.MIXED),

    # ── Amman: residential / family-friendly ──
    ("bedford-yoga",    "Bedford Yoga",       "بدفورد لليوغا",        "Sweifieh",     "Amman", Category.YOGA,     Tier.GOLD,     31.9693, 35.8688, AudienceGender.MIXED),
    ("body-master",     "Body Master Gym",    "بودي ماستر",          "Tlaa al-Ali",  "Amman", Category.GYM,      Tier.SILVER,   31.9836, 35.8500, AudienceGender.MIXED),
    ("nordic-fit",      "Nordic Fitness",     "نوردك فتنس",          "Jubeiha",      "Amman", Category.GYM,      Tier.SILVER,   32.0167, 35.8806, AudienceGender.MIXED),
    ("fortis-boxing",   "Fortis Boxing Club", "فورتس للملاكمة",      "Jabal Amman",  "Amman", Category.MARTIAL,  Tier.PLATINUM, 31.9540, 35.9319, AudienceGender.MALE_ONLY),

    # ── Amman: north / sweileh / shmeisani ──
    ("the-floor",       "The Floor CrossFit", "ذا فلور كروسفت",      "Sweileh",      "Amman", Category.CROSSFIT, Tier.GOLD,     32.0367, 35.8400, AudienceGender.MIXED),
    ("royal-pilates",   "Royal Pilates",      "رويال للبيلاتيس",      "Shmeisani",    "Amman", Category.YOGA,     Tier.PLATINUM, 31.9682, 35.9046, AudienceGender.FEMALE_ONLY),
    ("strength-academy","Strength Academy",   "أكاديمية القوة",       "Wasfi al-Tal", "Amman", Category.GYM,      Tier.GOLD,     31.9893, 35.8783, AudienceGender.MIXED),

    # ── Zarqa ──
    ("zarqa-power",     "Zarqa Power Gym",    "نادي الزرقاء للقوة",   "Zarqa Centre", "Zarqa", Category.GYM,      Tier.SILVER,   32.0728, 36.0876, AudienceGender.MIXED),
    ("phoenix-mma",     "Phoenix MMA",        "فينكس للفنون القتالية","Zarqa New",    "Zarqa", Category.MARTIAL,  Tier.GOLD,     32.0850, 36.1010, AudienceGender.MALE_ONLY),

    # ── Irbid ──
    ("irbid-athletic",  "Irbid Athletic",     "إربد الرياضي",         "Hashmi",       "Irbid", Category.GYM,      Tier.GOLD,     32.5556, 35.8500, AudienceGender.MIXED),
    ("northern-crossfit","Northern CrossFit", "الشمال كروسفت",        "Yarmouk",      "Irbid", Category.CROSSFIT, Tier.PLATINUM, 32.5430, 35.8650, AudienceGender.MIXED),

    # ── Aqaba ──
    ("ayla-wellness",   "Ayla Wellness Club", "آيلا للعافية",        "Tala Bay",     "Aqaba", Category.GYM,      Tier.DIAMOND,  29.5267, 35.0019, AudienceGender.MIXED),
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
# Tuple shape matches GYMS above (with audience as the 10th element).
OSM_GYMS: list[GymTuple] = [
    ('fitness-masters-1932930595', 'Fitness Masters', 'Fitness Masters', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 32.026201, 35.855839, AudienceGender.MIXED),
    ('fitness-gym-2522315951', 'Fitness Gym', 'Fitness Gym', 'Amman', 'Amman', Category.GYM, Tier.DIAMOND, 31.955426, 35.928051, AudienceGender.MIXED),
    ('caucasian-club-4172942049', 'Caucasian Club', 'النادي القوقازي', 'Zarqa', 'Zarqa', Category.GYM, Tier.PLATINUM, 32.061387, 36.088014, AudienceGender.MIXED),
    ('wider-4220680924', 'Wider', 'ويدر', 'Zarqa', 'Zarqa', Category.GYM, Tier.SILVER, 32.064402, 36.09066, AudienceGender.MIXED),
    # OSM name explicitly tagged "للسيدات" (for ladies) — single-sex.
    ('slim-gym-4306967706', 'Slim Gym للسيدات', 'Slim Gym للسيدات', 'Sukhna', 'Zarqa', Category.GYM, Tier.GOLD, 32.129825, 36.069527, AudienceGender.FEMALE_ONLY),
    ('power-fitness-center-5388251221', 'Power Fitness Center', 'مركز قوة اللياقة', 'Zarqa', 'Zarqa', Category.GYM, Tier.SILVER, 32.094656, 36.087657, AudienceGender.MIXED),
    ('spark-health-club-5624592021', 'Spark Health Club', 'نادي سبارك الصحي', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 31.9797, 35.895242, AudienceGender.MIXED),
    ('osm-6264279695', 'نادي بيت يافا الرياضي', 'نادي بيت يافا الرياضي', 'Irbid', 'Irbid', Category.GYM, Tier.SILVER, 32.519288, 35.782998, AudienceGender.MIXED),
    ('osm-6774433359', 'نادي الوقت المميز للياقة والسباحة', 'نادي الوقت المميز للياقة والسباحة', 'Amman', 'Amman', Category.GYM, Tier.PLATINUM, 31.916862, 35.937926, AudienceGender.MIXED),
    ('golds-gym-7205564385', "Gold's Gym", 'جولدز جم', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 31.97967, 35.840287, AudienceGender.MIXED),
    ('osm-7281810265', 'وقت اللياقه', 'وقت اللياقه', 'Irbid', 'Irbid', Category.GYM, Tier.GOLD, 32.532387, 35.854902, AudienceGender.MIXED),
    ('osm-7284362999', 'ابراج الرياضة', 'ابراج الرياضة', 'Irbid', 'Irbid', Category.GYM, Tier.GOLD, 32.540805, 35.851438, AudienceGender.MIXED),
    ('osm-7284664788', 'الأمل للسياحة والسفر', 'الأمل للسياحة والسفر', 'Irbid', 'Irbid', Category.GYM, Tier.PLATINUM, 32.54633, 35.855615, AudienceGender.MIXED),
    ('osm-7284778606', 'المستوى للسياحة والسفر', 'المستوى للسياحة والسفر', 'Irbid', 'Irbid', Category.GYM, Tier.SILVER, 32.547503, 35.85471, AudienceGender.MIXED),
    ('osm-7284992368', 'no name fation and more;بلعاوي', 'no name fation and more;بلعاوي', 'Irbid', 'Irbid', Category.GYM, Tier.GOLD, 32.548992, 35.85387, AudienceGender.MIXED),
    ('dr-protein-7287554673', 'Dr protein', 'Dr protein', 'Irbid', 'Irbid', Category.GYM, Tier.SILVER, 32.539314, 35.851489, AudienceGender.MIXED),
    ('sams-gym-7287602301', 'SAMS GYM', 'SAMS GYM', 'Irbid', 'Irbid', Category.GYM, Tier.SILVER, 32.539758, 35.851352, AudienceGender.MIXED),
    ('quicksand-9065749018', 'Quicksand', 'Quicksand', 'Amman', 'Amman', Category.GYM, Tier.GOLD, 31.942431, 35.889998, AudienceGender.MIXED),
    ('golds-gym-9065756717', "Gold's Gym", "Gold's Gym", 'Amman', 'Amman', Category.GYM, Tier.DIAMOND, 31.946136, 35.88628, AudienceGender.MIXED),
    ('osm-9655322251', 'مجمع أبقراط', 'مجمع أبقراط', 'Irbid', 'Irbid', Category.GYM, Tier.GOLD, 32.530413, 35.891554, AudienceGender.MIXED),
    ('osm-9655322255', 'مجمع زينب نجيب العبيد خريس', 'مجمع زينب نجيب العبيد خريس', 'Irbid', 'Irbid', Category.GYM, Tier.DIAMOND, 32.527135, 35.896156, AudienceGender.MIXED),
    ('osm-9655335327', 'مجمع الحاج سليم عبدالله خصاونة', 'مجمع الحاج سليم عبدالله خصاونة', 'Irbid', 'Irbid', Category.GYM, Tier.GOLD, 32.534935, 35.88522, AudienceGender.MIXED),
    ('osm-9655363168', 'مركز الحتامله', 'مركز الحتامله', 'Irbid', 'Irbid', Category.GYM, Tier.PLATINUM, 32.52852, 35.894284, AudienceGender.MIXED),
    ('smart-buy-9655374241', 'Smart Buy', 'Smart Buy', 'Irbid', 'Irbid', Category.GYM, Tier.SILVER, 32.523347, 35.877121, AudienceGender.MIXED),
    ('osm-9655389323', 'مجمع السيف التجاري', 'مجمع السيف التجاري', 'Irbid', 'Irbid', Category.GYM, Tier.DIAMOND, 32.520932, 35.872196, AudienceGender.MIXED),
    ('grams-gym-9716237862', 'Grams Gym', 'Grams Gym', 'Amman', 'Amman', Category.GYM, Tier.PLATINUM, 31.946136, 35.847183, AudienceGender.MIXED),
    ('hulk-gym-10000011949', 'Hulk GYM', 'Hulk GYM', 'Amman', 'Amman', Category.GYM, Tier.PLATINUM, 31.959848, 35.837461, AudienceGender.MIXED),
    ('badiya-by-barbedu-13267604827', 'Badiya By BarBedu', 'Badiya By BarBedu', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 31.955117, 35.924063, AudienceGender.MIXED),
    ('elite-one-gym-13288693100', 'Elite One Gym', 'Elite One Gym', 'Amman', 'Amman', Category.GYM, Tier.GOLD, 31.9501, 35.883959, AudienceGender.MIXED),
    ('we-fit-13371963022', 'We Fit', 'We Fit', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 31.955257, 35.927441, AudienceGender.MIXED),
    ('strong-arms-gym-13530375201', 'Strong Arms GYM', 'سترونق آرمز جيم', 'Zarqa', 'Zarqa', Category.GYM, Tier.GOLD, 32.100473, 36.097237, AudienceGender.MIXED),
    ('360-gym-13531438701', '360 GYM', '٣٦٠ جيم', 'Zarqa', 'Zarqa', Category.GYM, Tier.SILVER, 32.097442, 36.102675, AudienceGender.MIXED),
    ('safa-fitness-13684981801', 'Safa Fitness', 'سافا فتنيس', 'Zarqa', 'Zarqa', Category.GYM, Tier.GOLD, 32.099823, 36.091726, AudienceGender.MIXED),
    ('sunset-gym-13732688471', 'Sunset Gym', 'Sunset Gym', 'Amman', 'Amman', Category.GYM, Tier.GOLD, 31.918124, 35.956222, AudienceGender.MIXED),
    ('osm-168057589', 'صالة رياضة', 'صالة رياضة', 'Zarqa', 'Zarqa', Category.GYM, Tier.GOLD, 32.101707, 36.184123, AudienceGender.MIXED),
    ('osm-168057590', 'صالة عثمان بدير', 'صالة عثمان بدير', 'Zarqa', 'Zarqa', Category.GYM, Tier.GOLD, 32.101271, 36.184124, AudienceGender.MIXED),
    ('sport-activities-complex-180109487', 'Sport Activities Complex', 'مجمع النشاطات الرياضية', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 32.013364, 35.871605, AudienceGender.MIXED),
    ('abu-nuseir-club-185443120', 'Abu Nuseir Club', 'Abu Nuseir Club', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 32.061926, 35.885867, AudienceGender.MIXED),
    ('rizeup-gym-200004754', 'Rizeup Gym', 'Rizeup Gym', 'Amman', 'Amman', Category.GYM, Tier.GOLD, 31.971256, 35.832934, AudienceGender.MIXED),
    ('orthodox-club-265950065', 'Orthodox Club', 'النادي الأرثوذكسي', 'Amman', 'Amman', Category.GYM, Tier.SILVER, 31.947619, 35.896588, AudienceGender.MIXED),
    ('dojo-285605748', 'Dojo', 'دوجو', 'Amman', 'Amman', Category.MARTIAL, Tier.SILVER, 31.986908, 35.909116, AudienceGender.MIXED),
    ('osm-396475220', 'النادي الرياضي', 'النادي الرياضي', 'Zarqa', 'Zarqa', Category.GYM, Tier.SILVER, 32.333105, 36.240846, AudienceGender.MIXED),
    ('osm-460954983', 'صالة رياضة', 'صالة رياضة', 'Zarqa', 'Zarqa', Category.GYM, Tier.GOLD, 32.100545, 36.184266, AudienceGender.MIXED),
    ('powerhut-522463750', 'PowerHut', 'PowerHut', 'Amman', 'Amman', Category.GYM, Tier.PLATINUM, 31.969271, 35.89882, AudienceGender.MIXED),
    ('jordan-taekwondo-federation-633909925', 'Jordan Taekwondo Federation', 'اتحاد التايكوندو الأردني', 'Amman', 'Amman', Category.MARTIAL, Tier.SILVER, 31.948386, 35.927185, AudienceGender.MIXED),
    # OSM "Ladies Gym" → female-only.
    ('revolution-ladies-gym-651686882', 'Revolution Ladies Gym', 'ريفولوشن جيم للسيدات', 'Amman', 'Amman', Category.GYM, Tier.GOLD, 32.01063, 35.862698, AudienceGender.FEMALE_ONLY),
    ('sports-hall-1098931426', 'Sports Hall', 'صالة رياضة', 'Madaba', 'Madaba', Category.GYM, Tier.PLATINUM, 31.777893, 35.799112, AudienceGender.MIXED),
]

# Merge: curated dev set takes priority; OSM additions fill out the
# rest of the Jordan footprint with real venues. De-dup by slug —
# curated wins if both sources somehow share a slug (none do today).
_curated_slugs = {g[0] for g in GYMS}
GYMS = GYMS + [g for g in OSM_GYMS if g[0] not in _curated_slugs]

# ── Per-osm-id enrichment harvested from OSM tags. Phone + opening
# hours are kept where OSM had them; the rest of the enrichment
# (amenities, default hours, photos, ratings) is generated below
# from the category/tier so dev data feels complete without
# fabricating specific real-business facts.
OSM_FACTS: dict[int, tuple[str | None, dict[str, Any] | None]] = {
    5388251221: (
        "+962786969110",
        {
            "mon": {"open": "08:00", "close": "20:30"},
            "tue": {"open": "08:00", "close": "20:30"},
            "wed": {"open": "08:00", "close": "20:30"},
            "thu": {"open": "08:00", "close": "20:30"},
            "fri": {"closed": True},
            "sat": {"open": "08:00", "close": "20:30"},
            "sun": {"open": "08:00", "close": "20:30"},
        },
    ),
    5624592021: (
        "+96265650054",
        {
            "mon": {"open": "10:00", "close": "01:30"},
            "tue": {"open": "10:00", "close": "01:30"},
            "wed": {"open": "10:00", "close": "01:30"},
            "thu": {"open": "10:00", "close": "01:30"},
            "fri": {"closed": True},
            "sat": {"open": "10:00", "close": "01:30"},
            "sun": {"open": "10:00", "close": "01:30"},
        },
    ),
    7205564385: ("+96264001222", {"24_7": True}),
    9716237862: ("+962795556818", None),
    10000011949: ("+962778083064", None),
    200004754: ("+962791888777", None),
}

# Category-default amenity templates. Tier additions layer on top
# (richer gyms add sauna/pool/PT). Strings match the keys the mobile
# `gymAmenityX` localisation entries already support.
_BASE_AMENITIES = ["wifi", "showers", "lockers", "ac"]
CATEGORY_AMENITIES: dict[tuple[Category, Tier], list[str]] = {
    (Category.GYM, Tier.SILVER):   _BASE_AMENITIES + ["parking", "free_weights"],
    (Category.GYM, Tier.GOLD):     _BASE_AMENITIES + ["parking", "free_weights", "cardio_machines", "changing_rooms"],
    (Category.GYM, Tier.PLATINUM): _BASE_AMENITIES + ["parking", "free_weights", "cardio_machines", "changing_rooms", "sauna", "personal_training", "water_fountain"],
    (Category.GYM, Tier.DIAMOND):  _BASE_AMENITIES + ["parking", "free_weights", "cardio_machines", "changing_rooms", "sauna", "personal_training", "water_fountain", "pool", "steam_room", "juice_bar", "towels"],
    (Category.YOGA, Tier.SILVER):   _BASE_AMENITIES + ["changing_rooms", "water_fountain", "prayer_room"],
    (Category.YOGA, Tier.GOLD):     _BASE_AMENITIES + ["changing_rooms", "water_fountain", "prayer_room", "group_classes"],
    (Category.YOGA, Tier.PLATINUM): _BASE_AMENITIES + ["changing_rooms", "water_fountain", "prayer_room", "group_classes", "personal_training", "towels"],
    (Category.YOGA, Tier.DIAMOND):  _BASE_AMENITIES + ["changing_rooms", "water_fountain", "prayer_room", "group_classes", "personal_training", "towels", "juice_bar"],
    (Category.CROSSFIT, Tier.SILVER):   _BASE_AMENITIES + ["parking", "free_weights", "water_fountain"],
    (Category.CROSSFIT, Tier.GOLD):     _BASE_AMENITIES + ["parking", "free_weights", "water_fountain", "group_classes", "changing_rooms"],
    (Category.CROSSFIT, Tier.PLATINUM): _BASE_AMENITIES + ["parking", "free_weights", "water_fountain", "group_classes", "changing_rooms", "personal_training"],
    (Category.CROSSFIT, Tier.DIAMOND):  _BASE_AMENITIES + ["parking", "free_weights", "water_fountain", "group_classes", "changing_rooms", "personal_training", "sauna", "towels"],
    (Category.MARTIAL, Tier.SILVER):   _BASE_AMENITIES + ["parking", "changing_rooms"],
    (Category.MARTIAL, Tier.GOLD):     _BASE_AMENITIES + ["parking", "changing_rooms", "group_classes", "water_fountain"],
    (Category.MARTIAL, Tier.PLATINUM): _BASE_AMENITIES + ["parking", "changing_rooms", "group_classes", "water_fountain", "personal_training"],
    (Category.MARTIAL, Tier.DIAMOND):  _BASE_AMENITIES + ["parking", "changing_rooms", "group_classes", "water_fountain", "personal_training", "towels"],
}

# Category-default opening hours. Diamond gyms get 24/7 by default;
# others follow Jordan-typical schedules (Sun-Thu primary, Fri short
# / closed, Sat normal). The schema accepts either `{"24_7": true}`
# or per-day `{mon: {open, close}, ...}` — the partner sidebar in
# the gym-partner portal already handles both shapes.
def _weekday_hours(open_time: str, close_time: str, *, fri_short: bool = True) -> dict[str, Any]:
    days = ["mon", "tue", "wed", "thu", "sat", "sun"]
    schedule: dict[str, Any] = {
        d: {"open": open_time, "close": close_time} for d in days
    }
    schedule["fri"] = (
        {"open": "14:00", "close": close_time} if fri_short
        else {"open": open_time, "close": close_time}
    )
    return schedule

def category_hours(category: Category, tier: Tier) -> dict[str, Any]:
    if tier == Tier.DIAMOND:
        return {"24_7": True}
    if category == Category.YOGA:
        return _weekday_hours("07:00", "21:00")
    if category == Category.CROSSFIT:
        return _weekday_hours("06:00", "22:00")
    if category == Category.MARTIAL:
        return _weekday_hours("16:00", "22:00", fri_short=False)
    # GYM default
    if tier == Tier.PLATINUM:
        return _weekday_hours("06:00", "00:00")
    return _weekday_hours("06:00", "23:00")

# Unsplash photo pools per category (CC0 / Unsplash-licence). Each
# venue picks 2-3 deterministically from its category pool by
# slug hash, so OSM gyms also feel populated. Tuples are
# (url, alt_en, alt_ar).
_CAT_PHOTOS_GYM = [
    ("https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1200", "Main floor", "الصالة الرئيسية"),
    ("https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=1200", "Free weights", "الأوزان الحرة"),
    ("https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=1200", "Cardio row", "صف الكارديو"),
    ("https://images.unsplash.com/photo-1571902943202-507ec2618e8f?w=1200", "Training floor", "أرضية التدريب"),
    ("https://images.unsplash.com/photo-1593079831268-3381b0db4a77?w=1200", "Recovery zone", "منطقة التعافي"),
    ("https://images.unsplash.com/photo-1605296867424-35fc25c9212a?w=1200", "Open floor", "صالة مفتوحة"),
    ("https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=1200", "Strength corner", "ركن القوة"),
    ("https://images.unsplash.com/photo-1583500178690-f7ddeae9b1b9?w=1200", "Powerlifting", "رفع الأثقال"),
    ("https://images.unsplash.com/photo-1576678927484-cc907957088c?w=1200", "Group session", "جلسة جماعية"),
    ("https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=1200", "Functional area", "منطقة وظيفية"),
]
_CAT_PHOTOS_YOGA = [
    ("https://images.unsplash.com/photo-1588286840104-8957b019727f?w=1200", "Studio", "الاستديو"),
    ("https://images.unsplash.com/photo-1599901860904-17e6ed7083a0?w=1200", "Mat room", "غرفة الحصر"),
    ("https://images.unsplash.com/photo-1506629082955-511b1aa562c8?w=1200", "Main studio", "الاستديو الرئيسي"),
    ("https://images.unsplash.com/photo-1545205597-3d9d02c29597?w=1200", "Practice room", "غرفة التدريب"),
    ("https://images.unsplash.com/photo-1591291621164-2c6367723315?w=1200", "Meditation room", "غرفة التأمل"),
    ("https://images.unsplash.com/photo-1601925260368-ae2f83cf8b7f?w=1200", "Reformer studio", "استوديو الريفورمر"),
]
_CAT_PHOTOS_CROSSFIT = [
    ("https://images.unsplash.com/photo-1534367610401-9f5ed68180aa?w=1200", "Box", "القاعة"),
    ("https://images.unsplash.com/photo-1518611012118-696072aa579a?w=1200", "Rig", "المنصة"),
    ("https://images.unsplash.com/photo-1526506118085-60ce8714f8c5?w=1200", "Rig + rowers", "المنصة والمجاديف"),
    ("https://images.unsplash.com/photo-1517466787929-bc90951d0974?w=1200", "Olympic platforms", "منصات الرفع"),
]
_CAT_PHOTOS_MARTIAL = [
    ("https://images.unsplash.com/photo-1549576490-b0b4831ef60a?w=1200", "Ring", "الحلبة"),
    ("https://images.unsplash.com/photo-1544717305-2782549b5136?w=1200", "Heavy bags", "أكياس الملاكمة"),
    ("https://images.unsplash.com/photo-1517438476312-10d79c5f25a9?w=1200", "Mat area", "منطقة الحصير"),
]

CATEGORY_PHOTOS: dict[Category, list[tuple[str, str, str]]] = {
    Category.GYM: _CAT_PHOTOS_GYM,
    Category.YOGA: _CAT_PHOTOS_YOGA,
    Category.CROSSFIT: _CAT_PHOTOS_CROSSFIT,
    Category.MARTIAL: _CAT_PHOTOS_MARTIAL,
}

def photos_for(slug: str, category: Category, count: int = 3) -> list[tuple[str, str, str]]:
    """Pick `count` photos from the category pool, deterministically
    by slug hash so the same slug always yields the same picture set
    across reseeds."""
    pool = CATEGORY_PHOTOS[category]
    h = sum(ord(c) for c in slug)
    start = h % len(pool)
    return [pool[(start + i) % len(pool)] for i in range(min(count, len(pool)))]

def rating_for(slug: str) -> tuple[Decimal, int]:
    """Deterministic (rating, review_count). Range 3.8-4.8 stars,
    review counts 12-220 — plausible for a working partner gym."""
    h = sum(ord(c) * (i + 1) for i, c in enumerate(slug))
    # Rating in tenths from 38 to 48 → 3.8 to 4.8
    tenths = 38 + (h % 11)
    rating = Decimal(tenths) / Decimal(10)
    reviews = 12 + ((h * 7) % 209)
    return rating, reviews

def phone_for_curated(slug: str) -> str | None:
    """Plausible Jordan mobile numbers for the curated 18. OSM gyms
    keep whatever phone OSM had (via OSM_FACTS). For curated, a
    deterministic but obviously-sequential number — clearly dev
    data, never confusable with a real venue's line."""
    h = sum(ord(c) for c in slug)
    # +9627X XXXXXXX — operator prefix rotates 77/78/79
    op = ["77", "78", "79"][h % 3]
    rest = (h * 13_337) % 10_000_000
    return f"+962{op}{rest:07d}"

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
    if not settings.should_seed_demo_data:
        raise SystemExit(
            f"seed.py refuses to run when APP_ENV={settings.app_env!r}. "
            "Demo data lives only in development; staging and production "
            "data must come through real signup/admin flows."
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
        existing_by_slug = {g.slug: g for g in existing_gyms}

        # Helper: parse the OSM id off the back of a slug. Slugs from
        # the OSM importer end in `-<digits>` (or are exactly
        # `osm-<digits>` for non-Latin names); curated slugs have no
        # trailing digits, so this returns None for them.
        def _osm_id_from_slug(s: str) -> int | None:
            tail = s.rsplit("-", 1)[-1]
            return int(tail) if tail.isdigit() else None

        def enrichment_for(
            slug: str, category: Category, tier: Tier,
        ) -> dict[str, Any]:
            osm_id = _osm_id_from_slug(slug)
            phone: str | None
            hours: dict[str, Any]
            if osm_id is not None and osm_id in OSM_FACTS:
                osm_phone, osm_hours = OSM_FACTS[osm_id]
                phone = osm_phone
                hours = osm_hours or category_hours(category, tier)
            else:
                phone = phone_for_curated(slug)
                hours = category_hours(category, tier)
            rating, reviews = rating_for(slug)
            return {
                "phone": phone,
                "opening_hours": hours,
                "amenities": CATEGORY_AMENITIES[(category, tier)],
                "rating": rating,
                "review_count": reviews,
            }

        for slug, name_en, name_ar, area, city, category, tier, lat, lng, audience in GYMS:
            if slug in existing_slugs:
                continue
            enrich = enrichment_for(slug, category, tier)
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
                phone=enrich["phone"],
                category=category,
                required_tier=tier,
                audience_gender=audience,
                per_visit_rate_jod=Decimal("2.00"),
                amenities=enrich["amenities"],
                opening_hours=enrich["opening_hours"],
                rating=enrich["rating"],
                review_count=enrich["review_count"],
            )
            session.add(gym)
            await session.flush()
            # Photos: curated slugs use their hand-picked GYM_PHOTOS
            # set; OSM slugs fall back to a category-pool selection.
            photo_rows = GYM_PHOTOS.get(slug) or photos_for(slug, category)
            for order, (url, alt_en, alt_ar) in enumerate(photo_rows):
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

        # Backfill: existing gyms (seeded by earlier seed runs that
        # only wrote `["wifi","parking","showers"]` + `{24_7: True}`)
        # are upgraded in place to the new enrichment. We only
        # overwrite fields that are at their placeholder value so a
        # partner who has hand-edited their gym keeps their changes.
        gyms_in_payload = {g[0]: g for g in GYMS}
        # Build a photo-count lookup so we only seed photos for rows
        # that currently have zero — never duplicate an admin-uploaded
        # gallery.
        photo_counts = {
            r[0]: int(r[1])
            for r in (await session.execute(
                select(GymPhoto.gym_id, func.count(GymPhoto.id))
                .group_by(GymPhoto.gym_id)
            )).all()
        }
        for row in rows:
            tup = gyms_in_payload.get(row.slug)
            if tup is None:
                continue
            _, _, _, _, _, category, tier, _, _, audience = tup
            enrich = enrichment_for(row.slug, category, tier)
            # Default amenities placeholder shipped by the old seed.
            if row.amenities == ["wifi", "parking", "showers"]:
                row.amenities = enrich["amenities"]
            # Default hours placeholder.
            if row.opening_hours == {"24_7": True} and tier != Tier.DIAMOND:
                row.opening_hours = enrich["opening_hours"]
            if row.phone is None:
                row.phone = enrich["phone"]
            if row.rating is None:
                row.rating = enrich["rating"]
                row.review_count = enrich["review_count"]
            # Audience is unconditional — it only just landed and the
            # source-of-truth lives in the seed tuple. Existing rows
            # default to `mixed` (server_default), and overwriting
            # with the seed-declared value is the correct behaviour.
            row.audience_gender = audience

            # Photos: only seed if the gym currently has zero. An
            # admin-uploaded gallery is never touched.
            if photo_counts.get(row.id, 0) == 0:
                photo_rows = GYM_PHOTOS.get(row.slug) or photos_for(row.slug, category)
                for order, (url, alt_en, alt_ar) in enumerate(photo_rows):
                    session.add(
                        GymPhoto(
                            id=uuid7(),
                            gym_id=row.id,
                            url=url,
                            sort_order=order,
                            alt_text_en=alt_en,
                            alt_text_ar=alt_ar,
                        )
                    )

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
