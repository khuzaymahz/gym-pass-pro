import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'billing_repository.dart';

enum PaymentMethodKind { visa, mastercard, cliq, applePay, googlePay }

extension PaymentMethodKindX on PaymentMethodKind {
  String get storageKey => switch (this) {
        PaymentMethodKind.visa => 'visa',
        PaymentMethodKind.mastercard => 'mastercard',
        PaymentMethodKind.cliq => 'cliq',
        PaymentMethodKind.applePay => 'apple_pay',
        PaymentMethodKind.googlePay => 'google_pay',
      };

  static PaymentMethodKind fromStorage(String raw) => switch (raw) {
        'mastercard' => PaymentMethodKind.mastercard,
        'cliq' => PaymentMethodKind.cliq,
        'apple_pay' => PaymentMethodKind.applePay,
        'google_pay' => PaymentMethodKind.googlePay,
        _ => PaymentMethodKind.visa,
      };
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.kind,
    required this.label,
    required this.last4,
    this.holder,
    this.expiryMm,
    this.expiryYy,
    this.cliqAlias,
    this.cliqPhone,
  });

  final String id;
  final PaymentMethodKind kind;
  final String label;

  /// Short display-safe identifier for the method: the last four card digits,
  /// the CliQ alias/masked-phone, or empty for Apple Pay. Never the full
  /// card number — those are tokenized server-side in a real gateway.
  final String last4;

  // Card-only
  final String? holder;
  final int? expiryMm;
  final int? expiryYy;

  // CliQ-only — we keep both since users can register with either a phone
  // number or an alias, and gateways forward whichever is populated.
  final String? cliqAlias;
  final String? cliqPhone;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.storageKey,
        'label': label,
        'last4': last4,
        if (holder != null) 'holder': holder,
        if (expiryMm != null) 'expiry_mm': expiryMm,
        if (expiryYy != null) 'expiry_yy': expiryYy,
        if (cliqAlias != null) 'cliq_alias': cliqAlias,
        if (cliqPhone != null) 'cliq_phone': cliqPhone,
      };

  static PaymentMethod fromJson(Map<String, dynamic> j) => PaymentMethod(
        id: j['id'] as String,
        kind: PaymentMethodKindX.fromStorage(j['kind'] as String? ?? 'visa'),
        label: j['label'] as String,
        last4: j['last4'] as String? ?? '',
        holder: j['holder'] as String?,
        expiryMm: j['expiry_mm'] as int?,
        expiryYy: j['expiry_yy'] as int?,
        cliqAlias: j['cliq_alias'] as String?,
        cliqPhone: j['cliq_phone'] as String?,
      );
}

class Invoice {
  const Invoice({
    required this.id,
    required this.iso,
    required this.amountJod,
    required this.tierKey,
    required this.paid,
  });

  final String id;
  final String iso;
  final int amountJod;
  final String tierKey;
  final bool paid;

  Map<String, dynamic> toJson() => {
        'id': id,
        'iso': iso,
        'amount': amountJod,
        'tier': tierKey,
        'paid': paid,
      };

  static Invoice fromJson(Map<String, dynamic> j) => Invoice(
        id: j['id'] as String,
        iso: j['iso'] as String,
        amountJod: j['amount'] as int,
        tierKey: j['tier'] as String,
        paid: j['paid'] as bool? ?? true,
      );
}

class BillingState {
  const BillingState({
    this.methods = const [],
    this.defaultMethodId,
    this.invoices = const [],
    this.loaded = false,
  });

  final List<PaymentMethod> methods;
  final String? defaultMethodId;
  final List<Invoice> invoices;
  final bool loaded;

  PaymentMethod? get defaultMethod {
    if (methods.isEmpty) return null;
    for (final m in methods) {
      if (m.id == defaultMethodId) return m;
    }
    return methods.first;
  }

  BillingState copyWith({
    List<PaymentMethod>? methods,
    String? defaultMethodId,
    bool clearDefault = false,
    List<Invoice>? invoices,
    bool? loaded,
  }) {
    return BillingState(
      methods: methods ?? this.methods,
      defaultMethodId:
          clearDefault ? null : (defaultMethodId ?? this.defaultMethodId),
      invoices: invoices ?? this.invoices,
      loaded: loaded ?? this.loaded,
    );
  }
}

class BillingNotifier extends StateNotifier<BillingState> {
  BillingNotifier(this._repo) : super(const BillingState()) {
    _hydrate();
  }

  final BillingRepository _repo;

  // Methods + invoices come from the backend. There is no auto-renew
  // toggle: real recurring billing depends on a payment gateway we
  // haven't picked yet, and offering the toggle under the mock
  // provider would falsely promise an automatic charge.
  Future<void> _hydrate() async {
    await refreshFromBackend();
  }

  /// Pull payment methods + invoices from the backend in one round trip.
  /// Called on cold-start, after add/remove/set-default mutations, after
  /// a checkout (so the new invoice appears immediately), and on pull-
  /// to-refresh from the billing screen. Network failure leaves the
  /// previous snapshot in place so the UI doesn't blank mid-session.
  Future<void> refreshFromBackend() async {
    try {
      // Run both fetches concurrently — methods and invoices are
      // independent, and waiting in series would double the perceived
      // latency on the billing screen.
      final results = await Future.wait<dynamic>([
        _repo.list(),
        _repo.listInvoices(),
      ]);
      final methods = results[0] as List<PaymentMethod>;
      final invoices = results[1] as List<Invoice>;
      final defaultId = methods
          .firstWhere(
            (m) => _isMarkedDefault(m, methods),
            orElse: () => methods.isEmpty
                ? const PaymentMethod(
                    id: '',
                    kind: PaymentMethodKind.visa,
                    label: '',
                    last4: '',
                  )
                : methods.first,
          )
          .id;
      state = state.copyWith(
        methods: methods,
        defaultMethodId: methods.isEmpty ? null : defaultId,
        clearDefault: methods.isEmpty,
        invoices: invoices,
        loaded: true,
      );
    } catch (_) {
      // Network blip — keep previous list. Mark loaded so the UI can flip
      // out of skeleton state and surface its empty / retry affordance.
      state = state.copyWith(loaded: true);
    }
  }

  /// Backend marks one row `is_default=true`; we pluck it out of the list
  /// after fetch. The repo doesn't surface the bit on PaymentMethod
  /// (intentionally — the UI only ever needs "is this the active one for
  /// checkout?"), so we re-fetch the raw list and pick. If the position
  /// of the default ever fights server ordering, this is the spot to fix.
  bool _isMarkedDefault(PaymentMethod m, List<PaymentMethod> all) {
    // Backend always lists the default first. Trust ordering rather than
    // round-tripping the bit, which keeps the UI shape unchanged.
    return all.isNotEmpty && all.first.id == m.id;
  }

  /// Add a method server-side, then refresh. The fresh `id` from the
  /// backend matters — it's what we'll send when checkout references the
  /// saved method by id.
  Future<PaymentMethod> addMethod({
    required PaymentMethodKind kind,
    required String label,
    String last4 = '',
    String? holder,
    int? expiryMm,
    int? expiryYy,
    String? cliqAlias,
    String? cliqPhone,
    bool makeDefault = false,
  }) async {
    final added = await _repo.add(
      kind: kind,
      label: label,
      last4: last4,
      holder: holder,
      expiryMm: expiryMm,
      expiryYy: expiryYy,
      cliqAlias: cliqAlias,
      cliqPhone: cliqPhone,
      isDefault: makeDefault,
    );
    await refreshFromBackend();
    return added;
  }

  Future<void> removeMethod(String id) async {
    await _repo.remove(id);
    await refreshFromBackend();
  }

  Future<void> setDefault(String id) async {
    await _repo.setDefault(id);
    await refreshFromBackend();
  }

  /// Backend writes an invoice row server-side as part of every
  /// `POST /subscriptions` so the checkout flow no longer pushes a
  /// local invoice. This call now just triggers a backend refresh so
  /// the receipt drawer surfaces the new row immediately. The
  /// `invoice` arg is kept for source-compat with callers that built
  /// a local Invoice; the value is ignored.
  Future<void> recordInvoice(Invoice _) async {
    await refreshFromBackend();
  }

  /// Wipe local state. Methods + invoices are server-owned so logout
  /// doesn't have to delete them per-row — they disappear when the
  /// next hydrate runs against a different identity.
  Future<void> clear() async {
    state = const BillingState();
  }
}

final billingProvider =
    StateNotifierProvider<BillingNotifier, BillingState>((ref) {
  return BillingNotifier(
    ref.read(billingRepositoryProvider),
  );
});
