import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/entry_toggles.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/gp_scaffold.dart';
import '../../../core/widgets/help_button.dart';
import '../../../core/widgets/gym_loader.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

enum _ResetMethod { sms, email }

enum _ResetStep { method, code, password }

/// Password reset wizard, opened from the sign-in page's "Forgot password?"
/// link. Walks the user through picking a delivery channel (SMS or email),
/// verifying a 4-digit code, and setting a new password. In dev the "send"
/// step is a local delay — CLAUDE.md §4 dictates 1234 as the valid code.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  _ResetStep _step = _ResetStep.method;
  _ResetMethod? _method;
  bool _accountExists = false;
  String? _maskedEmail;
  bool _lookupDone = false;

  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The code, password, and confirm fields drive the CTA's
    // enabled/disabled state and the password match check, so each
    // keystroke needs a rebuild. The previous shape — three anonymous
    // `addListener(() => setState(() {}))` closures — is the listener-
    // storm pattern: every controller fires on EVERY mutation
    // (including programmatic clears), three times per keystroke.
    // Replaced with a single named handler so we can detach cleanly
    // in dispose, and the password fields rebuild via Form(
    // autovalidateMode: onUserInteraction) further down. The code
    // field still drives the CTA, hence the listener.
    _codeCtrl.addListener(_onCtrlChange);
    _passwordCtrl.addListener(_onCtrlChange);
    _confirmCtrl.addListener(_onCtrlChange);
    _lookupAccount();
  }

  void _onCtrlChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _codeCtrl.removeListener(_onCtrlChange);
    _passwordCtrl.removeListener(_onCtrlChange);
    _confirmCtrl.removeListener(_onCtrlChange);
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupAccount() async {
    // Backend confirms the phone is registered (existence is unavoidably
    // leaked anyway by the OTP UX) and returns a masked email when one is
    // on file. The masked form is the only email we ever surface — full
    // addresses never leave the server.
    bool exists = false;
    String? masked;
    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.checkPhone(widget.phone);
      exists = result.exists;
      masked = result.maskedEmail;
    } catch (_) {
      exists = false;
      masked = null;
    }
    if (!mounted) return;
    setState(() {
      _accountExists = exists;
      _maskedEmail = masked;
      _lookupDone = true;
      // Default to email-reset when the backend says one is on file, so the
      // happier path is one tap closer; SMS otherwise.
      _method = (masked != null && masked.isNotEmpty)
          ? _ResetMethod.email
          : _ResetMethod.sms;
    });
  }

  /// Masks the middle of a phone so we don't echo the full number on screen
  /// as the "code destination". E.g. `+962780195111` → `+962 78 ••• 5111`.
  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    final prefix = phone.substring(0, phone.length - 4);
    final tail = phone.substring(phone.length - 4);
    final masked =
        '${prefix.substring(0, prefix.length - 3)}•••'; // keep area visible
    return '$masked $tail';
  }

  String _targetForSelectedMethod() {
    if (_method == _ResetMethod.email && (_maskedEmail ?? '').isNotEmpty) {
      return _maskedEmail!;
    }
    return _maskPhone(widget.phone);
  }

  Future<void> _sendCode() async {
    if (_method == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Real OTP. Email channel still routes through the same SMS endpoint
      // because the backend doesn't yet expose an email-OTP path; the channel
      // toggle is UX scaffolding for when it does.
      await ref.read(authRepositoryProvider).requestPhoneOtp(widget.phone);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = _ResetStep.code;
        _codeCtrl.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).forgotErrAccountMissing;
      });
    }
  }

  Future<void> _verifyCode() async {
    final l = AppLocalizations.of(context);
    final code = _codeCtrl.text.trim();
    if (code.length != 4) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Verify mints a session for the phone owner — that's the privilege
      // the user needs to PATCH /me with a new password in the next step.
      await ref.read(authRepositoryProvider).verifyPhoneOtp(
            phone: widget.phone,
            code: code,
            persistent: false,
          );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = _ResetStep.password;
        _passwordCtrl.clear();
        _confirmCtrl.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = l.forgotErrCodeInvalid;
      });
    }
  }

  String? _validatePassword(String? v, AppLocalizations l) {
    final t = v ?? '';
    if (t.isEmpty) return l.errorPasswordRequired;
    if (t.length < 8) return l.errorPasswordTooShort;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(t);
    final hasDigit = RegExp(r'\d').hasMatch(t);
    if (!hasLetter || !hasDigit) return l.errorPasswordWeak;
    return null;
  }

  String? _validateConfirm(String? v, AppLocalizations l) {
    if ((v ?? '') != _passwordCtrl.text) return l.errorPasswordMismatch;
    return null;
  }

  bool _canSubmitPassword(AppLocalizations l) {
    return _validatePassword(_passwordCtrl.text, l) == null &&
        _validateConfirm(_confirmCtrl.text, l) == null;
  }

  Future<void> _submitNewPassword() async {
    final l = AppLocalizations.of(context);
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await ref
        .read(authControllerProvider.notifier)
        .updatePassword(phone: widget.phone, newPassword: _passwordCtrl.text);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _loading = false;
        _error = l.forgotErrAccountMissing;
      });
      return;
    }
    // Drop the temporary session minted by the OTP-verify step so the user
    // re-authenticates with the new password from a clean slate.
    await ref.read(authRepositoryProvider).logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(duration: const Duration(seconds: 4), content: Text(l.forgotResetSuccess)),
    );
    // Back to sign-in so the user enters the new password against the same
    // gate they came from — fresh state, no stale error.
    context.go('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;

    return GpScaffold(
      tips: [
        HelpTip(icon: Icons.phone_outlined, text: l.helpForgotPw1),
        HelpTip(icon: Icons.alternate_email_rounded, text: l.helpForgotPw2),
        HelpTip(icon: Icons.lock_reset_rounded, text: l.helpForgotPw3),
        HelpTip(icon: Icons.key_rounded, text: l.helpForgotPw4),
        HelpTip(icon: Icons.login_rounded, text: l.helpForgotPw5),
      ],
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: RadialGlow(opacity: 0.14, alignment: Alignment(0, -0.95)),
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BackBtn(
                        onPressed: () {
                          if (_step == _ResetStep.method) {
                            context.pop();
                          } else {
                            setState(() {
                              _step = _ResetStep.values[_step.index - 1];
                              _error = null;
                            });
                          }
                        },
                      ),
                      const Spacer(),
                      const EntryTopToggles(),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Overline(_stepLabel(l)),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      DisplayText(l.forgotTitle, size: 44, height: 0.9),
                      const SizedBox(width: 10),
                      SerifAccent(l.forgotTitleAccent, size: 44),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Expanded(child: _stepBody(l, gp)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _stepLabel(AppLocalizations l) {
    switch (_step) {
      case _ResetStep.method:
        return l.forgotStep1;
      case _ResetStep.code:
        return l.forgotStep2;
      case _ResetStep.password:
        return l.forgotStep3;
    }
  }

  Widget _stepBody(AppLocalizations l, GpColors gp) {
    switch (_step) {
      case _ResetStep.method:
        return _methodStep(l, gp);
      case _ResetStep.code:
        return _codeStep(l, gp);
      case _ResetStep.password:
        return _passwordStep(l, gp);
    }
  }

  Widget _methodStep(AppLocalizations l, GpColors gp) {
    if (!_lookupDone) {
      return const Center(
        child: GymLoader(size: GymLoaderSize.large),
      );
    }
    if (!_accountExists) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.forgotErrAccountMissing,
            style: GPText.body(size: 14, color: GP.danger),
          ),
          const SizedBox(height: 24),
          PillButton(
            label: l.back,
            onPressed: () => context.pop(),
          ),
        ],
      );
    }
    final masked = (_maskedEmail ?? '').trim();
    final hasEmail = masked.isNotEmpty;
    // Scrollable top content + bottom-pinned CTA. The previous
    // `Column + Spacer + button` pattern overflowed when the keyboard
    // pushed the parent's bounded slot below the natural content
    // height. The Stack-with-Positioned approach keeps the CTA
    // visually pinned to the bottom of the slot while letting the top
    // content scroll independently.
    return _StepFrame(
      gp: gp,
      error: _error,
      cta: PillButton(
        label: l.forgotSendCode,
        trailingIcon: Icons.arrow_forward,
        onPressed: (_method == null || _loading) ? null : _sendCode,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.forgotBlurb1,
            style: GPText.body(size: 14, color: gp.mutedSoft),
          ),
          const SizedBox(height: 18),
          _methodTile(
            gp: gp,
            selected: _method == _ResetMethod.sms,
            icon: Icons.sms_outlined,
            title: l.forgotMethodSmsTitle,
            subtitle: l.forgotMethodSmsSubtitle(_maskPhone(widget.phone)),
            onTap: () => setState(() => _method = _ResetMethod.sms),
          ),
          const SizedBox(height: 12),
          _methodTile(
            gp: gp,
            selected: _method == _ResetMethod.email,
            icon: Icons.mail_outline,
            title: l.forgotMethodEmailTitle,
            subtitle: hasEmail
                ? l.forgotMethodEmailSubtitle(masked)
                : l.forgotMethodEmailMissing,
            onTap: hasEmail
                ? () => setState(() => _method = _ResetMethod.email)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            l.forgotDevHint,
            style: GPText.mono(
              size: 10,
              letterSpacing: 1.2,
              color: gp.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodTile({
    required GpColors gp,
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? gp.bg3 : gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(
              color: selected ? gp.accentInk : gp.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? gp.accentInk.withValues(alpha: 0.12)
                      : gp.bg3,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 20,
                  color: disabled ? gp.muted : gp.fg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GPText.body(
                        size: 14,
                        color: disabled ? gp.muted : gp.fg,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GPText.mono(
                        size: 10,
                        letterSpacing: 1.0,
                        color: gp.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? gp.accentInk : gp.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _codeStep(AppLocalizations l, GpColors gp) {
    return _StepFrame(
      gp: gp,
      error: _error,
      cta: PillButton(
        label: l.forgotVerifyCode,
        trailingIcon: Icons.arrow_forward,
        onPressed: (_loading || _codeCtrl.text.length != 4)
            ? null
            : _verifyCode,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.forgotCodeBlurb(_targetForSelectedMethod()),
            style: GPText.body(size: 14, color: gp.mutedSoft),
          ),
          const SizedBox(height: 20),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GPText.display(28, color: gp.fg, height: 1.0)
                  .copyWith(fontStyle: FontStyle.normal, letterSpacing: 12),
              cursorColor: gp.accentInk,
              decoration: InputDecoration(
                counterText: '',
                hintText: '0000',
                hintStyle: GPText.display(28, color: gp.muted)
                    .copyWith(fontStyle: FontStyle.normal, letterSpacing: 12),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading ? null : _sendCode,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l.forgotResendCode,
              style: GPText.body(size: 13, color: gp.accentInk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordStep(AppLocalizations l, GpColors gp) {
    return Form(
      key: _passwordFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: _StepFrame(
        gp: gp,
        error: _error,
        cta: PillButton(
          label: l.forgotSetNewPassword,
          trailingIcon: Icons.arrow_forward,
          onPressed: (_loading || !_canSubmitPassword(l))
              ? null
              : _submitNewPassword,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.forgotNewPasswordBlurb,
              style: GPText.body(size: 14, color: gp.mutedSoft),
            ),
            const SizedBox(height: 20),
            _label(gp, l.labelPassword),
            const SizedBox(height: 8),
            _passwordField(
              controller: _passwordCtrl,
              hint: l.hintPassword,
              visible: _passwordVisible,
              onToggle: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
              validator: (v) => _validatePassword(v, l),
              gp: gp,
            ),
            const SizedBox(height: 16),
            _label(gp, l.labelPasswordConfirm),
            const SizedBox(height: 8),
            _passwordField(
              controller: _confirmCtrl,
              hint: l.hintPasswordConfirm,
              visible: _confirmVisible,
              onToggle: () =>
                  setState(() => _confirmVisible = !_confirmVisible),
              validator: (v) => _validateConfirm(v, l),
              gp: gp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(GpColors gp, String text) => Text(
        text,
        style: GPText.mono(size: 10, letterSpacing: 1.8, color: gp.muted),
      );

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
    required FormFieldValidator<String> validator,
    required GpColors gp,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      // Passwords are always Latin, so force the typed text + cursor
      // to the visual-left even on an Arabic page. Keying off the
      // input type (not `obscure`) so the alignment survives the
      // visibility toggle — otherwise revealing the password would
      // snap the visible text to the right edge of the field.
      keyboardType: TextInputType.visiblePassword,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      validator: validator,
      cursorColor: gp.accentInk,
      style: GPText.body(size: 15, color: gp.fg, weight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GPText.body(size: 14, color: gp.muted),
        filled: true,
        fillColor: gp.bg2,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: gp.muted,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GPRadius.lg),
          borderSide: const BorderSide(color: GP.danger),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
    );
  }
}

/// Step body frame: a scrollable top region above a CTA pinned to the
/// bottom. Each step in the forgot-password wizard sits inside an
/// `Expanded` slot whose height shrinks when the IME claims room — the
/// previous `Column + Spacer + button` pattern overflowed once natural
/// content exceeded the bounded height (typical on small Androids
/// when both password fields + the keyboard are visible). This frame
/// keeps the CTA visible at the bottom of the slot, lets the top
/// content scroll independently when squeezed, and surfaces inline
/// errors directly above the CTA where they're hardest to miss.
class _StepFrame extends StatelessWidget {
  const _StepFrame({
    required this.gp,
    required this.cta,
    required this.child,
    this.error,
  });

  final GpColors gp;
  final Widget cta;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            // Allow scrolling even when content is short — keeps the
            // gesture available so a member can flick to dismiss the
            // keyboard if they need to.
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            child: child,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: GPText.body(size: 13, color: GP.danger)),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 12),
        cta,
        const SizedBox(height: 8),
      ],
    );
  }
}
