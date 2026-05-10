import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../gym_detail_page.dart' show favoritedGymsProvider;
import '../gyms_filter_state.dart';

/// Modal filters sheet — favourites toggle, category chips, tier
/// chips. Tapping any chip / toggle pushes immediately into the
/// corresponding Riverpod provider; the explore page rebuilds on
/// each change so the gym list + map markers thin in real time.
/// Closing the sheet keeps the filters in place.
class FiltersSheet extends ConsumerWidget {
  const FiltersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final category = ref.watch(gymsCategoryFilterProvider);
    final tiers = ref.watch(gymsTierFilterProvider);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: gp.bg2.withValues(alpha: 0.96),
            border: Border(top: BorderSide(color: gp.line, width: 0.5)),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tap-to-dismiss target around the drag handle. The
                // handle itself is only 5 px tall — too small a hit
                // area for a thumb tap, and members were instinctively
                // tapping it to close the sheet rather than dragging.
                // The wrapping `GestureDetector` claims a 32-px-tall
                // band of negative space around the handle (the
                // `EdgeInsets.symmetric(vertical: 14)` padding) so the
                // tap lands cleanly without stealing space from the
                // visible handle bar.
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: gp.line2,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      l.exploreFiltersTitle,
                      style: GPText.display(24, color: gp.fg, height: 1.0),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref.read(gymsCategoryFilterProvider.notifier).state =
                            'all';
                        ref.read(gymsTierFilterProvider.notifier).state =
                            const <String>{};
                        ref.read(gymsFavoritesOnlyProvider.notifier).state =
                            false;
                      },
                      child: Text(
                        l.exploreFiltersReset,
                        style: GPText.mono(
                          size: 11,
                          letterSpacing: 1.4,
                          color: gp.accentInk,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _FavoritesToggleRow(
                  active: ref.watch(gymsFavoritesOnlyProvider),
                  count: ref.watch(favoritedGymsProvider).length,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    ref.read(gymsFavoritesOnlyProvider.notifier).state = v;
                  },
                  l: l,
                  gp: gp,
                ),
                const SizedBox(height: 22),
                _SectionLabel(text: l.exploreFiltersCategorySection),
                const SizedBox(height: 10),
                _CategoryWrap(
                  active: category,
                  onChange: (v) {
                    HapticFeedback.selectionClick();
                    ref.read(gymsCategoryFilterProvider.notifier).state = v;
                  },
                  l: l,
                  gp: gp,
                ),
                const SizedBox(height: 22),
                _SectionLabel(text: l.exploreFiltersTierSection),
                const SizedBox(height: 10),
                _TierWrap(
                  active: tiers,
                  onToggle: (key) {
                    HapticFeedback.selectionClick();
                    final next = Set<String>.from(tiers);
                    if (next.contains(key)) {
                      next.remove(key);
                    } else {
                      next.add(key);
                    }
                    ref.read(gymsTierFilterProvider.notifier).state = next;
                  },
                  l: l,
                  gp: gp,
                ),
                // No Done button. Filter taps apply live (each chip /
                // toggle mutates Riverpod state and the map rebuilds
                // immediately), and the drag handle is tap-to-dismiss
                // — a separate Done CTA would just be a third path
                // back to the same already-applied state. Removing
                // it keeps the sheet honest about what it does.
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Text(
      text.toUpperCase(),
      style: GPText.mono(
        size: 10,
        letterSpacing: 1.6,
        color: gp.muted,
        weight: FontWeight.w700,
      ),
    );
  }
}

class _FavoritesToggleRow extends StatelessWidget {
  const _FavoritesToggleRow({
    required this.active,
    required this.count,
    required this.onChanged,
    required this.l,
    required this.gp,
  });

  final bool active;
  final int count;
  final ValueChanged<bool> onChanged;
  final AppLocalizations l;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    // Disabled only when there are NO favourites AND the filter isn't
    // currently on. If the filter is somehow stuck ON with 0 favourites
    // (e.g. a Riverpod listener missed the update), the toggle stays
    // tappable so the member can turn it OFF without having to hit
    // Reset — the original bug was that `disabled = count == 0`
    // blocked turn-off too.
    final disabled = count == 0 && !active;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.lg),
        onTap: disabled ? null : () => onChanged(!active),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: active ? GP.lime22 : gp.bg3,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(
              color: active ? gp.accentInk.withValues(alpha: 0.55) : gp.line,
            ),
          ),
          child: Row(
            children: [
              Icon(
                active ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: active ? gp.accentInk : (disabled ? gp.muted : gp.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.exploreFiltersFavoritesLabel,
                  style: GPText.body(
                    size: 14,
                    color: disabled ? gp.muted : gp.fg,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$count',
                style: GPText.mono(
                  size: 11,
                  letterSpacing: 1.2,
                  color: disabled ? gp.muted : gp.mutedSoft,
                ),
              ),
              const SizedBox(width: 6),
              Switch.adaptive(
                value: active,
                onChanged: disabled ? null : onChanged,
                activeThumbColor: gp.accentInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryWrap extends StatelessWidget {
  const _CategoryWrap({
    required this.active,
    required this.onChange,
    required this.l,
    required this.gp,
  });

  final String active;
  final ValueChanged<String> onChange;
  final AppLocalizations l;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String, IconData)>[
      ('all', l.gymsCategoryAll, Icons.public),
      ('gym', l.gymsCategoryGym, Icons.fitness_center),
      ('crossfit', l.gymsCategoryCrossfit, Icons.bolt_outlined),
      ('martial', l.gymsCategoryMartial, Icons.sports_mma_outlined),
      ('yoga', l.gymsCategoryYoga, Icons.self_improvement_outlined),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in entries)
          _SheetChip(
            label: e.$2,
            icon: e.$3,
            active: active == e.$1,
            tint: e.$1 == 'all' ? gp.accentInk : GPCategory.color(e.$1),
            onTap: () => onChange(e.$1),
          ),
      ],
    );
  }
}

class _TierWrap extends StatelessWidget {
  const _TierWrap({
    required this.active,
    required this.onToggle,
    required this.l,
    required this.gp,
  });

  final Set<String> active;
  final ValueChanged<String> onToggle;
  final AppLocalizations l;
  final GpColors gp;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('silver', l.tierSilver),
      ('gold', l.tierGold),
      ('platinum', l.tierPlatinum),
      ('diamond', l.tierDiamond),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in entries)
          _SheetChip(
            label: e.$2,
            dotColor: GPTier.byKey(e.$1).color,
            active: active.contains(e.$1),
            tint: GPTier.byKey(e.$1).color,
            onTap: () => onToggle(e.$1),
          ),
      ],
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.active,
    required this.tint,
    required this.onTap,
    this.icon,
    this.dotColor,
  });

  final String label;
  final bool active;
  final Color tint;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GPRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? tint.withValues(alpha: 0.18) : gp.bg3,
            borderRadius: BorderRadius.circular(GPRadius.pill),
            border: Border.all(
              color: active ? tint.withValues(alpha: 0.6) : gp.line,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: active ? tint : gp.mutedSoft,
                ),
                const SizedBox(width: 6),
              ] else if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GPText.body(
                  size: 13,
                  color: active ? tint : gp.fg,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
