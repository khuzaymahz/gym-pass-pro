import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../gyms_filter_state.dart';

/// Floating top chrome — search pill on the left, filter button on
/// the right. Glass-blurred over the live map; sits on top of the
/// map layer in the page's stack so it doesn't lift on scroll.
class ExploreTopBar extends StatelessWidget {
  const ExploreTopBar({
    super.key,
    required this.searchCtrl,
    required this.searchFocus,
    required this.activeFilterCount,
    required this.onOpenFilters,
  });

  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final int activeFilterCount;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Positioned(
      top: topInset + 8,
      left: 12,
      right: 12,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(GPRadius.pill),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: _SearchField(
                  controller: searchCtrl,
                  focusNode: searchFocus,
                  hint: l.exploreSearchHint,
                  gp: gp,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(GPRadius.pill),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: _FilterIconButton(
                activeCount: activeFilterCount,
                onTap: onOpenFilters,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.gp,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final GpColors gp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: gp.bg2.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(GPRadius.pill),
          border: Border.all(color: gp.line),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 6, 0),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: gp.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                cursorColor: gp.accentInk,
                cursorWidth: 1.4,
                style: GPText.body(size: 14, color: gp.fg),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: hint,
                  hintStyle: GPText.body(size: 14, color: gp.muted),
                ),
                textInputAction: TextInputAction.search,
                // No `onChanged` here — the controller listener in
                // `_ExplorePageState._onSearchTextChanged` already
                // pushes (debounced) into the search-query provider.
                // Wiring both fires the same update twice per
                // keystroke and doubles the rebuild work.
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  controller.clear();
                  ref.read(gymsSearchQueryProvider.notifier).state = '';
                },
                iconSize: 16,
                splashRadius: 18,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(Icons.close_rounded, color: gp.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({
    required this.activeCount,
    required this.onTap,
  });

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final hasActive = activeCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GPRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: 48,
          padding: EdgeInsets.symmetric(
            horizontal: hasActive ? 14 : 12,
          ),
          decoration: BoxDecoration(
            color: hasActive ? gp.accent : gp.bg2.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(GPRadius.pill),
            border: Border.all(
              color: hasActive ? gp.accent : gp.line,
            ),
            boxShadow: hasActive
                ? [
                    BoxShadow(
                      color: gp.accent.withValues(alpha: 0.32),
                      blurRadius: 18,
                      spreadRadius: -4,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: hasActive ? gp.onLime : gp.fg,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: hasActive
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(start: 6),
                        child: Text(
                          '$activeCount',
                          style: GPText.mono(
                            size: 13,
                            letterSpacing: 0.5,
                            color: gp.onLime,
                            weight: FontWeight.w800,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
