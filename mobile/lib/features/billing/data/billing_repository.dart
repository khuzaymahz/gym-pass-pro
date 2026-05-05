import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/providers.dart';
import 'billing_state.dart';

/// Wire-shape from the backend payment-methods endpoint. Held privately
/// because consumers always cast through [PaymentMethod] — keeping this
/// in one file means the mapping logic can't drift between hydrate and
/// add paths.
class BackendPaymentMethod {
  const BackendPaymentMethod({
    required this.id,
    required this.kind,
    required this.label,
    required this.last4,
    this.holder,
    this.expiryMm,
    this.expiryYy,
    this.cliqAlias,
    this.cliqPhone,
    required this.isDefault,
  });

  final String id;
  final String kind; // backend enum: card | cliq | apple_pay | google_pay | mock
  final String label;
  final String last4;
  final String? holder;
  final int? expiryMm;
  final int? expiryYy;
  final String? cliqAlias;
  final String? cliqPhone;
  final bool isDefault;

  factory BackendPaymentMethod.fromJson(Map<String, dynamic> j) {
    return BackendPaymentMethod(
      id: j['id'] as String,
      kind: j['kind'] as String,
      label: j['label'] as String,
      last4: j['last4'] as String? ?? '',
      holder: j['holder'] as String?,
      expiryMm: j['expiryMm'] as int?,
      expiryYy: j['expiryYy'] as int?,
      cliqAlias: j['cliqAlias'] as String?,
      cliqPhone: j['cliqPhone'] as String?,
      isDefault: j['isDefault'] as bool? ?? false,
    );
  }

  /// Adapt to the UI's [PaymentMethod]. Backend collapses Visa and
  /// Mastercard into `kind=card`; the brand survives in `label` (which
  /// the add-method sheet wrote with "Visa" / "Mastercard"). If the
  /// label is ambiguous we default to Visa — the brand only affects the
  /// icon, never the gateway routing.
  PaymentMethod toUiMethod() {
    final uiKind = _kindFromBackend(kind, label);
    return PaymentMethod(
      id: id,
      kind: uiKind,
      label: label,
      last4: last4,
      holder: holder,
      expiryMm: expiryMm,
      expiryYy: expiryYy,
      cliqAlias: cliqAlias,
      cliqPhone: cliqPhone,
    );
  }
}

PaymentMethodKind _kindFromBackend(String backendKind, String label) {
  switch (backendKind) {
    case 'cliq':
      return PaymentMethodKind.cliq;
    case 'apple_pay':
      return PaymentMethodKind.applePay;
    case 'google_pay':
      return PaymentMethodKind.googlePay;
    case 'card':
    default:
      // Brand inference: the add sheet writes "Visa · primary" or
      // "Mastercard …" — first token wins. Anything we don't recognise
      // falls back to Visa so the row at least renders.
      final lower = label.toLowerCase();
      if (lower.contains('mastercard')) return PaymentMethodKind.mastercard;
      return PaymentMethodKind.visa;
  }
}

String _backendKindFor(PaymentMethodKind kind) {
  switch (kind) {
    case PaymentMethodKind.visa:
    case PaymentMethodKind.mastercard:
      return 'card';
    case PaymentMethodKind.cliq:
      return 'cliq';
    case PaymentMethodKind.applePay:
      return 'apple_pay';
    case PaymentMethodKind.googlePay:
      return 'google_pay';
  }
}

class BillingRepository {
  BillingRepository(this._api);

  final ApiClient _api;

  Future<List<PaymentMethod>> list() async {
    final response = await _api.get<List<dynamic>>(
      '/api/v1/me/payment-methods',
      authed: true,
    );
    final raw = response.data ?? const [];
    return raw
        .map(
          (e) => BackendPaymentMethod.fromJson(
            (e as Map).cast<String, dynamic>(),
          ).toUiMethod(),
        )
        .toList();
  }

  /// Add a saved method. The mobile sheet writes `holder`, `last4` etc.
  /// after a Luhn / format check — the backend does its own light
  /// validation (last4 is 4 digits, expiry mm/yy in range, CliQ has
  /// at least one identifier). We pass `isDefault=true` only when the
  /// caller explicitly asked; the backend auto-promotes the very first
  /// method on a new account either way.
  Future<PaymentMethod> add({
    required PaymentMethodKind kind,
    required String label,
    String last4 = '',
    String? holder,
    int? expiryMm,
    int? expiryYy,
    String? cliqAlias,
    String? cliqPhone,
    bool isDefault = false,
  }) async {
    final body = <String, dynamic>{
      'kind': _backendKindFor(kind),
      'label': label,
      'last4': last4,
      if (holder != null) 'holder': holder,
      if (expiryMm != null) 'expiryMm': expiryMm,
      if (expiryYy != null) 'expiryYy': expiryYy,
      if (cliqAlias != null) 'cliqAlias': cliqAlias,
      if (cliqPhone != null) 'cliqPhone': cliqPhone,
      'isDefault': isDefault,
    };
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/me/payment-methods',
      body: body,
      authed: true,
    );
    return BackendPaymentMethod.fromJson(response.data!).toUiMethod();
  }

  Future<void> remove(String id) async {
    await _api.delete<void>('/api/v1/me/payment-methods/$id', authed: true);
  }

  Future<PaymentMethod> setDefault(String id) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/v1/me/payment-methods/$id/default',
      authed: true,
    );
    return BackendPaymentMethod.fromJson(response.data!).toUiMethod();
  }

  /// Fetch the member's invoice ledger. Backend emits one row per
  /// completed payment with the matching subscription's tier and
  /// billing window, so the mobile receipt drawer can render without a
  /// second hop. The list is bounded server-side at 100 rows.
  Future<List<Invoice>> listInvoices({int limit = 50}) async {
    final response = await _api.get<List<dynamic>>(
      '/api/v1/me/invoices',
      query: {'limit': '$limit'},
      authed: true,
    );
    final raw = response.data ?? const [];
    return raw
        .map((e) => _backendInvoiceToUi((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

/// Map the backend `InvoiceRead` shape onto the mobile UI's [Invoice]
/// data class. The backend carries a richer payload (status, gateway
/// txn id, billing window) but the receipt drawer only renders amount,
/// date, tier, and paid-state for now — keep the mapping narrow so
/// adding fields later is an additive change.
Invoice _backendInvoiceToUi(Map<String, dynamic> j) {
  final paid = j['status'] == 'succeeded';
  // ISO date for the receipt header — paidAt when present (succeeded
  // path), createdAt when not (pending or failed). Either way the
  // user gets a stable date that matches their card statement.
  final iso = (j['paidAt'] ?? j['createdAt']) as String;
  final isoDate = iso.split('T').first;
  final amountStr = (j['amountJod'] ?? '0').toString();
  final amount = double.tryParse(amountStr)?.round() ?? 0;
  return Invoice(
    id: j['id'] as String,
    iso: isoDate,
    amountJod: amount,
    tierKey: j['tier'] as String,
    paid: paid,
  );
}

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(ref.read(apiClientProvider));
});
