import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'support_repository.dart';

/// Local view-model classification. The backend stores
/// `bug | complaint | feature | account | payment | gym_issue | other`
/// while the mobile splits its UX into "message" (general help) and
/// "report" (bug-or-issue report). We map both forms onto the backend
/// categories at submit time and onto a coarse kind at hydrate time.
enum SupportTicketKind { message, report }

extension SupportTicketKindX on SupportTicketKind {
  String get storageKey => switch (this) {
        SupportTicketKind.message => 'message',
        SupportTicketKind.report => 'report',
      };
}

/// Backend → mobile category mapping. `bug` and `gym_issue` both surface
/// as report-style entries because the report flow already collects the
/// gym + attachment + description; everything else stays a message.
SupportTicketKind kindForBackendCategory(String category) {
  switch (category) {
    case 'bug':
    case 'gym_issue':
      return SupportTicketKind.report;
    default:
      return SupportTicketKind.message;
  }
}

class SupportTicket {
  const SupportTicket({
    required this.ref,
    required this.kind,
    required this.createdIso,
    required this.subject,
    required this.status,
  });

  /// Short, user-facing reference. Currently the last 8 characters of the
  /// backend UUID — readable enough to share in a chat with support, and
  /// stable across the ticket lifetime.
  final String ref;
  final SupportTicketKind kind;
  final String createdIso;
  final String subject;
  final String status;
}

class SupportTicketsState {
  const SupportTicketsState({this.tickets = const [], this.loaded = false});
  final List<SupportTicket> tickets;
  final bool loaded;

  SupportTicketsState copyWith({
    List<SupportTicket>? tickets,
    bool? loaded,
  }) =>
      SupportTicketsState(
        tickets: tickets ?? this.tickets,
        loaded: loaded ?? this.loaded,
      );
}

class SupportTicketsNotifier extends StateNotifier<SupportTicketsState> {
  SupportTicketsNotifier(this._repo) : super(const SupportTicketsState()) {
    refreshFromBackend();
  }

  final SupportRepository _repo;

  /// Pull the authoritative ticket list from the backend. Called on
  /// init, after a submit, and from pull-to-refresh on the help screen.
  /// Network failures leave the previous list in place — better stale
  /// than a sudden empty mid-session.
  Future<void> refreshFromBackend() async {
    try {
      final rows = await _repo.list();
      state = state.copyWith(
        tickets: rows.map(_toLocalTicket).toList(),
        loaded: true,
      );
    } catch (_) {
      state = state.copyWith(loaded: true);
    }
  }

  SupportTicket _toLocalTicket(BackendTicket b) {
    return SupportTicket(
      ref: _refFromId(b.id),
      kind: kindForBackendCategory(b.category),
      createdIso: b.createdAt.toIso8601String(),
      subject: b.subject,
      status: b.status,
    );
  }

  String _refFromId(String id) {
    final clean = id.replaceAll('-', '');
    if (clean.length < 8) return clean.toUpperCase();
    return 'GP-${clean.substring(clean.length - 8).toUpperCase()}';
  }

  /// "Talk to support" general message. No specific category; backend
  /// stores it as `other`. Returns the user-facing reference so the
  /// confirmation dialog can show it.
  Future<String> submitMessage({
    required String subject,
    required String body,
  }) async {
    final ticket = await _repo.create(
      category: 'other',
      priority: 'normal',
      subject: subject,
      body: body,
    );
    await refreshFromBackend();
    return _refFromId(ticket.id);
  }

  /// "Report an issue" flow — `category` comes from the report sheet's
  /// pickers and is mapped to a backend category. `gym` and `attachment`
  /// ride along in `meta` so they surface in the admin queue without
  /// needing dedicated columns.
  Future<String> submitReport({
    required String category,
    required String description,
    String? gym,
    String? attachment,
  }) async {
    final backendCategory = _mapReportCategory(category);
    final meta = <String, dynamic>{};
    if (gym != null && gym.isNotEmpty) meta['gym'] = gym;
    if (attachment != null && attachment.isNotEmpty) {
      meta['attachment'] = attachment;
    }
    final subject = _subjectFromCategory(category);
    final ticket = await _repo.create(
      category: backendCategory,
      priority: 'normal',
      subject: subject,
      body: description,
      meta: meta.isEmpty ? null : meta,
    );
    await refreshFromBackend();
    return _refFromId(ticket.id);
  }

  /// Loose mapping from the report sheet's free-form category text to
  /// the backend enum. Anything we don't recognise becomes `other` so
  /// the admin queue still sees the ticket — they can re-categorise.
  String _mapReportCategory(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('gym')) return 'gym_issue';
    if (lower.contains('bug') || lower.contains('crash')) return 'bug';
    if (lower.contains('pay') || lower.contains('billing')) return 'payment';
    if (lower.contains('account') || lower.contains('login')) {
      return 'account';
    }
    if (lower.contains('feature') || lower.contains('suggest')) {
      return 'feature';
    }
    if (lower.contains('complaint')) return 'complaint';
    return 'other';
  }

  String _subjectFromCategory(String category) {
    if (category.trim().isEmpty) return 'Report from mobile';
    final trimmed = category.trim();
    if (trimmed.length <= 80) return trimmed;
    return trimmed.substring(0, 80);
  }
}

final supportTicketsProvider =
    StateNotifierProvider<SupportTicketsNotifier, SupportTicketsState>((ref) {
  return SupportTicketsNotifier(ref.read(supportRepositoryProvider));
});
