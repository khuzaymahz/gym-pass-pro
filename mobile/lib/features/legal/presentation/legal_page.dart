import 'package:flutter/material.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';

/// Single-page reader for legal documents (terms, privacy, etc.).
///
/// Content is passed in as a list of `LegalSection`s — one per
/// numbered article in the document. Each section renders as
/// `(number, headline, body)` with reading-rhythm spacing. Body
/// strings honour `\n` newlines so the i18n entry can group
/// bullet-like clauses without dragging in a markdown parser.
///
/// **IMPORTANT**: the content delivered with these pages today is
/// structural placeholder. Before the app reaches production, the
/// strings under `terms_*` and `privacy_*` in the ARB files MUST be
/// reviewed by legal counsel. The clauses describe real GymPass
/// data flows accurately (PII masking, audit log retention, the
/// partner-portal masking boundary added in commit 7294812), so
/// the lawyer's job is wording + jurisdiction adaptation, not
/// fact-gathering.
class LegalPage extends StatelessWidget {
  const LegalPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.lastUpdatedLabel,
    required this.lastUpdated,
    required this.sections,
  });

  final String title;
  final String subtitle;
  final String lastUpdatedLabel;
  final String lastUpdated;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Scaffold(
      backgroundColor: gp.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: Row(
                  children: [
                    const BackBtn(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Overline(subtitle),
                    const SizedBox(height: 8),
                    Text(
                      title.toUpperCase(),
                      style: GPText.display(34, color: gp.fg, height: 0.9),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$lastUpdatedLabel · $lastUpdated',
                      style: GPText.mono(
                        size: 10.5,
                        letterSpacing: 1.4,
                        color: gp.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 48),
              sliver: SliverList.builder(
                itemCount: sections.length,
                itemBuilder: (_, i) => _SectionView(
                  index: i + 1,
                  section: sections[i],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LegalSection {
  const LegalSection({required this.headline, required this.body});
  final String headline;
  final String body;
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.index, required this.section});
  final int index;
  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                index.toString().padLeft(2, '0'),
                style: GPText.mono(
                  size: 11,
                  letterSpacing: 1.4,
                  color: gp.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.headline,
                  style: GPText.body(
                    size: 16,
                    weight: FontWeight.w700,
                    color: gp.fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: GPText.body(size: 13.5, color: gp.mutedSoft, height: 1.55),
          ),
        ],
      ),
    );
  }
}
