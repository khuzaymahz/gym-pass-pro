import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/network_error.dart';
import '../../../core/prefs/app_preferences.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/entry_toggles.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/jordan_flag.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/wordmark.dart';
import '../../../l10n/app_localizations.dart';
import '../data/biometric_vault.dart';
import 'auth_controller.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;
  bool _passwordSubmitAttempted = false;
  // True while `_submit` is awaiting its first network call. Hard guard
  // against a determined double-tap before the controller flips its
  // own `loading` flag — prevents a duplicate OTP request fanning out.
  bool _submitting = false;

  /// Resolved on first frame: true when the device can biometric AND the
  /// user has saved creds in the vault. Drives the biometric pill's
  /// visibility — we don't show a button that would only ever fail.
  bool _biometricReady = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_onPhoneChanged);
    _checkBiometricReady();
  }

  Future<void> _checkBiometricReady() async {
    final vault = ref.read(biometricVaultProvider);
    final available = await vault.canUseBiometrics();
    final enabled = await vault.isEnabled();
    if (!mounted) return;
    setState(() => _biometricReady = available && enabled);
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_onPhoneChanged);
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Strip spaces and a leading 0 if the user typed 07...
  String _normalized() {
    final raw = _phoneCtrl.text.replaceAll(RegExp(r'\s+'), '').trim();
    return raw.startsWith('0') ? raw.substring(1) : raw;
  }

  /// Jordanian mobile: starts with 7, then 8 more digits (9 total).
  bool _isValid() => RegExp(r'^7\d{8}$').hasMatch(_normalized());

  /// Runs on every keystroke. Handles two jobs:
  ///  1. If the phone is no longer valid (or the user typed a different number
  ///     from the last checked one), clear any lingering password prompt so we
  ///     don't leave a password box pinned to a stale number.
  ///  2. As soon as the phone becomes a complete valid Jordanian mobile, kick
  ///     off the directory check automatically. This replaces the old manual
  ///     "Continue" press — returning members see the password field appear
  ///     inline, new members are routed straight to the OTP step.
  void _onPhoneChanged() {
    setState(() => _passwordSubmitAttempted = false);
    final controller = ref.read(authControllerProvider.notifier);
    final state = ref.read(authControllerProvider);
    final valid = _isValid();
    final nextPhone = valid ? '+962${_normalized()}' : '';

    if (!valid) {
      if (state.phone.isNotEmpty ||
          state.requiresPassword ||
          state.error != null) {
        controller.resetPhoneCheck();
      }
      return;
    }

    if (nextPhone == state.phone || state.loading) return;
    // Phone differs from the last check — clear prior gate, then re-check.
    if (state.requiresPassword || state.error != null) {
      controller.resetPhoneCheck();
    }
    controller.checkPhone(nextPhone);
  }

  String? _validatePhone(String? v, AppLocalizations l) {
    final raw = (v ?? '').replaceAll(RegExp(r'\s+'), '').trim();
    if (raw.isEmpty) return l.errorPhoneRequired;
    final norm = raw.startsWith('0') ? raw.substring(1) : raw;
    if (!RegExp(r'^7\d{8}$').hasMatch(norm)) return l.errorPhoneInvalid;
    return null;
  }

  Future<void> _submit(AuthState state) async {
    // In-flight guard. The Continue button's loading state catches the
    // first tap by setting `loading=true`, but the controller flips
    // that state AFTER the first awaited call returns — a determined
    // double-tap (or a flaky tap-tap from a slow render) fires the
    // second `_submit` while the first await is still in flight. Both
    // would race through `checkPhone` → `requestOtp` and fire TWO OTP
    // SMS for the same phone. The local `_submitting` flag closes the
    // window deterministically without depending on the controller's
    // state update cadence.
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      FocusScope.of(context).unfocus();
      final phone = '+962${_normalized()}';
      final controller = ref.read(authControllerProvider.notifier);
      if (state.requiresPassword) {
        setState(() => _passwordSubmitAttempted = true);
        if (_passwordCtrl.text.isEmpty) return;
        controller.signInWithPassword(_passwordCtrl.text);
        return;
      }
      // Authoritative re-check on explicit intent. The auto-check might
      // have been skipped (e.g. paste event that arrived while another
      // check was loading, or a race where the controller bootstrap
      // wasn't ready yet) so we look up the phone one more time here.
      // If a registered account exists, we surface the password gate
      // instead of shotgunning an OTP.
      await controller.checkPhone(phone);
      if (!mounted) return;
      final refreshed = ref.read(authControllerProvider);
      if (refreshed.requiresPassword) {
        // Password gate revealed itself — let the user see the new
        // field and type their password instead of auto-submitting
        // stale input.
        return;
      }
      controller.requestOtp(phone);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _onBiometric() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    final vault = ref.read(biometricVaultProvider);
    final result = await vault.authenticate(
      localizedReason: l.biometricUnlockReason,
    );
    if (!mounted) return;
    switch (result) {
      case BiometricResult.unavailable:
        // Hardware/enrolment vanished between init and tap — hide the
        // button next time so it's not a dead end.
        setState(() => _biometricReady = false);
        return;
      case BiometricResult.cancelled:
        return;
      case BiometricResult.ok:
        break;
    }
    final ok =
        await ref.read(authControllerProvider.notifier).signInWithBiometric();
    if (!mounted) return;
    if (!ok) {
      // Saved credential rejected (likely a server-side password change).
      // Vault was already cleared by the controller; refresh local visibility.
      setState(() => _biometricReady = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.errorPasswordInvalid)));
    }
  }

  void _onForgotPassword() {
    // The user has to have a valid phone in the field for this to be useful —
    // the wizard identifies the account by phone. Guard up front so we never
    // land on the reset page with an empty context.
    if (!_isValid()) {
      _formKey.currentState?.validate();
      return;
    }
    final phone = '+962${_normalized()}';
    context.push('/forgot-password?phone=${Uri.encodeQueryComponent(phone)}');
  }

  /// Translates the raw error surfaced by the auth controller (which in turn
  /// comes from the backend as an ApiException string or a network-level
  /// DioException) into a friendly, localized message. Unknown codes fall
  /// back to the generic l10n snack so we never leak raw
  /// "DioException [unknown]: null" noise at users.
  String? _resolveError(AuthState state, AppLocalizations l) {
    final raw = state.error;
    if (raw == null) return null;
    // Specific server-issued codes first. The backend returns a
    // single `AUTH_INVALID_CREDENTIALS` for both "phone unknown" and
    // "wrong password" — we surface it as the password-invalid copy
    // because that's the actionable variant on this screen (the
    // phone field has its own format check upstream).
    if (raw.contains('AUTH_INVALID_CREDENTIALS') ||
        raw.contains('AUTH_PASSWORD_INVALID')) {
      return l.errorPasswordInvalid;
    }
    if (raw.contains('AUTH_OTP_LOCKED')) return l.errorOtpLocked;
    return resolveErrorMessageString(raw, l);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final l = AppLocalizations.of(context);
    final errorMessage = _resolveError(state, l);
    final submitting = state.loading;
    final canSubmit = state.requiresPassword
        ? _isValid() && _passwordCtrl.text.isNotEmpty
        : _isValid();

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (prev?.phase != AuthPhase.awaitingCode &&
          next.phase == AuthPhase.awaitingCode) {
        context.push('/otp');
      }
      if (prev?.phase != AuthPhase.authed && next.phase == AuthPhase.authed) {
        context.go('/home');
      }
      // Password gate just closed (user edited the phone or reset manually):
      // clear the password field so stale input can't survive into the next
      // gate for a different number.
      if ((prev?.requiresPassword ?? false) && !next.requiresPassword) {
        _passwordCtrl.clear();
        setState(() => _passwordSubmitAttempted = false);
      }
    });

    // When the user flips the language toggle mid-session, the validator
    // closure captured by the TextFormField keeps rendering its last-resolved
    // error string — so you end up with an Arabic error still showing under
    // an English UI. Forcing a re-validate after the switch re-runs the
    // validator with the new locale's strings.
    ref.listen<AppPreferences>(appPreferencesProvider, (prev, next) {
      if (prev == null || prev.locale == next.locale) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _formKey.currentState?.validate();
      });
    });

    final gatePassword = state.requiresPassword;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: RadialGlow(
              opacity: 0.18,
              size: 520,
              alignment: Alignment(0, -0.9),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                // The page scrolls when the keyboard claims room. Previously
                // the layout used `IntrinsicHeight` + `Spacer` to pin the
                // CTA stack to the bottom of the viewport, which broke once
                // content exceeded available height (keyboard up + password
                // gate appeared) — `Spacer` can't go negative, so the
                // Column overflowed by ~20 px and rendered the yellow/black
                // overflow stripes. The simpler scroll-friendly layout
                // below trades the bottom-pinned CTA for a clean scroll on
                // all viewport sizes.
                child: SingleChildScrollView(
                  // Push extra padding when the keyboard is up so the last
                  // CTA can scroll *above* the IME instead of being kissed
                  // by it.
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.viewInsetsOf(context).bottom > 0 ? 16 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lock the top row to LTR so the wordmark stays
                      // top-start and the locale toggle stays top-end
                      // in both locales — brand identity is not
                      // mirrored.
                      const Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          children: [
                            Wordmark(size: 26),
                            Spacer(),
                            EntryTopToggles(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      Overline(l.signInStep),
                      const SizedBox(height: 22),
                      DisplayText(
                        l.signInHeadline1,
                        size: 52,
                        height: 0.88,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          DisplayText(
                            l.signInHeadline2,
                            size: 52,
                            height: 0.88,
                          ),
                          const SizedBox(width: 10),
                          SerifAccent(l.signInHeadlineAccent, size: 52),
                        ],
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: 300,
                        child: Text(
                          l.signInBlurb,
                          style: GPText.body(
                            size: 14,
                            color: context.gp.mutedSoft,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _PhoneField(
                        controller: _phoneCtrl,
                        validator: (v) => _validatePhone(v, l),
                      ),
                      if (gatePassword) ...[
                        const SizedBox(height: 14),
                        _PasswordField(
                          controller: _passwordCtrl,
                          visible: _passwordVisible,
                          onToggle: () => setState(
                            () => _passwordVisible = !_passwordVisible,
                          ),
                          onChanged: () => setState(() {}),
                          showEmptyError: _passwordSubmitAttempted &&
                              _passwordCtrl.text.isEmpty,
                        ),
                        const SizedBox(height: 10),
                        _RememberForgotRow(
                          rememberMe: state.rememberMe,
                          onRememberChanged: (v) => ref
                              .read(authControllerProvider.notifier)
                              .setRememberMe(v),
                          onForgotPassword: _onForgotPassword,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l.signInPasswordNote,
                          style: GPText.mono(
                            size: 10,
                            letterSpacing: 1.2,
                            color: context.gp.muted,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          submitting ? l.signInCheckingNumber : l.signInOtpNote,
                          style: GPText.mono(
                            size: 10,
                            letterSpacing: 1.2,
                            color: context.gp.muted,
                          ),
                        ),
                      ],
                      // Fixed gap between fields and CTA stack. Was a
                      // `Spacer` before, but Spacer needs a bounded
                      // parent height — once the keyboard came up
                      // and content exceeded the viewport, Spacer
                      // collapsed to 0 and the column overflowed. A
                      // plain SizedBox lets the page scroll cleanly
                      // when space is tight and gives reasonable
                      // breathing room when it isn't.
                      const SizedBox(height: 32),
                      if (errorMessage != null) ...[
                        Text(
                          errorMessage,
                          style: GPText.body(size: 13, color: GP.danger),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_biometricReady) ...[
                        PillButton(
                          label: l.biometricSignInBtn,
                          leadingIcon: Icons.fingerprint,
                          onPressed: submitting ? null : _onBiometric,
                        ),
                        const SizedBox(height: 10),
                      ],
                      PillButton(
                        label: gatePassword
                            ? l.signInWithPasswordCta
                            : l.continueLabel,
                        trailingIcon: Icons.arrow_forward,
                        variant: _biometricReady
                            ? PillVariant.secondary
                            : PillVariant.primary,
                        onPressed: (submitting || !canSubmit)
                            ? null
                            : () => _submit(state),
                      ),
                      // Registration-adjacent controls (OR divider +
                      // Google sign-in) disappear once the password
                      // gate is showing, since they belong to the
                      // new-user path.
                      // Google sign-in is gated behind kDebugMode until
                      // real Google JWKS verification lands on the
                      // backend. Showing the button in a release build
                      // would invite users to tap a path that 401s in
                      // production, so the affordance is hidden there.
                      if (!gatePassword && kDebugMode) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: context.gp.line),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                l.orDivider,
                                style: GPText.mono(
                                  size: 10,
                                  letterSpacing: 2,
                                  color: context.gp.muted,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: context.gp.line),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        PillButton(
                          label: l.signInContinueWithGoogle,
                          variant: PillVariant.secondary,
                          leadingIcon: Icons.g_mobiledata_rounded,
                          onPressed: submitting
                              ? null
                              : () async {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l.googleSignInMock),
                                    ),
                                  );
                                  await ref
                                      .read(
                                        authControllerProvider.notifier,
                                      )
                                      .mockGoogleSignIn(
                                        email: l.googleMockEmail,
                                      );
                                  if (!mounted) return;
                                  this.context.go('/home');
                                },
                        ),
                      ],
                      const SizedBox(height: 18),
                      _LegalConsentFooter(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small consent footer that points at the full Terms / Privacy pages.
///
/// Spans-with-recognizers rather than three sibling widgets so the
/// line wraps naturally in narrow viewports without leaving an
/// orphaned "Privacy Policy" alone on its own line.
class _LegalConsentFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final base = GPText.body(size: 11.5, color: gp.muted, height: 1.5);
    final link = base.copyWith(
      color: gp.accentInk,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: gp.accentInk.withValues(alpha: 0.4),
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: '${l.legalSignupConsentPrefix} '),
          TextSpan(
            text: l.legalReadTermsAction,
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => context.push('/legal/terms'),
          ),
          TextSpan(text: ' ${l.and} '),
          TextSpan(
            text: l.legalReadPrivacyAction,
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => context.push('/legal/privacy'),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _RememberForgotRow extends StatelessWidget {
  const _RememberForgotRow({
    required this.rememberMe,
    required this.onRememberChanged,
    required this.onForgotPassword,
  });

  final bool rememberMe;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: () => onRememberChanged(!rememberMe),
          borderRadius: BorderRadius.circular(GPRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: rememberMe,
                    onChanged: (v) => onRememberChanged(v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: gp.line2),
                    activeColor: gp.accentInk,
                    checkColor: gp.bg,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l.signInRememberMe,
                  style: GPText.body(size: 13, color: gp.fg),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: onForgotPassword,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            l.signInForgotPassword,
            style: GPText.body(size: 13, color: gp.accentInk),
          ),
        ),
      ],
    );
  }
}

class _PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  const _PhoneField({
    required this.controller,
    this.validator,
  });

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  // True once the user has finished an interaction with the field
  // (focus lost, or after first character entry). Gates the
  // external error display so a fresh empty field doesn't pop a
  // red message before they've typed anything.
  bool _interacted = false;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    // First keystroke marks the field as interacted — error feedback
    // starts surfacing live.
    if (!_interacted && widget.controller.text.isNotEmpty) {
      setState(() => _interacted = true);
    } else {
      // Trigger a rebuild on every change so the externally-rendered
      // error text re-runs the validator with the latest input.
      setState(() {});
    }
  }

  void _onFocusChanged() {
    // Treat blur as "user is done with this field" so the error is
    // surfaced even when they tab to the next field with an
    // incomplete number.
    if (!_focus.hasFocus && widget.controller.text.isNotEmpty) {
      setState(() => _interacted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final externalError =
        _interacted ? widget.validator?.call(widget.controller.text) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Phone input is always LTR: E.164 prefix on the visual left,
        // national digits entered left-to-right. We wrap THIS subtree
        // (the field + its prefix) in `Directionality.ltr` so the
        // prefixIcon (flag + +962) sits on the visual-left even on
        // an Arabic page. The `errorStyle` is zero-sized so the
        // built-in inline error doesn't render here — instead we
        // surface the error as an *external* Text below the field
        // (outside this Directionality), which inherits the ambient
        // RTL direction in Arabic and right-aligns under the field.
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _JoPhoneFormatter(),
            ],
            style: GPText.mono(
              size: 15,
              color: gp.fg,
              letterSpacing: 1.0,
              weight: FontWeight.w500,
            ),
            cursorColor: gp.accentInk,
            // Validator stays for `Form.validate()` integration on
            // submit. Visual feedback is handled externally below.
            validator: widget.validator,
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const JordanFlag(height: 13),
                    const SizedBox(width: 8),
                    Text(
                      l.phoneCountryPrefix,
                      style: GPText.mono(
                        size: 13,
                        color: gp.fg,
                        letterSpacing: 0.8,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(width: 1, height: 22, color: gp.line),
                  ],
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              hintText: l.phoneHint,
              hintStyle:
                  GPText.mono(size: 13, color: gp.muted, letterSpacing: 1),
              hintTextDirection: TextDirection.ltr,
              // Suppress the built-in inline error renderer. The
              // border still flips to `errorBorder` color when
              // validation fails (Flutter's InputDecorator handles
              // that based on the validator result, not on errorText
              // visibility). Zero-size style + collapsed
              // errorMaxLines hides the text without removing the
              // FormField's error tracking.
              errorStyle: const TextStyle(
                height: 0.001,
                fontSize: 0.001,
                color: Colors.transparent,
              ),
              filled: true,
              fillColor: gp.bg2,
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GPRadius.lg),
                borderSide: const BorderSide(color: GP.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GPRadius.lg),
                borderSide: const BorderSide(color: GP.danger, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            ),
          ),
        ),
        // External error: ambient direction so AR right-aligns it
        // under the phone field's right edge. `textAlign: start`
        // is locale-aware. Padding matches the field's horizontal
        // contentPadding so the text starts under the field's
        // inner edge, not flush with the border.
        if (externalError != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 0),
            child: Text(
              externalError,
              textAlign: TextAlign.start,
              style: GPText.body(size: 12, color: GP.danger, height: 1.3),
            ),
          ),
      ],
    );
  }
}

/// Normalizes raw digit input into the canonical `07XXXXXXXX` Jordanian form.
///
/// Rules applied every keystroke:
///   * if the first digit is `0`, the value is capped at 10 digits;
///   * otherwise the value is capped at 9 digits, and once it reaches exactly
///     9 digits the formatter auto-prepends a leading `0` — so the user can
///     type either `7X XXX XXXX` or `07X XXX XXXX` and always land on the
///     same 10-digit shape.
///
/// Non-digit characters are already stripped by the preceding
/// [FilteringTextInputFormatter.digitsOnly]; this formatter only shapes the
/// already-digit-only string.
class _JoPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (text.isEmpty) return newValue;
    if (text.startsWith('0')) {
      if (text.length > 10) text = text.substring(0, 10);
    } else {
      if (text.length > 9) text = text.substring(0, 9);
      if (text.length == 9) text = '0$text';
    }
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.visible,
    required this.onToggle,
    required this.onChanged,
    required this.showEmptyError,
  });

  final TextEditingController controller;
  final bool visible;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  final bool showEmptyError;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.signInPasswordLabel,
          style: GPText.mono(
            size: 10,
            letterSpacing: 1.8,
            color: gp.muted,
          ),
        ),
        const SizedBox(height: 8),
        // Passwords type left-to-right in every locale — otherwise an Arabic
        // ambient flips the caret and mirrors the visibility toggle, which
        // confuses users typing Latin characters behind an obscure mask.
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: controller,
            obscureText: !visible,
            onChanged: (_) => onChanged(),
            style: GPText.body(size: 14, color: gp.fg),
            cursorColor: gp.accentInk,
            decoration: InputDecoration(
              hintText: l.signInPasswordHint,
              hintStyle: GPText.body(size: 14, color: gp.muted),
              filled: true,
              fillColor: gp.bg2,
              suffixIcon: IconButton(
                onPressed: onToggle,
                icon: Icon(
                  visible ? Icons.visibility_off : Icons.visibility,
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            ),
          ),
        ),
        if (showEmptyError) ...[
          const SizedBox(height: 6),
          Text(
            l.errorPasswordSignInRequired,
            style: GPText.body(size: 12, color: GP.danger),
          ),
        ],
      ],
    );
  }
}
