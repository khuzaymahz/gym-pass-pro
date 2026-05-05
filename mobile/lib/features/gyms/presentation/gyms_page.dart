import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/gym_tile.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../l10n/app_localizations.dart';
import 'gym_detail_page.dart' show favoritedGymsProvider;
import 'gyms_filter_state.dart';

class GymsPage extends ConsumerStatefulWidget {
  const GymsPage({super.key});

  @override
  ConsumerState<GymsPage> createState() => _GymsPageState();
}

class _GymsPageState extends ConsumerState<GymsPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ref.read(gymsSearchQueryProvider);
    _searchCtrl.addListener(() {
      ref.read(gymsSearchQueryProvider.notifier).state = _searchCtrl.text;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GPGym> _computeFiltered({
    required String category,
    required Set<String> tiers,
    required String query,
    Set<String> favorites = const <String>{},
    bool favoritesOnly = false,
  }) {
    final list = GPGym.seed.where((g) {
      if (favoritesOnly && !favorites.contains(g.slug)) return false;
      final byCategory = category == 'all' || g.category == category;
      if (!byCategory) return false;
      final byTier = tiers.isEmpty || tiers.contains(g.tier);
      if (!byTier) return false;
      if (query.isEmpty) return true;
      final q = query.toLowerCase();
      return g.name.toLowerCase().contains(q) ||
          g.area.toLowerCase().contains(q);
    }).toList();

    // Sort alphabetically — distance was the previous sort key but
    // it lied (it was a hardcoded seed value that didn't reflect the
    // member's actual location). Live distance now comes from
    // [userPositionProvider] inside [GymRow]; ordering by name
    // gives a predictable shape until distance-aware sorting is
    // wired through here too.
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final category = ref.watch(gymsCategoryFilterProvider);
    final tierFilter = ref.watch(gymsTierFilterProvider);
    final query = ref.watch(gymsSearchQueryProvider);
    final favorites = ref.watch(favoritedGymsProvider);
    final favoritesOnly = ref.watch(gymsFavoritesOnlyProvider);
    final filtered = _computeFiltered(
      category: category,
      tiers: tierFilter,
      query: query,
      favorites: favorites,
      favoritesOnly: favoritesOnly,
    );

    // The page is now pushed as a top-level route (no shell wrapper),
    // so it owns its own Scaffold. Without this, the inner TextField
    // can't find a Material ancestor and asserts at first paint.
    return Scaffold(
      backgroundColor: gp.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: RadialGlow(
              opacity: 0.12,
              size: 520,
              alignment: Alignment(0, -0.95),
            ),
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 16),
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Overline(l.clubsCount(GPGym.seed.length))],
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                DisplayText(l.gymsHeadline, size: 36),
                const SizedBox(width: 10),
                SerifAccent(l.gymsHeadlineAccent, size: 36),
              ],
            ),
            const SizedBox(height: 18),
            _searchField(l, gp),
            const SizedBox(height: 14),
            _filterPills(l, gp, category),
            const SizedBox(height: 14),
            _miniMap(filtered, gp),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    favoritesOnly && favorites.isEmpty
                        ? l.gymsEmptyFavorites
                        : l.gymsEmpty,
                    style: GPText.body(size: 14, color: gp.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...filtered.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GymRow(
                    gym: g,
                    onTap: () => context.push('/gyms/${g.slug}'),
                  ),
                ),
              ),
          ],
        ),
        PositionedDirectional(
          top: topInset + 12,
          start: 20,
          child: const BackBtn(),
        ),
          PositionedDirectional(
            top: topInset + 12,
            end: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconBtn(
                  icon: favoritesOnly ? Icons.favorite : Icons.favorite_border,
                  tint: favoritesOnly ? GP.lime : null,
                  onPressed: () {
                    ref.read(gymsFavoritesOnlyProvider.notifier).state =
                        !favoritesOnly;
                  },
                ),
                const SizedBox(width: 8),
                IconBtn(
                  icon: Icons.tune,
                  onPressed: () => _openFilterSheet(l),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(AppLocalizations l, GpColors gp) {
    return Container(
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: TextField(
        controller: _searchCtrl,
        cursorColor: gp.accentInk,
        style: GPText.body(size: 14, color: gp.fg),
        decoration: InputDecoration(
          hintText: l.gymsSearchHint,
          hintStyle: GPText.body(size: 13, color: gp.muted),
          prefixIcon: Icon(Icons.search, color: gp.muted, size: 18),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: gp.muted, size: 16),
                  onPressed: () => _searchCtrl.clear(),
                ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _filterPills(AppLocalizations l, GpColors gp, String activeKey) {
    final filters = <(String, String, Color)>[
      ('all', l.gymsFilterAll, gp.fg),
      ('gym', l.gymsFilterGym, GPCategory.gym),
      ('crossfit', l.gymsFilterCrossfit, GPCategory.crossfit),
      ('martial', l.gymsFilterMartial, GPCategory.martial),
      ('yoga', l.gymsFilterYoga, GPCategory.yoga),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final active = activeKey == f.$1;
          return GestureDetector(
            onTap: () =>
                ref.read(gymsCategoryFilterProvider.notifier).state = f.$1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? f.$3.withValues(alpha: 0.16) : gp.bg2,
                borderRadius: BorderRadius.circular(GPRadius.pill),
                border: Border.all(
                  color: active ? f.$3.withValues(alpha: 0.55) : gp.line,
                ),
              ),
              child: Center(
                child: Text(
                  f.$2.toUpperCase(),
                  style: GPText.mono(
                    size: 10,
                    letterSpacing: 1.4,
                    color: active ? f.$3 : gp.mutedSoft,
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

  Widget _miniMap(List<GPGym> gyms, GpColors gp) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapPainter(gp))),
          ...List.generate(gyms.length, (i) {
            final g = gyms[i];
            final dx = 30 + (i * 48) % 280;
            final dy = 20 + (i * 23) % 80;
            return Positioned(
              left: dx.toDouble(),
              top: dy.toDouble(),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: g.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: gp.bg, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: g.color.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            );
          }),
          Positioned(
            left: 10,
            bottom: 8,
            child: Text(
              AppLocalizations.of(context).gymsMapPreview,
              style: GPText.mono(size: 9, letterSpacing: 1.5, color: gp.muted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet(AppLocalizations l) async {
    final gp = context.gp;
    // Live-apply: the sheet now writes directly to providers, so the list
    // behind it filters as the user toggles. Removed the previous draft +
    // Apply-button pattern — users were missing the commit step and seeing
    // stale results, then assuming the filter was broken.

    String tierLabel(String key) {
      switch (key) {
        case 'silver':
          return l.tierSilver;
        case 'gold':
          return l.tierGold;
        case 'platinum':
          return l.tierPlatinum;
        case 'diamond':
          return l.tierDiamond;
      }
      return key;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: gp.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GPRadius.xl2)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, sheetRef, _) {
          final activeCategory = sheetRef.watch(gymsCategoryFilterProvider);
          final activeTiers = sheetRef.watch(gymsTierFilterProvider);
          final filteredCount = _computeFiltered(
            category: activeCategory,
            tiers: activeTiers,
            query: sheetRef.read(gymsSearchQueryProvider),
          ).length;

          void setCategory(String key) =>
              sheetRef.read(gymsCategoryFilterProvider.notifier).state = key;

          void toggleTier(String key) {
            final next = {...activeTiers};
            if (!next.remove(key)) next.add(key);
            sheetRef.read(gymsTierFilterProvider.notifier).state = next;
          }

          void resetAll() {
            sheetRef.read(gymsCategoryFilterProvider.notifier).state = 'all';
            sheetRef.read(gymsTierFilterProvider.notifier).state = <String>{};
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: gp.line2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DisplayText(l.filterDialogTitle, size: 24),
                  const SizedBox(height: 18),
                  Text(
                    l.filterCategory.toUpperCase(),
                    style: GPText.mono(
                      size: 10,
                      letterSpacing: 1.8,
                      color: gp.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _categoryChip(
                        gp,
                        label: l.gymsFilterAll,
                        color: gp.fg,
                        selected: activeCategory == 'all',
                        onTap: () => setCategory('all'),
                      ),
                      _categoryChip(
                        gp,
                        label: l.gymsFilterGym,
                        color: GPCategory.gym,
                        selected: activeCategory == 'gym',
                        onTap: () => setCategory('gym'),
                      ),
                      _categoryChip(
                        gp,
                        label: l.gymsFilterCrossfit,
                        color: GPCategory.crossfit,
                        selected: activeCategory == 'crossfit',
                        onTap: () => setCategory('crossfit'),
                      ),
                      _categoryChip(
                        gp,
                        label: l.gymsFilterMartial,
                        color: GPCategory.martial,
                        selected: activeCategory == 'martial',
                        onTap: () => setCategory('martial'),
                      ),
                      _categoryChip(
                        gp,
                        label: l.gymsFilterYoga,
                        color: GPCategory.yoga,
                        selected: activeCategory == 'yoga',
                        onTap: () => setCategory('yoga'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l.filterTier.toUpperCase(),
                    style: GPText.mono(
                      size: 10,
                      letterSpacing: 1.8,
                      color: gp.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in GPTier.all)
                        _categoryChip(
                          gp,
                          label: tierLabel(t.key),
                          color: t.color,
                          selected: activeTiers.contains(t.key),
                          onTap: () => toggleTier(t.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Live count: tells the user exactly how the filter is
                  // affecting results so they don't have to dismiss the sheet
                  // to check.
                  Text(
                    l.filterMatchCount(filteredCount),
                    style: GPText.mono(
                      size: 10,
                      letterSpacing: 1.4,
                      color: gp.mutedSoft,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: resetAll,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: gp.line2),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(GPRadius.pill),
                            ),
                          ),
                          child: Text(
                            l.filterReset.toUpperCase(),
                            style: GPText.mono(
                              size: 11,
                              letterSpacing: 1.4,
                              color: gp.fg,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: GP.lime,
                            foregroundColor: GP.ink,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(GPRadius.pill),
                            ),
                          ),
                          child: Text(
                            l.filterDone.toUpperCase(),
                            style: GPText.mono(
                              size: 11,
                              letterSpacing: 1.4,
                              color: GP.ink,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _categoryChip(
    GpColors gp, {
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : gp.bg3,
          borderRadius: BorderRadius.circular(GPRadius.pill),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.55) : gp.line,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: GPText.mono(
            size: 10,
            letterSpacing: 1.4,
            color: selected ? color : gp.mutedSoft,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.gp);
  final GpColors gp;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gp.line
      ..strokeWidth = 0.6;
    for (var x = 0; x < size.width; x += 24) {
      canvas.drawLine(
        Offset(x.toDouble(), 0),
        Offset(x.toDouble(), size.height),
        grid,
      );
    }
    for (var y = 0; y < size.height; y += 24) {
      canvas.drawLine(
        Offset(0, y.toDouble()),
        Offset(size.width, y.toDouble()),
        grid,
      );
    }
    final road = Paint()
      ..color = gp.line2
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height * 0.4)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.2,
        size.width * 0.55,
        size.height * 0.6,
        size.width,
        size.height * 0.3,
      );
    canvas.drawPath(path, road);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => oldDelegate.gp != gp;
}
