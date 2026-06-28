import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/app_preferences.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/help_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/top_bounce_physics.dart';
import '../../../core/widgets/wordmark_refresh.dart';
import '../../../l10n/app_localizations.dart';
import '../data/notifications_repository.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() =>
      _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  String _filter = 'all';
  Future<List<BackendNotification>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<BackendNotification>> _load() {
    return ref.read(notificationsRepositoryProvider).list();
  }

  Future<void> _refresh() async {
    final fresh = _load();
    setState(() => _future = fresh);
    await fresh;
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      await _refresh();
    } catch (_) {
      // Surfaced silently — pull-to-refresh exists if the user wants
      // to retry. Mid-list errors aren't worth a dialog.
    }
  }

  Future<void> _onTap(BackendNotification n) async {
    if (n.isUnread) {
      try {
        await ref.read(notificationsRepositoryProvider).markRead(n.id);
        await _refresh();
      } catch (_) {
        // Best effort — read state matters less than not blocking the
        // tap-to-deep-link interaction.
      }
    }
    // Deep links are not yet wired; once the route table grows beyond
    // /home and /gyms/<slug>, plumb `n.deepLink` through go_router.
  }

  List<BackendNotification> _applyFilter(List<BackendNotification> all) {
    // Per-type preferences from settings. Toggling a category off in
    // Settings → Notifications should hide that category from this
    // list — otherwise the toggle is just storage with no observable
    // effect, which is precisely the "faking it" failure the user
    // flagged. OS-level (lock screen / status bar / badge) delivery
    // is deferred per CLAUDE.md §15 until FCM/APNs is wired; in-app
    // filtering is what we can ship today.
    final prefs = ref.read(appPreferencesProvider);
    final filteredByPref = all.where((n) {
      final t = n.type.toLowerCase();
      if (_isPlanType(t)) return prefs.notifPlanReminders;
      if (_isClubType(t)) return prefs.notifClubsNearby;
      if (_isPromoType(t)) return prefs.notifPromos;
      return true; // system, welcome, anything we don't categorise
    }).toList();
    switch (_filter) {
      case 'unread':
        return filteredByPref.where((n) => n.isUnread).toList();
      case 'check_in':
        return filteredByPref.where((n) => n.type == 'checkin').toList();
      case 'promo':
        return filteredByPref.where((n) => _isPromoType(n.type)).toList();
      case 'all':
      default:
        return filteredByPref;
    }
  }

  static bool _isPlanType(String t) =>
      t == 'plan_reminder' ||
      t == 'renewal_due' ||
      t == 'pass_active' ||
      t == 'subscription' ||
      t == 'checkin';
  static bool _isClubType(String t) =>
      t == 'gym_nearby' || t == 'new_partner' || t == 'club';
  static bool _isPromoType(String t) =>
      t == 'promo' || t == 'referral_bonus';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final locale = ref.watch(appPreferencesProvider).locale.languageCode;
    return Scaffold(
      body: Stack(
        children: [
          WordmarkRefresh(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: TopBouncePhysics(),
              ),
              padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Overline(l.notificationsOverline)],
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    DisplayText(l.notificationsHeadline, size: 36),
                    const SizedBox(width: 10),
                    SerifAccent(l.notificationsHeadlineAccent, size: 36),
                  ],
                ),
                const SizedBox(height: 20),
                _pills(l, gp),
                const SizedBox(height: 14),
                FutureBuilder<List<BackendNotification>>(
                  future: _future,
                  builder: (context, snapshot) {
                    final isFirstLoad =
                        snapshot.connectionState == ConnectionState.waiting;
                    final isPullRefreshing = RefreshScope.of(context);
                    // First-load and pull-refresh both render
                    // skeletons of the same shape — there's no
                    // reason to show a spinner on first load and
                    // skeletons on refresh, the member's mental
                    // model is the same in both states ("waiting
                    // for the list").
                    if (isFirstLoad || isPullRefreshing) {
                      return Column(
                        children: List.generate(
                          4,
                          (_) => const SkeletonNotificationRow(),
                        ),
                      );
                    }
                    // Treat both "API error" and "API returned empty
                    // list" as the same empty state. A brand-new
                    // member with zero notifications shouldn't be
                    // greeted with "An error occurred" — they should
                    // see the calm "no notifications yet" copy. A
                    // network hiccup falls through to the same state
                    // for the same reason: the page is showing
                    // *absence*, not a failure mode worth alarming
                    // the member about. Pull-to-refresh re-runs the
                    // fetch; auth or token-expired errors are handled
                    // upstream by the ApiClient interceptor.
                    final List<BackendNotification> items = snapshot.hasError
                        ? const <BackendNotification>[]
                        : (snapshot.data ?? const <BackendNotification>[]);
                    final filtered = _applyFilter(items);
                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            l.notificationsEmpty,
                            style: GPText.body(size: 14, color: gp.muted),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        if (items.any((n) => n.isUnread))
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton.icon(
                              onPressed: _markAllRead,
                              icon: Icon(
                                Icons.done_all,
                                size: 14,
                                color: gp.accentInk,
                              ),
                              label: Text(
                                l.notificationsMarkAllRead,
                                style: GPText.mono(
                                  size: 11,
                                  letterSpacing: 1.4,
                                  color: gp.accentInk,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ...filtered.map(
                          (n) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NotificationCard(
                              notification: n,
                              locale: locale,
                              onTap: () => _onTap(n),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          PositionedDirectional(
            top: topInset + 12,
            start: 20,
            child: const BackBtn(),
          ),
          Positioned(
            bottom: 78 + MediaQuery.viewPaddingOf(context).bottom,
            left: 20,
            child: HelpButton(tips: [
              HelpTip(icon: Icons.campaign_outlined, text: l.helpNotifications1),
              HelpTip(icon: Icons.mark_email_read_outlined, text: l.helpNotifications2),
              HelpTip(icon: Icons.tune_rounded, text: l.helpNotifications3),
            ],),
          ),
        ],
      ),
    );
  }

  Widget _pills(AppLocalizations l, GpColors gp) {
    final filters = [
      ('all', l.notifFilterAll),
      ('unread', l.notifFilterUnread),
      ('check_in', l.notifFilterCheckin),
      ('promo', l.notifFilterPromo),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final active = _filter == f.$1;
          return GestureDetector(
            onTap: () => setState(() => _filter = f.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? GP.lime22 : gp.bg2,
                borderRadius: BorderRadius.circular(GPRadius.pill),
                border: Border.all(
                  color: active ? gp.accentInk.withValues(alpha: 0.55) : gp.line,
                ),
              ),
              child: Center(
                child: Text(
                  f.$2.toUpperCase(),
                  style: GPText.mono(
                    size: 10,
                    letterSpacing: 1.4,
                    color: active ? gp.accentInk : gp.mutedSoft,
                    weight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.locale,
    required this.onTap,
  });

  final BackendNotification notification;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final isAr = locale == 'ar';
    final title = isAr ? notification.titleAr : notification.titleEn;
    final body = isAr ? notification.bodyAr : notification.bodyEn;
    final accent = _accentForType(notification.type);
    final icon = _iconForType(notification.type);
    final timeLabel = _formatRelativeTime(notification.createdAt);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isUnread ? gp.bg3 : gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(
              color: notification.isUnread
                  ? accent.withValues(alpha: 0.4)
                  : gp.line,
            ),
            boxShadow: gp.cardShadows,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: accent.withValues(alpha: 0.15),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GPText.body(
                              size: 14,
                              color: gp.fg,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          timeLabel,
                          style: GPText.mono(
                            size: 9,
                            letterSpacing: 1.2,
                            color: gp.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: GPText.body(
                        size: 13,
                        color: gp.mutedSoft,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (notification.isUnread)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8, top: 4),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentForType(String type) {
    switch (type) {
      case 'checkin':
        return GP.lime;
      case 'promo':
        return GP.warn;
      case 'expire':
        return GP.danger;
      case 'guest':
        return GP.success;
      case 'system':
      default:
        return GP.lime;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'checkin':
        return Icons.qr_code_scanner_rounded;
      case 'promo':
        return Icons.local_offer_outlined;
      case 'expire':
        return Icons.schedule_rounded;
      case 'guest':
        return Icons.group_add_outlined;
      case 'system':
      default:
        return Icons.notifications_active_outlined;
    }
  }

  /// Compact relative time. Anything inside an hour shows "Xm";
  /// inside a day shows "Xh"; older rows show the day. Locale-agnostic
  /// digits so admin / member views read the same string.
  String _formatRelativeTime(DateTime at) {
    final now = DateTime.now();
    final age = now.difference(at);
    if (age.inMinutes < 1) return 'now';
    if (age.inMinutes < 60) return '${age.inMinutes}m';
    if (age.inHours < 24) return '${age.inHours}h';
    if (age.inDays < 7) return '${age.inDays}d';
    final mm = at.month.toString().padLeft(2, '0');
    final dd = at.day.toString().padLeft(2, '0');
    return '$mm-$dd';
  }
}
