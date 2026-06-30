import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gp_scaffold.dart';
import '../../../core/widgets/help_button.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/top_bounce_physics.dart';
import '../../../core/widgets/wordmark_refresh.dart';
import '../../../l10n/app_localizations.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  Future<void> _onRefresh() async {
    // Help links are static today; once a backend status / outage banner
    // ships, refresh fetches it. WordmarkRefresh enforces a dwell so the
    // gesture is perceptible regardless.
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final entries = <(IconData, String, String, String, Color)>[
      (
        Icons.support_agent,
        l.helpContactSupport,
        l.helpContactSupportDesc,
        '/support',
        gp.accentInk,
      ),
      (
        Icons.help_outline,
        l.helpFaq,
        l.helpFaqDesc,
        '/faq',
        GP.warn,
      ),
      (
        Icons.bug_report_outlined,
        l.helpReportIssue,
        l.helpReportIssueDesc,
        '/report-issue',
        GP.danger,
      ),
    ];
    return GpScaffold(
      tips: [
        HelpTip(icon: Icons.support_agent, text: l.helpHelpHub1),
        HelpTip(icon: Icons.help_outline, text: l.helpHelpHub2),
        HelpTip(icon: Icons.bug_report_outlined, text: l.helpHelpHub3),
      ],
      body: Stack(
        children: [
          WordmarkRefresh(
            onRefresh: _onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: TopBouncePhysics(),
              ),
              padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 32),
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Overline(l.helpOverline)],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  DisplayText(l.helpHeadline, size: 34),
                  const SizedBox(width: 10),
                  SerifAccent(l.helpHeadlineAccent, size: 34),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l.helpBlurb,
                style: GPText.body(size: 14, color: gp.mutedSoft),
              ),
              const SizedBox(height: 24),
              // Pull-to-refresh skeleton — keeps the help page in
              // the same visual register as every other refreshable
              // surface in the app even though Help links are static
              // today (refresh becomes a real fetch once the planned
              // outage / status banner ships, at which point this
              // already does the right thing).
              Builder(
                builder: (innerCtx) {
                  if (RefreshScope.of(innerCtx)) {
                    return Column(
                      children: List.generate(
                        entries.length,
                        (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: SkeletonGymRow(),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _helpCard(
                            context,
                            gp,
                            icon: e.$1,
                            title: e.$2,
                            subtitle: e.$3,
                            accent: e.$5,
                            isRtl: isRtl,
                            onTap: () => context.push(e.$4),
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
            child: const BackBtn(fallback: '/profile'),
          ),
        ],
      ),
    );
  }

  Widget _helpCard(
    BuildContext context,
    GpColors gp, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required bool isRtl,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(color: gp.line),
            boxShadow: gp.cardShadows,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: accent.withValues(alpha: 0.16),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.42),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GPText.body(
                        size: 15,
                        color: gp.fg,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GPText.body(
                        size: 12.5,
                        color: gp.mutedSoft,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                size: 12,
                color: gp.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
