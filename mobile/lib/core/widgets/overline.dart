import 'package:flutter/material.dart';

import '../theme/gp_text.dart';
import '../theme/gp_tokens.dart';

class Overline extends StatelessWidget {
  final String text;
  final Color? color;
  final bool bullet;
  final Color? bulletColor;

  const Overline(
    this.text, {
    super.key,
    this.color,
    this.bullet = true,
    this.bulletColor,
  });

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final resolved = color ?? gp.muted;
    final bullet = bulletColor ?? gp.accentInk;
    // Arabic is a connected script — letter-spacing visually breaks the
    // joins between letters and makes overlines look fractured. We also
    // skip toUpperCase since Arabic has no case mapping. AR overlines get
    // a small size bump to compensate for losing the tracked-out emphasis.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final label = isRtl ? text : text.toUpperCase();
    final style = isRtl
        ? GPText.overline.copyWith(
            color: resolved,
            letterSpacing: 0,
            fontSize: 12,
          )
        : GPText.overline.copyWith(color: resolved);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (this.bullet) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: bullet,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bullet.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(label, style: style),
      ],
    );
  }
}

class DisplayText extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final double? height;
  final TextAlign align;

  const DisplayText(
    this.text, {
    super.key,
    this.size = 42,
    this.color,
    this.height,
    this.align = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    // AR path stays upright (slnt 0) so ligatures stay intact;
    // EN path uses the slanted display weight.
    final lang = Localizations.localeOf(context).languageCode;
    final isAr = lang == 'ar';
    final display = isAr
        ? GPText.displayArabic(size, color: color ?? context.gp.fg)
        : GPText.display(size, color: color ?? context.gp.fg, height: height ?? 0.92);
    return Text(
      isAr ? text : text.toUpperCase(),
      textAlign: align,
      style: display,
    );
  }
}

class SerifAccent extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;

  const SerifAccent(
    this.text, {
    super.key,
    this.size = 42,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GPText.serifAccent(size, color: color ?? context.gp.accentInk),
    );
  }
}
