import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/help_button.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/top_bounce_physics.dart';
import '../../../l10n/app_localizations.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqEntry {
  final String question;
  final String answer;
  final String category;
  const _FaqEntry(this.question, this.answer, this.category);
}

class _FaqPageState extends State<FaqPage> {
  final _searchCtrl = TextEditingController();
  String _filter = 'all';
  final Set<int> _open = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_FaqEntry> _entries(AppLocalizations l) => [
        _FaqEntry(l.faqQ1, l.faqA1, 'checkin'),
        _FaqEntry(l.faqQ2, l.faqA2, 'billing'),
        _FaqEntry(l.faqQ3, l.faqA3, 'general'),
        _FaqEntry(l.faqQ5, l.faqA5, 'billing'),
        _FaqEntry(l.faqQ6, l.faqA6, 'billing'),
        _FaqEntry(l.faqQ7, l.faqA7, 'general'),
        _FaqEntry(l.faqQ8, l.faqA8, 'classes'),
      ];

  List<_FaqEntry> _filtered(List<_FaqEntry> all) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return all.where((e) {
      if (_filter != 'all' && e.category != _filter) return false;
      if (query.isEmpty) return true;
      return e.question.toLowerCase().contains(query) ||
          e.answer.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final entries = _entries(l);
    final filtered = _filtered(entries);
    // No `WordmarkRefresh` here — FAQ entries are localised strings
    // shipped in the ARB bundle, so there is nothing to re-fetch. A
    // pull-to-refresh gesture would be theatre that lies about what
    // it's doing. If a CMS-driven FAQ ever ships, wrap the ListView
    // in a `WordmarkRefresh` and re-add the skeleton-on-refresh
    // gating then.
    return Scaffold(
      body: Stack(
        children: [
          ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: TopBouncePhysics(),
            ),
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 28),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Overline(l.faqOverline)],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  DisplayText(l.faqHeadline, size: 36),
                  const SizedBox(width: 10),
                  SerifAccent(l.faqHeadlineAccent, size: 36),
                ],
              ),
              const SizedBox(height: 12),
              Text(l.faqBlurb,
                  style: GPText.body(size: 14, color: gp.mutedSoft),),
              const SizedBox(height: 20),
              _searchField(l, gp),
              const SizedBox(height: 14),
              _pills(l, gp),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      l.faqEmpty,
                      textAlign: TextAlign.center,
                      style: GPText.body(size: 14, color: gp.muted),
                    ),
                  ),
                )
              else
                ...filtered.asMap().entries.map((e) {
                  final key = _entryKey(entries, e.value);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _faqCard(e.value, key, gp),
                  );
                }),
              const SizedBox(height: 20),
              _contactFooter(l, gp),
            ],
          ),
          PositionedDirectional(
            top: topInset + 12,
            start: 20,
            child: const BackBtn(fallback: '/profile'),
          ),
          Positioned(
            bottom: 78 + MediaQuery.viewPaddingOf(context).bottom,
            left: 20,
            child: HelpButton(tips: [
              HelpTip(icon: Icons.touch_app_outlined, text: l.helpSupportFaq1),
              HelpTip(icon: Icons.search, text: l.helpSupportFaq2),
              HelpTip(icon: Icons.filter_list_rounded, text: l.helpSupportFaq3),
            ],),
          ),
        ],
      ),
    );
  }

  int _entryKey(List<_FaqEntry> all, _FaqEntry entry) => all.indexOf(entry);

  Widget _searchField(AppLocalizations l, GpColors gp) {
    return TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() {}),
      cursorColor: gp.accentInk,
      style: GPText.body(size: 14, color: gp.fg),
      decoration: InputDecoration(
        hintText: l.faqSearchHint,
        hintStyle: GPText.body(size: 14, color: gp.muted),
        filled: true,
        fillColor: gp.bg2,
        prefixIcon: Icon(Icons.search, size: 18, color: gp.muted),
        suffixIcon: _searchCtrl.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, size: 16, color: gp.muted),
                onPressed: () => setState(_searchCtrl.clear),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GPRadius.pill),
          borderSide: BorderSide(color: gp.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GPRadius.pill),
          borderSide: BorderSide(color: gp.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GPRadius.pill),
          borderSide: BorderSide(color: gp.accentInk, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    );
  }

  Widget _pills(AppLocalizations l, GpColors gp) {
    final options = [
      ('all', l.faqCategoryAll),
      ('general', l.faqCategoryGeneral),
      ('billing', l.faqCategoryBilling),
      ('checkin', l.faqCategoryCheckin),
      ('classes', l.faqCategoryClasses),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final o = options[i];
          final active = _filter == o.$1;
          return GestureDetector(
            onTap: () => setState(() => _filter = o.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? GP.lime22 : gp.bg2,
                borderRadius: BorderRadius.circular(GPRadius.pill),
                border: Border.all(
                  color: active
                      ? gp.accentInk.withValues(alpha: 0.55)
                      : gp.line,
                ),
              ),
              child: Center(
                child: Text(
                  o.$2.toUpperCase(),
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

  Widget _faqCard(_FaqEntry entry, int key, GpColors gp) {
    final open = _open.contains(key);
    return Container(
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GPRadius.lg),
          onTap: () => setState(() {
            if (open) {
              _open.remove(key);
            } else {
              _open.add(key);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.question,
                        style: GPText.body(
                            size: 14, color: gp.fg, weight: FontWeight.w600,),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.keyboard_arrow_down,
                          size: 22, color: gp.mutedSoft,),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      entry.answer,
                      style: GPText.body(
                          size: 13, color: gp.mutedSoft, height: 1.55,),
                    ),
                  ),
                  crossFadeState: open
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contactFooter(AppLocalizations l, GpColors gp) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.faqContactFooter,
              style: GPText.body(
                  size: 14, color: gp.fg, weight: FontWeight.w600,),),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(GPRadius.pill),
              onTap: () => context.push('/support'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: GP.lime22,
                  borderRadius: BorderRadius.circular(GPRadius.pill),
                  border:
                      Border.all(color: gp.accentInk.withValues(alpha: 0.55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.support_agent,
                        size: 16, color: gp.accentInk,),
                    const SizedBox(width: 8),
                    Text(
                      l.faqContactCta.toUpperCase(),
                      style: GPText.mono(
                        size: 11,
                        letterSpacing: 1.4,
                        color: gp.accentInk,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
