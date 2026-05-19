import 'package:flutter/foundation.dart';

/// Public view of a gym's day-pass offering. Returned by
/// `GET /api/v1/gyms/{slug}/day-pass-offering`. Members read this
/// to decide whether to render the "Try today" CTA on the gym
/// detail page.
///
/// The backend always returns a body — even when no offering is
/// configured it synthesizes `{isEnabled: false, priceJod: 0,
/// validityHours: 0}`. UI code only ever needs to check
/// `isEnabled` to decide whether the CTA appears.
@immutable
class DayPassOffering {
  const DayPassOffering({
    required this.isEnabled,
    required this.priceJod,
    required this.validityHours,
  });

  final bool isEnabled;

  /// Decimal-as-double for display only. The mobile app never
  /// computes payouts; the backend snapshots the canonical decimal
  /// at purchase time, so a tiny float repr drift here is
  /// invisible. Members see e.g. `8 JOD` or `8.50 JOD`.
  final double priceJod;

  /// How long the pass stays valid after purchase. Used for the
  /// "Expires in 24h" copy on the buy-sheet and the active-passes
  /// list. Backend default is 24; admins may override per offering.
  final int validityHours;

  factory DayPassOffering.fromJson(Map<String, dynamic> json) {
    return DayPassOffering(
      isEnabled: json['isEnabled'] as bool? ?? false,
      priceJod: double.tryParse((json['priceJod'] ?? '0').toString()) ?? 0,
      validityHours: (json['validityHours'] as num?)?.toInt() ?? 0,
    );
  }

  static const disabled = DayPassOffering(
    isEnabled: false,
    priceJod: 0,
    validityHours: 0,
  );
}

/// A single day-pass the member has purchased. Mirrors the backend's
/// `DayPassRead` schema. Active passes show on the Profile screen
/// and gate the gym-detail "Check in here" CTA for non-subscribers
/// who already bought a pass for the gym.
@immutable
class DayPass {
  const DayPass({
    required this.id,
    required this.gymId,
    required this.gymSlug,
    required this.gymNameEn,
    required this.gymNameAr,
    required this.status,
    required this.priceJod,
    required this.purchasedAt,
    required this.expiresAt,
    this.usedAt,
  });

  final String id;
  final String gymId;
  final String gymSlug;
  final String gymNameEn;
  final String gymNameAr;
  final String status;
  final double priceJod;
  final DateTime purchasedAt;
  final DateTime expiresAt;
  final DateTime? usedAt;

  /// True while the pass is paid for, unredeemed, and within its
  /// validity window. The backend writes this status; the
  /// `expiresAt > now` check is a defensive UI guard against
  /// stale data after a long screen idle.
  bool isActive(DateTime now) =>
      status == 'active' && expiresAt.isAfter(now);

  /// Localized gym name selector — matches the rest of the app's
  /// AR-default rendering.
  String name({required bool isAr}) =>
      isAr ? (gymNameAr.isNotEmpty ? gymNameAr : gymNameEn) : gymNameEn;

  factory DayPass.fromJson(Map<String, dynamic> json) {
    return DayPass(
      id: json['id']?.toString() ?? '',
      gymId: json['gymId']?.toString() ?? '',
      gymSlug: json['gymSlug']?.toString() ?? '',
      gymNameEn: json['gymNameEn']?.toString() ?? '',
      gymNameAr: json['gymNameAr']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      priceJod: double.tryParse((json['priceJod'] ?? '0').toString()) ?? 0,
      purchasedAt:
          DateTime.tryParse(json['purchasedAt']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      usedAt: json['usedAt'] == null
          ? null
          : DateTime.tryParse(json['usedAt'].toString())?.toUtc(),
    );
  }
}
