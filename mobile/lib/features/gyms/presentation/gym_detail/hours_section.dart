import 'package:flutter/material.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/opening_hours.dart';
import 'gym_detail_helpers.dart';

/// Opening-hours block: a live status line that expands into the full
/// per-day schedule. Always-open gyms render a single non-expandable
/// "Open 24/7" row (no point listing seven identical days).
class HoursSection extends StatefulWidget {
  const HoursSection({super.key, required this.hours, required this.status});

  final OpeningHours hours;
  final OpenStatus status;

  @override
  State<HoursSection> createState() => _HoursSectionState();
}

class _HoursSectionState extends State<HoursSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final l = AppLocalizations.of(context);
    final open = widget.status.isOpen || widget.status.always;
    final statusLine = openStatusLine(l, widget.status) ?? l.gymStatusClosed;
    final expandable = !widget.hours.is247;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(gp, l.gymHoursTitle),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.md),
            border: Border.all(color: gp.line2),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(GPRadius.md),
                onTap: expandable
                    ? () => setState(() => _expanded = !_expanded)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 18,
                        color: open ? gp.accentInk : gp.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusLine,
                          style: GPText.body(
                            size: 13,
                            color: gp.fg,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (expandable)
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: gp.muted,
                        ),
                    ],
                  ),
                ),
              ),
              if (expandable && _expanded) ...[
                Divider(height: 1, color: gp.line2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Column(
                    children: [
                      for (var d = 1; d <= 7; d++)
                        _dayRow(gp, l, d, widget.hours.windowFor(d)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _dayRow(GpColors gp, AppLocalizations l, int weekday, DayWindow w) {
    final isToday = DateTime.now().weekday == weekday;
    final value = w.closed
        ? l.gymHoursClosedDay
        // En-dash range, Western digits in both locales (Jordanian
        // convention this app follows everywhere).
        : '${w.open} – ${w.close}';
    final weight = isToday ? FontWeight.w700 : FontWeight.w400;
    final color = isToday ? gp.fg : gp.mutedSoft;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dayShortName(l, weekday),
            style: GPText.body(size: 12, color: color, weight: weight),
          ),
          Text(
            value,
            style: GPText.mono(
              size: 11,
              letterSpacing: 0.6,
              color: w.closed ? gp.muted : color,
            ),
          ),
        ],
      ),
    );
  }
}
