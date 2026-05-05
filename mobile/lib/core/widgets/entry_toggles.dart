import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_preferences.dart';
import '../theme/gp_text.dart';
import '../theme/gp_tokens.dart';

/// Top-right toggles on the auth / entry screens. A theme cycle on
/// the left, a locale toggle on the right — both circular pills so
/// they read as one chrome group. Theme lives here (not just in
/// settings) because the auth screens are pre-login: the member
/// hasn't reached settings yet, but should still be able to flip
/// to light mode if they prefer it.
class EntryTopToggles extends ConsumerWidget {
  const EntryTopToggles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);
    final current = prefs.locale.languageCode;
    final nextLocale =
        current == 'ar' ? const Locale('en') : const Locale('ar');
    // Binary theme toggle: read the effective brightness from the
    // active theme and flip to the opposite. Same convention as the
    // locale pill — the icon shows the target the member will
    // switch *to*. Only Light and Dark exist as user-selectable
    // modes; auto-following the OS was dropped.
    final isDarkNow = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThemeToggleButton(
          isDarkNow: isDarkNow,
          onToggle: () => notifier.setThemeMode(
            isDarkNow ? ThemeMode.light : ThemeMode.dark,
          ),
        ),
        const SizedBox(width: 8),
        _CircleLabel(
          label: nextLocale.languageCode.toUpperCase(),
          onPressed: () => notifier.setLocale(nextLocale),
        ),
      ],
    );
  }
}

/// Circular icon button that shows the **target** theme — sun when
/// the app is currently dark (tap → light), moon when currently
/// light (tap → dark). Mirrors the locale pill's "show what you'll
/// get if you tap" convention.
class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({required this.isDarkNow, required this.onToggle});

  final bool isDarkNow;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    final icon = isDarkNow
        ? Icons.light_mode_outlined
        : Icons.dark_mode_outlined;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.pill),
        onTap: onToggle,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: gp.bg3,
            shape: BoxShape.circle,
            border: Border.all(color: gp.line2),
          ),
          child: Icon(icon, size: 18, color: gp.fg),
        ),
      ),
    );
  }
}

class _CircleLabel extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _CircleLabel({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.pill),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: gp.bg3,
            shape: BoxShape.circle,
            border: Border.all(color: gp.line2),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GPText.mono(
              size: 11,
              letterSpacing: 1.2,
              color: gp.fg,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
