import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/prefs/app_preferences.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/gym_loader.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/biometric_settings_controller.dart';
import '../../auth/data/user_profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../security/data/security_state.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prefs = ref.watch(appPreferencesProvider);
    final prefsCtrl = ref.read(appPreferencesProvider.notifier);
    final gp = context.gp;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Scaffold(
      body: Stack(
        children: [
          // No pull-to-refresh on Settings — every value here is
          // local (locale, theme, notification toggles, app
          // version) and updates the instant the member taps. A
          // refresh gesture had nothing meaningful to fetch.
          ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Overline(l.settingsTitle)],
              ),
              const SizedBox(height: 22),
              DisplayText(l.settingsTitle, size: 36),
              const SizedBox(height: 28),
              _sectionLabel(context, l.settingsLanguage),
              _langSelector(prefs.locale.languageCode, prefsCtrl, l),
              const SizedBox(height: 20),
              _sectionLabel(context, l.settingsAppearance),
              _themeSelector(prefs.themeMode, prefsCtrl, l),
              const SizedBox(height: 20),
              _sectionLabel(context, l.settingsNotifications),
              _toggleCard(
                context,
                l.settingsNotifPlanReminders,
                prefs.notifPlanReminders,
                (v) => prefsCtrl.setNotifPlanReminders(v),
              ),
              const SizedBox(height: 8),
              _toggleCard(
                context,
                l.settingsNotifNewClubs,
                prefs.notifClubsNearby,
                (v) => prefsCtrl.setNotifClubsNearby(v),
              ),
              const SizedBox(height: 8),
              _toggleCard(
                context,
                l.settingsNotifPromos,
                prefs.notifPromos,
                (v) => prefsCtrl.setNotifPromos(v),
              ),
              const SizedBox(height: 20),
              _sectionLabel(context, l.settingsAccount),
              _accountList(context, l),
              const SizedBox(height: 30),
              Center(
                child: Text(l.settingsAppVersion,
                    style: GPText.mono(
                        size: 9, letterSpacing: 1.6, color: gp.muted,),),
              ),
              const SizedBox(height: 10),
            ],
          ),
          PositionedDirectional(
            top: topInset + 12,
            start: 20,
            child: const BackBtn(),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: GPText.mono(
                size: 10, letterSpacing: 1.8, color: context.gp.muted,),),
      );

  Widget _langSelector(
      String code, AppPreferencesNotifier ctrl, AppLocalizations l,) {
    final gp = context.gp;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.pill),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Row(
        children: [
          Expanded(
              child: _langBtn(context, code == 'ar', l.settingsLangArabic,
                  () => ctrl.setLocale(const Locale('ar')),),),
          Expanded(
              child: _langBtn(context, code == 'en', l.settingsLangEnglish,
                  () => ctrl.setLocale(const Locale('en')),),),
        ],
      ),
    );
  }

  Widget _langBtn(
      BuildContext context, bool sel, String label, VoidCallback onTap,) {
    final gp = context.gp;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: sel ? GP.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(GPRadius.pill),
        ),
        child: Center(
          child: Text(label,
              style: GPText.body(
                size: 13,
                color: sel ? GP.ink : gp.mutedSoft,
                weight: FontWeight.w600,
              ),),
        ),
      ),
    );
  }

  /// Two-state appearance picker — Light / Dark. The product chose
  /// to drop "follow system" because the in-app surfaces are tuned
  /// to one or the other; auto-flipping mid-session would surprise
  /// the member more than it would help. A member who pinned dark
  /// stays in dark until they explicitly toggle.
  Widget _themeSelector(
    ThemeMode mode,
    AppPreferencesNotifier ctrl,
    AppLocalizations l,
  ) {
    final gp = context.gp;
    // Anything other than `light` reads as dark — covers the case
    // where a previously-saved `system` preference is loaded from
    // storage; the picker shows the dark pill highlighted, and the
    // first tap on either option migrates the stored value.
    final isLight = mode == ThemeMode.light;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.pill),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Row(
        children: [
          Expanded(
            child: _langBtn(
              context,
              isLight,
              l.settingsThemeLight,
              () => ctrl.setThemeMode(ThemeMode.light),
            ),
          ),
          Expanded(
            child: _langBtn(
              context,
              !isLight,
              l.settingsThemeDark,
              () => ctrl.setThemeMode(ThemeMode.dark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleCard(BuildContext context, String label, bool value,
      ValueChanged<bool> onChanged,) {
    final gp = context.gp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.md),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: GPText.body(
                    size: 14, color: gp.fg, weight: FontWeight.w500,),),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: GP.ink,
            activeTrackColor: GP.lime,
            inactiveThumbColor: gp.muted,
            inactiveTrackColor: gp.bg3,
          ),
        ],
      ),
    );
  }

  Widget _accountList(BuildContext context, AppLocalizations l) {
    final gp = context.gp;
    final rows = <(IconData, String, VoidCallback, Color)>[
      (
        Icons.person_outline,
        l.settingsAccountEditProfile,
        () => _showEditProfileSheet(context, gp),
        gp.fg,
      ),
      (
        Icons.lock_outline,
        l.settingsAccountSecurity,
        () => _showSecuritySheet(context, l, gp),
        gp.fg,
      ),
      (
        Icons.description_outlined,
        l.settingsAccountTerms,
        () => _showTermsSheet(context, l, gp),
        gp.fg,
      ),
      (
        Icons.logout,
        l.settingsAccountLogout,
        () => _confirmLogout(context, l),
        GP.danger,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final data = e.value;
          final color = data.$4;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: data.$3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: e.key < rows.length - 1
                        ? BorderSide(color: gp.line)
                        : BorderSide.none,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(data.$1, size: 18, color: color),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        data.$2,
                        style: GPText.body(
                            size: 14, color: color, weight: FontWeight.w500,),
                      ),
                    ),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.arrow_back_ios
                          : Icons.arrow_forward_ios,
                      size: 12,
                      color: color.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _showEditProfileSheet(BuildContext context, GpColors gp) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: gp.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GPRadius.xl2)),
      ),
      builder: (_) => const _EditProfileSheet(),
    );
  }

  Future<void> _showSecuritySheet(
      BuildContext context, AppLocalizations l, GpColors gp,) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: gp.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GPRadius.xl2)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, sheetRef, _) {
          final biometric = sheetRef.watch(biometricSettingsProvider);
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
                  DisplayText(l.securityTitle, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    l.securityBlurb,
                    style: GPText.body(size: 13, color: gp.mutedSoft),
                  ),
                  const SizedBox(height: 18),
                  _securityTile(
                    context,
                    gp,
                    icon: Icons.phone_android,
                    title: l.securityChangePhone,
                    subtitle: l.securityChangePhoneDesc,
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _showChangePhoneSheet(context, l, gp);
                    },
                  ),
                  const SizedBox(height: 10),
                  _securityTile(
                    context,
                    gp,
                    icon: Icons.fingerprint,
                    title: l.securityBiometricTitle,
                    subtitle: !biometric.available
                        ? l.securityBiometricUnavailable
                        : !biometric.hasPassword
                            ? l.securityBiometricNoPassword
                            : l.securityBiometricDesc,
                    trailing: Switch(
                      value: biometric.enabled,
                      // Disabled when the device can't biometric or when
                      // the member never set a password (Google-only or
                      // OTP-only path) — there'd be nothing to vault.
                      onChanged: (biometric.available && biometric.hasPassword)
                          ? (v) async {
                              if (v) {
                                final ok = await _enableBiometric(
                                    context, sheetRef, l,);
                                if (!context.mounted) return;
                                if (ok) {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(SnackBar(
                                      content: Text(l.biometricEnabled),
                                    ),);
                                }
                              } else {
                                await sheetRef
                                    .read(biometricSettingsProvider.notifier)
                                    .disable();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(SnackBar(
                                    content: Text(l.biometricDisabled),
                                  ),);
                              }
                            }
                          : null,
                      activeThumbColor: GP.ink,
                      activeTrackColor: GP.lime,
                      inactiveThumbColor: gp.muted,
                      inactiveTrackColor: gp.bg3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _securityTile(
                    context,
                    gp,
                    icon: Icons.devices_other,
                    title: l.securitySessions,
                    subtitle: l.securitySessionsDesc,
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _showSessionsSheet(context, l, gp);
                    },
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _securityTile(
    BuildContext context,
    GpColors gp, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: gp.bg3,
            borderRadius: BorderRadius.circular(GPRadius.md),
            border: Border.all(color: gp.line),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: gp.accentInk.withValues(alpha: 0.15),
                  border: Border.all(
                    color: gp.accentInk.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: gp.accentInk),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GPText.body(
                        size: 14,
                        color: gp.fg,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GPText.body(size: 12, color: gp.mutedSoft),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_back_ios
                      : Icons.arrow_forward_ios,
                  size: 12,
                  color: gp.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Walks the user through arming biometric sign-in. Returns true on a
  /// successful enrolment so the caller can show the "biometric on" snack.
  ///
  /// The flow has two prompts on purpose: the password sheet proves
  /// proof-of-knowledge (so a thief who picks up an unlocked phone can't
  /// quietly arm biometric and lock the real owner out), and the OS
  /// biometric prompt that follows proves the sensor pairs with the same
  /// person who just typed the password.
  Future<bool> _enableBiometric(
    BuildContext context,
    WidgetRef sheetRef,
    AppLocalizations l,
  ) async {
    final password = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.gp.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GPRadius.xl2)),
      ),
      builder: (_) => const _BiometricEnrollSheet(),
    );
    if (password == null || password.isEmpty) return false;
    final result = await sheetRef
        .read(biometricSettingsProvider.notifier)
        .enable(
          password: password,
          localizedReason: l.biometricEnrollReason,
        );
    if (!context.mounted) return false;
    switch (result) {
      case BiometricToggleResult.ok:
        return true;
      case BiometricToggleResult.passwordWrong:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.errorPasswordInvalid)));
      case BiometricToggleResult.biometricCancelled:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.biometricCancelled)));
      case BiometricToggleResult.biometricUnavailable:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              SnackBar(content: Text(l.securityBiometricUnavailable)),);
      case BiometricToggleResult.network:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.errorNetwork)));
    }
    return false;
  }

  Future<void> _showChangePhoneSheet(
      BuildContext context, AppLocalizations l, GpColors gp,) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: gp.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GPRadius.xl2)),
      ),
      builder: (_) => const _ChangePhoneSheet(),
    );
  }

  Future<void> _showSessionsSheet(
      BuildContext context, AppLocalizations l, GpColors gp,) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: gp.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GPRadius.xl2)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, sheetRef, _) {
          final security = sheetRef.watch(securityProvider);
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, controller) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: Column(
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
                    DisplayText(l.securitySessionsTitle, size: 22),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        controller: controller,
                        itemCount: security.sessions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final s = security.sessions[i];
                          return _sessionTile(
                              context, sheetRef, l, gp, s,);
                        },
                      ),
                    ),
                    if (security.sessions.any((s) => !s.isCurrent)) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => sheetRef
                              .read(securityProvider.notifier)
                              .revokeAllOthers(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: GP.danger),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(GPRadius.pill),
                            ),
                          ),
                          child: Text(
                            l.securitySessionsRevokeAll.toUpperCase(),
                            style: GPText.mono(
                              size: 11,
                              letterSpacing: 1.4,
                              color: GP.danger,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sessionTile(
    BuildContext context,
    WidgetRef sheetRef,
    AppLocalizations l,
    GpColors gp,
    ActiveSession session,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: gp.bg3,
        borderRadius: BorderRadius.circular(GPRadius.md),
        border: Border.all(
          color: session.isCurrent
              ? gp.accentInk.withValues(alpha: 0.55)
              : gp.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.devices_other,
            size: 20,
            color: session.isCurrent ? gp.accentInk : gp.fg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.device,
                  style: GPText.body(
                    size: 14,
                    color: gp.fg,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.isCurrent
                      ? '${session.location} · ${l.securitySessionsActive}'
                      : '${session.location} · ${l.securitySessionsLastActive(session.lastActiveIso)}',
                  style: GPText.body(size: 12, color: gp.mutedSoft),
                ),
              ],
            ),
          ),
          if (session.isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: GP.lime22,
                borderRadius: BorderRadius.circular(GPRadius.pill),
                border: Border.all(
                  color: gp.accentInk.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                l.securitySessionsThisDevice.toUpperCase(),
                style: GPText.mono(
                  size: 9,
                  letterSpacing: 1.4,
                  color: gp.accentInk,
                  weight: FontWeight.w600,
                ),
              ),
            )
          else
            TextButton(
              onPressed: () async {
                await sheetRef
                    .read(securityProvider.notifier)
                    .revokeSession(session.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(l.securitySessionsRevoked),
                  ),);
              },
              child: Text(
                l.securitySessionsRevoke.toUpperCase(),
                style: GPText.mono(
                  size: 10,
                  letterSpacing: 1.3,
                  color: GP.danger,
                  weight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showTermsSheet(
      BuildContext context, AppLocalizations l, GpColors gp,) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: gp.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GPRadius.xl2)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
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
                DisplayText(l.termsTitle, size: 24),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Text(
                      l.termsBody,
                      style: GPText.body(size: 14, color: gp.mutedSoft),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AppLocalizations l) async {
    final gp = context.gp;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: gp.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GPRadius.lg),
        ),
        title: Text(l.logoutConfirmTitle,
            style: GPText.body(
                size: 18, color: gp.fg, weight: FontWeight.w600,),),
        content: Text(l.logoutConfirmBody,
            style: GPText.body(size: 14, color: gp.mutedSoft),),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel.toUpperCase(),
                style: GPText.mono(
                    size: 11,
                    letterSpacing: 1.4,
                    color: gp.fg,
                    weight: FontWeight.w600,),),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: GP.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GPRadius.pill),
              ),
            ),
            child: Text(l.logoutConfirmYes.toUpperCase(),
                style: GPText.mono(
                    size: 11,
                    letterSpacing: 1.4,
                    color: Colors.white,
                    weight: FontWeight.w700,),),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    this.context.go('/sign-in');
  }
}

/// Edit-profile bottom sheet.
///
/// Owns its `TextEditingController`s in `initState`/`dispose` so their
/// lifetimes match the widget's — the previous function-scoped controllers
/// disposed out of sequence with the Element tree and tripped the
/// `_dependents.isEmpty` assertion on Save.
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  Gender? _gender;
  bool _showGenderError = false;
  bool _saving = false;

  /// Inline error message shown above the form. Populated when the
  /// save fails — snackbars don't work here because the bottom
  /// sheet covers the bottom edge of the Scaffold where they'd
  /// render, so the member would see no feedback.
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _firstNameCtrl = TextEditingController(text: profile.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: profile.lastName ?? '');
    _emailCtrl = TextEditingController(text: profile.email ?? '');
    _gender = profile.gender;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_saving) return;
    HapticFeedback.selectionClick();
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
      setState(() => _error = l.errorRequiredFields);
      return;
    }
    if (_gender == null) {
      setState(() {
        _showGenderError = true;
        _error = l.errorGenderRequired;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileProvider.notifier).updateIdentity(
            firstName: firstName,
            lastName: lastName,
            email: email,
            gender: _gender,
          );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final pretty = raw.contains('AUTH_INVALID_CREDENTIALS')
          ? l.errorPasswordInvalid
          : raw.contains('VALIDATION_ERROR') || raw.contains('Email already')
              ? l.errorInvalidInput
              : raw.contains('SocketException') ||
                      raw.contains('connectionError') ||
                      raw.contains('Failed host lookup')
                  ? l.errorNetwork
                  : '${l.snackErrorGeneric} ($raw)';
      setState(() {
        _saving = false;
        // Inline error inside the sheet — snackbars don't work
        // here because the modal sheet covers the bottom of the
        // Scaffold where they'd render.
        _error = pretty;
      });
      return;
    }
    if (!mounted) return;
    // Pop FIRST so the sheet is gone by the time the snackbar shows
    // — otherwise the snack would render under the sheet and the
    // member wouldn't see the success.
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.editProfileSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
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
              DisplayText(l.editProfileTitle, size: 24),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.editProfileFirstName.toUpperCase(),
                            style: GPText.mono(
                                size: 10, letterSpacing: 1.5, color: gp.mutedSoft,),),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _firstNameCtrl,
                          style: GPText.body(size: 14, color: gp.fg),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.editProfileLastName.toUpperCase(),
                            style: GPText.mono(
                                size: 10, letterSpacing: 1.5, color: gp.mutedSoft,),),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _lastNameCtrl,
                          style: GPText.body(size: 14, color: gp.fg),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(l.editProfileEmail.toUpperCase(),
                  style: GPText.mono(
                      size: 10, letterSpacing: 1.5, color: gp.mutedSoft,),),
              const SizedBox(height: 6),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GPText.body(size: 14, color: gp.fg),
              ),
              const SizedBox(height: 14),
              Text(l.labelGender,
                  style: GPText.mono(
                      size: 10, letterSpacing: 1.5, color: gp.mutedSoft,),),
              const SizedBox(height: 6),
              _GenderToggle(
                value: _gender,
                maleLabel: l.genderMale,
                femaleLabel: l.genderFemale,
                onChanged: (g) => setState(() {
                  _gender = g;
                  _showGenderError = false;
                }),
              ),
              if (_showGenderError && _gender == null) ...[
                const SizedBox(height: 6),
                Text(l.errorGenderRequired,
                    style: GPText.body(size: 12, color: GP.danger),),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GP.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(GPRadius.md),
                    border:
                        Border.all(color: GP.danger.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 16, color: GP.danger,),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GPText.body(size: 12, color: gp.fg),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: GP.lime,
                    foregroundColor: GP.ink,
                    disabledBackgroundColor: GP.lime.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GPRadius.pill),
                    ),
                  ),
                  child: _saving
                      ? const GymLoader(size: GymLoaderSize.small)
                      : Text(
                          l.editProfileSave.toUpperCase(),
                          style: GPText.mono(
                            size: 11,
                            letterSpacing: 1.4,
                            color: GP.ink,
                            weight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// Change-phone bottom sheet.
///
/// Owns its `TextEditingController` in `initState`/`dispose` for the same
/// reason `_EditProfileSheet` does: a function-scoped controller can outlive
/// — or be torn down before — the keyboard-hide animation, tripping the
/// `_dependents.isEmpty` assertion and the "wrong build scope" crash that
/// surfaced when changing the phone number.
class _ChangePhoneSheet extends ConsumerStatefulWidget {
  const _ChangePhoneSheet();

  @override
  ConsumerState<_ChangePhoneSheet> createState() => _ChangePhoneSheetState();
}

enum _ChangePhoneStep { enterPhone, enterOtp }

class _ChangePhoneSheetState extends ConsumerState<_ChangePhoneSheet> {
  late final TextEditingController _phoneCtrl;
  late final List<TextEditingController> _otpCells;
  late final List<FocusNode> _otpNodes;

  _ChangePhoneStep _step = _ChangePhoneStep.enterPhone;
  bool _busy = false;
  String _pendingPhone = '';
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController();
    _otpCells = List.generate(4, (_) => TextEditingController());
    _otpNodes = List.generate(4, (_) => FocusNode());
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtrl.dispose();
    for (final c in _otpCells) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _otpCells.map((c) => c.text).join();

  void _startResendCountdown() {
    _resendTimer?.cancel();
    _resendSeconds = 28;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _onSendCode() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final digits = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    // Backend regex: ^\+962(7[789])\d{7}$ — 9 digits starting with 77/78/79.
    final valid = digits.length == 9 &&
        digits.startsWith('7') &&
        ['77', '78', '79'].contains(digits.substring(0, 2));
    if (!valid) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.securityChangePhoneInvalid)));
      return;
    }
    final fullPhone = '+962$digits';
    setState(() => _busy = true);
    try {
      await ref
          .read(profileProvider.notifier)
          .requestPhoneChangeOtp(fullPhone);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_friendlyError(l, e))));
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = _ChangePhoneStep.enterOtp;
      _pendingPhone = fullPhone;
    });
    _startResendCountdown();
    if (_otpNodes.isNotEmpty) _otpNodes[0].requestFocus();
  }

  Future<void> _onResend() async {
    if (_busy || _resendSeconds > 0) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileProvider.notifier)
          .requestPhoneChangeOtp(_pendingPhone);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_friendlyError(AppLocalizations.of(context), e)),
          ),
        );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _startResendCountdown();
  }

  Future<void> _onVerify() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final code = _otpCode;
    if (code.length != 4) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileProvider.notifier).verifyPhoneChange(
            newPhone: _pendingPhone,
            code: code,
          );
    } catch (e) {
      if (!mounted) return;
      // Clear cells so the user retries instead of resubmitting the bad code.
      for (final c in _otpCells) {
        c.clear();
      }
      setState(() => _busy = false);
      _otpNodes.first.requestFocus();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_friendlyError(l, e))));
      return;
    }
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l.securityChangePhoneUpdated(_pendingPhone))),
      );
  }

  String _friendlyError(AppLocalizations l, Object e) {
    final msg = e.toString();
    if (msg.contains('AUTH_OTP_INVALID') ||
        msg.contains('AUTH_OTP_EXPIRED') ||
        msg.contains('AUTH_OTP_LOCKED')) {
      return l.securityChangePhoneOtpError;
    }
    if (msg.toLowerCase().contains('phone already in use')) {
      return l.securityChangePhoneInUse;
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
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
              if (_step == _ChangePhoneStep.enterPhone)
                _buildPhoneStep(gp)
              else
                _buildOtpStep(gp),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep(GpColors gp) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DisplayText(l.securityChangePhoneTitle, size: 22),
        const SizedBox(height: 12),
        Text(
          l.securityChangePhoneOtpNote,
          style: GPText.body(size: 13, color: gp.mutedSoft),
        ),
        const SizedBox(height: 18),
        Text(
          l.securityChangePhoneNewLabel.toUpperCase(),
          style: GPText.mono(
            size: 10,
            letterSpacing: 1.5,
            color: gp.mutedSoft,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          cursorColor: gp.accentInk,
          style: GPText.body(
            size: 15,
            color: gp.fg,
            weight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: l.phoneHint,
            hintStyle: GPText.body(size: 14, color: gp.muted),
            prefixText: '${l.phoneCountryPrefix} ',
            prefixStyle: GPText.body(
              size: 15,
              color: gp.fg,
              weight: FontWeight.w500,
            ),
            filled: true,
            fillColor: gp.bg3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GPRadius.lg),
              borderSide: BorderSide(color: gp.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GPRadius.lg),
              borderSide: BorderSide(color: gp.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GPRadius.lg),
              borderSide: BorderSide(color: gp.accentInk, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _primaryButton(
          label: l.securityChangePhoneSubmit,
          onPressed: _busy ? null : _onSendCode,
        ),
      ],
    );
  }

  Widget _buildOtpStep(GpColors gp) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DisplayText(l.securityChangePhoneOtpTitle, size: 22),
        const SizedBox(height: 12),
        Text(
          l.securityChangePhoneOtpSubtitle(_pendingPhone),
          style: GPText.body(size: 13, color: gp.mutedSoft),
        ),
        const SizedBox(height: 18),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) => _otpCell(i, gp)),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              _resendSeconds > 0
                  ? l.otpResendIn(_resendSeconds)
                  : l.otpResendNow,
              style: GPText.mono(
                size: 11,
                letterSpacing: 1.5,
                color: _resendSeconds > 0 ? gp.accentInk : gp.mutedSoft,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: (_resendSeconds == 0 && !_busy) ? _onResend : null,
              child: Text(
                l.otpResendBtn,
                style: GPText.mono(
                  size: 11,
                  letterSpacing: 1.5,
                  color: (_resendSeconds == 0 && !_busy) ? gp.fg : gp.muted,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _primaryButton(
          label: l.securityChangePhoneVerifyBtn,
          onPressed: (_busy || _otpCode.length < 4) ? null : _onVerify,
        ),
      ],
    );
  }

  Widget _otpCell(int i, GpColors gp) {
    final filled = _otpCells[i].text.isNotEmpty;
    final focused = _otpNodes[i].hasFocus;
    return SizedBox(
      width: 56,
      height: 64,
      child: Container(
        decoration: BoxDecoration(
          color: gp.bg3,
          borderRadius: BorderRadius.circular(GPRadius.lg),
          border: Border.all(
            color: focused || filled ? gp.accentInk : gp.line,
            width: focused || filled ? 1.6 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: _otpCells[i],
          focusNode: _otpNodes[i],
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          textAlign: TextAlign.center,
          cursorColor: gp.accentInk,
          style: GPText.body(size: 22, color: gp.fg, weight: FontWeight.w600),
          decoration: const InputDecoration(
            counterText: '',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (v) {
            setState(() {});
            if (v.isNotEmpty && i < 3) {
              _otpNodes[i + 1].requestFocus();
            } else if (v.isEmpty && i > 0) {
              _otpNodes[i - 1].requestFocus();
            }
            if (_otpCode.length == 4) _onVerify();
          },
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: GP.lime,
          foregroundColor: GP.ink,
          disabledBackgroundColor: GP.lime.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GPRadius.pill),
          ),
        ),
        child: _busy
            ? const GymLoader(size: GymLoaderSize.small)
            : Text(
                label.toUpperCase(),
                style: GPText.mono(
                  size: 11,
                  letterSpacing: 1.4,
                  color: GP.ink,
                  weight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _GenderToggle extends StatelessWidget {
  const _GenderToggle({
    required this.value,
    required this.maleLabel,
    required this.femaleLabel,
    required this.onChanged,
  });

  final Gender? value;
  final String maleLabel;
  final String femaleLabel;
  final ValueChanged<Gender> onChanged;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: gp.bg3,
        borderRadius: BorderRadius.circular(GPRadius.pill),
        border: Border.all(color: gp.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _chip(
              context,
              label: maleLabel,
              selected: value == Gender.male,
              onTap: () => onChanged(Gender.male),
            ),
          ),
          Expanded(
            child: _chip(
              context,
              label: femaleLabel,
              selected: value == Gender.female,
              onTap: () => onChanged(Gender.female),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final gp = context.gp;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? GP.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(GPRadius.pill),
        ),
        child: Center(
          child: Text(
            label,
            style: GPText.body(
              size: 13,
              color: selected ? GP.ink : gp.mutedSoft,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet that captures the user's password before arming the
/// biometric vault. Returns the typed password to the caller via
/// [Navigator.pop] — verification (and the biometric prompt) happens in
/// [BiometricSettingsController.enable], not here. Keeps the sheet
/// presentation-only.
class _BiometricEnrollSheet extends StatefulWidget {
  const _BiometricEnrollSheet();

  @override
  State<_BiometricEnrollSheet> createState() => _BiometricEnrollSheetState();
}

class _BiometricEnrollSheetState extends State<_BiometricEnrollSheet> {
  final _passwordCtrl = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          18,
          22,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
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
            DisplayText(l.biometricEnrollTitle, size: 22),
            const SizedBox(height: 8),
            Text(
              l.biometricEnrollBlurb(l.biometricGenericLabel),
              style: GPText.body(size: 13, color: gp.mutedSoft),
            ),
            const SizedBox(height: 18),
            Text(
              l.biometricEnrollPasswordLabel,
              style:
                  GPText.mono(size: 10, letterSpacing: 1.8, color: gp.muted),
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _passwordCtrl,
                obscureText: !_visible,
                autofocus: true,
                style: GPText.body(size: 14, color: gp.fg),
                cursorColor: gp.accentInk,
                onSubmitted: (v) {
                  if (v.isNotEmpty) Navigator.of(context).pop(v);
                },
                decoration: InputDecoration(
                  hintText: l.biometricEnrollPasswordHint,
                  hintStyle: GPText.body(size: 14, color: gp.muted),
                  filled: true,
                  fillColor: gp.bg3,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _visible = !_visible),
                    icon: Icon(
                      _visible ? Icons.visibility_off : Icons.visibility,
                      color: gp.muted,
                      size: 20,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GPRadius.lg),
                    borderSide: BorderSide(color: gp.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GPRadius.lg),
                    borderSide: BorderSide(color: gp.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GPRadius.lg),
                    borderSide: BorderSide(color: gp.accentInk, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 16,),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final pwd = _passwordCtrl.text;
                  if (pwd.isEmpty) return;
                  Navigator.of(context).pop(pwd);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: GP.lime,
                  foregroundColor: GP.ink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GPRadius.pill),
                  ),
                ),
                child: Text(
                  l.biometricEnrollSubmit.toUpperCase(),
                  style: GPText.mono(
                    size: 11,
                    letterSpacing: 1.4,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
