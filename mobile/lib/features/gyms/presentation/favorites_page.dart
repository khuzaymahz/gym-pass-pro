import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gym_tile.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/di/providers.dart';
import '../../home/presentation/home_page.dart' show gymSummaryToGPGym;
import '../data/gym_repository.dart';
import '../data/media_url.dart';
import 'gym_detail_page.dart' show favoritedGymsProvider;
import 'gyms_filter_state.dart';

/// Standalone favorites surface — reachable from the You menu. Lists
/// every gym the member has tapped the heart on, in alphabetical
/// order. Tapping a row routes into the gym profile; an empty state
/// prompts the member to head to Explore and start saving.
///
/// Source of truth: the live `gymsListProvider` (backend
/// `/api/v1/gyms`). Previously this surface filtered the local
/// `GPGym.seed` list, which is why members who favourited
/// backend-only gyms (every real Jordan gym is backend-seeded —
/// `GPGym.seed` is the legacy hardcoded prototype set) saw an empty
/// list even though their heart-taps had been recorded correctly.
/// Per CLAUDE.md rule 9, no surface may rely on the local seed to
/// hide a backend failure. If `gymsListProvider` is still hydrating
/// we render skeleton placeholders; on error we render the same
/// empty state, which is correct behaviour (we don't lie about
/// having data).
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final favorites = ref.watch(favoritedGymsProvider);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final gymsAsync = ref.watch(gymsListProvider);
    final apiBaseUrl = ref.watch(envProvider).apiBaseUrl;
    final allGyms = gymsAsync.valueOrNull ?? const [];
    // Resolve the backend's `/media/...` relative URL into an
    // absolute one CachedNetworkImage can fetch. Done at the source
    // so the row builder downstream stays presentation-only.
    final saved = allGyms
        .where((g) => favorites.contains(g.slug))
        .map((s) => (
              gpgym: gymSummaryToGPGym(s, isAr: isAr),
              logoUrl: s.logoUrl == null
                  ? null
                  : resolveMediaUrl(apiBaseUrl, s.logoUrl!),
            ))
        .toList()
      ..sort((a, b) => a.gpgym.name.compareTo(b.gpgym.name));
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final isLoading = gymsAsync.isLoading && allGyms.isEmpty;
    return Scaffold(
      backgroundColor: gp.bg,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Overline(l.favoritesOverline)],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    DisplayText(l.favoritesHeadline, size: 34),
                    const SizedBox(width: 10),
                    SerifAccent(l.favoritesHeadlineAccent, size: 34),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : saved.isEmpty
                          ? _empty(context, ref, l, gp)
                          : ListView.separated(
                              padding: const EdgeInsets.only(
                                top: 4,
                                bottom: 24,
                              ),
                              itemCount: saved.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final entry = saved[i];
                                return GymRow(
                                  gym: entry.gpgym,
                                  logoUrl: entry.logoUrl,
                                  onTap: () => context
                                      .push('/gyms/${entry.gpgym.slug}'),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            top: topInset + 12,
            start: 20,
            child: const BackBtn(fallback: '/profile'),
          ),
        ],
      ),
    );
  }

  Widget _empty(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    GpColors gp,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 56, color: gp.muted),
            const SizedBox(height: 14),
            Text(
              l.favoritesEmptyTitle,
              textAlign: TextAlign.center,
              style: GPText.display(22, color: gp.fg, height: 1.0),
            ),
            const SizedBox(height: 10),
            Text(
              l.favoritesEmptyBody,
              textAlign: TextAlign.center,
              style: GPText.body(size: 14, color: gp.mutedSoft, height: 1.5),
            ),
            const SizedBox(height: 18),
            PillButton(
              label: l.favoritesEmptyCta,
              trailingIcon: Icons.arrow_forward,
              onPressed: () {
                // Pre-load Explore with the favorites filter off so
                // the member sees the full network — the goal here is
                // discovery, not re-filtering to the (still-empty)
                // favorites set.
                ref.read(gymsFavoritesOnlyProvider.notifier).state = false;
                context.go('/explore');
              },
            ),
          ],
        ),
      ),
    );
  }
}
