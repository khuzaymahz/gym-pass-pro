import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/entry_toggles.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/help_button.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../data/user_profile.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  Gender? _gender;
  DateTime? _birthdate;
  bool _agreed = false;
  bool _showAgreementError = false;
  bool _showGenderError = false;
  bool _showBirthdateError = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _firstNameCtrl.text = profile.firstName ?? '';
    _lastNameCtrl.text = profile.lastName ?? '';
    _emailCtrl.text = profile.email ?? '';
    _gender = profile.gender;
    _birthdate = profile.birthdate;
    // No per-controller listeners — the Form below uses
    // `onChanged: () => setState(...)` so a single rebuild covers
    // every field. The previous shape (five anonymous addListener
    // closures) fired the rebuild once per field per keystroke and
    // had no detach in dispose, leaking listeners across hot
    // restarts.
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  static const _minNameLength = 3;

  String? _validateFirstName(String? v, AppLocalizations l) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return l.errorFirstNameRequired;
    if (t.runes.length < _minNameLength) {
      return l.errorNameTooShort(_minNameLength);
    }
    return null;
  }

  String? _validateLastName(String? v, AppLocalizations l) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return l.errorLastNameRequired;
    if (t.runes.length < _minNameLength) {
      return l.errorNameTooShort(_minNameLength);
    }
    return null;
  }

  String? _validateEmail(String? v, AppLocalizations l) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return l.errorEmailRequired;
    final re = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');
    if (!re.hasMatch(t)) return l.errorEmailInvalid;
    return null;
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

  bool _canSubmit() {
    final l = AppLocalizations.of(context);
    return _validateFirstName(_firstNameCtrl.text, l) == null &&
        _validateLastName(_lastNameCtrl.text, l) == null &&
        _validateEmail(_emailCtrl.text, l) == null &&
        _validatePassword(_passwordCtrl.text, l) == null &&
        _validateConfirm(_confirmCtrl.text, l) == null &&
        _gender != null &&
        _birthdate != null &&
        _agreed;
  }

  void _submit() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (_gender == null) {
      setState(() => _showGenderError = true);
      return;
    }
    if (_birthdate == null) {
      setState(() => _showBirthdateError = true);
      return;
    }
    if (!_agreed) {
      setState(() => _showAgreementError = true);
      return;
    }
    if (!ok) return;
    FocusScope.of(context).unfocus();
    unawaited(_persistAndContinue());
  }

  Future<void> _persistAndContinue() async {
    await ref.read(profileProvider.notifier).completeRegistration(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          gender: _gender!,
          birthdate: _birthdate,
          password: _passwordCtrl.text,
        );
    if (!mounted) return;
    context.go('/plans');
  }

  /// Open the system date picker bounded to a sane membership age
  /// range (must be 13+ years old; cap at 100 years past). Date
  /// picker theme inherits the app theme for amber accents in
  /// both light and dark modes.
  Future<void> _pickBirthdate(AppLocalizations l) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final earliest = DateTime(now.year - 100, now.month, now.day);
    final latest = DateTime(now.year - 13, now.month, now.day);
    final initial = _birthdate ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(latest) ? latest : initial,
      firstDate: earliest,
      lastDate: latest,
      // Calendar mode reads as more "modern" than the wheel; lets
      // the member jump to a year quickly via the year picker tap.
      initialEntryMode: DatePickerEntryMode.calendar,
      helpText: l.birthdateHelpText,
    );
    if (picked == null) return;
    setState(() {
      _birthdate = picked;
      _showBirthdateError = false;
    });
  }

  String _formatBirthdate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd / $mm / ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: RadialGlow(opacity: 0.14, alignment: Alignment(0, -0.95)),
          ),
          SafeArea(
            minimum: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                // Single rebuild per change across every field —
                // drives the CTA's enabled/disabled state and the
                // password match check.
                onChanged: () {
                  if (mounted) setState(() {});
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // No back button on signup — by the time the
                    // member lands here they've already verified
                    // their phone via OTP. A back button would
                    // unwind that verification and leave them on
                    // sign-in, where they'd just have to OTP again.
                    // Kept the entry toggles (theme + locale) at the
                    // end so the brand controls stay reachable.
                    const Row(
                      children: [
                        Spacer(),
                        EntryTopToggles(),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Overline(l.registerStep),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        DisplayText(l.registerTitle, size: 44, height: 0.9),
                        const SizedBox(width: 10),
                        SerifAccent(l.registerTitleAccent, size: 44),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(l.registerBlurb,
                        style: GPText.body(size: 14, color: gp.mutedSoft),),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _floatingField(
                            context: context,
                            controller: _firstNameCtrl,
                            label: l.labelFirstName,
                            textInputAction: TextInputAction.next,
                            validator: (v) => _validateFirstName(v, l),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _floatingField(
                            context: context,
                            controller: _lastNameCtrl,
                            label: l.labelLastName,
                            textInputAction: TextInputAction.next,
                            validator: (v) => _validateLastName(v, l),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Floating-label email: shows `username@domain.com`
                    // sample as resting label inside the field; on
                    // focus / fill the label rises smoothly to the
                    // border edge with the actual "Email" label
                    // taking its place at the top.
                    _floatingField(
                      context: context,
                      controller: _emailCtrl,
                      label: l.labelEmail,
                      restingPlaceholder: l.hintEmail,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) => _validateEmail(v, l),
                    ),
                    const SizedBox(height: 20),
                    _floatingField(
                      context: context,
                      controller: _passwordCtrl,
                      label: l.labelPassword,
                      restingPlaceholder: l.hintPassword,
                      obscure: !_passwordVisible,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.next,
                      suffixIcon: _visibilityToggle(
                        visible: _passwordVisible,
                        onTap: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                      ),
                      validator: (v) => _validatePassword(v, l),
                    ),
                    const SizedBox(height: 20),
                    _floatingField(
                      context: context,
                      controller: _confirmCtrl,
                      label: l.labelPasswordConfirm,
                      restingPlaceholder: l.hintPasswordConfirm,
                      obscure: !_confirmVisible,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      suffixIcon: _visibilityToggle(
                        visible: _confirmVisible,
                        onTap: () => setState(
                          () => _confirmVisible = !_confirmVisible,
                        ),
                      ),
                      validator: (v) => _validateConfirm(v, l),
                    ),
                    const SizedBox(height: 20),
                    _label(context, l.labelGender),
                    const SizedBox(height: 8),
                    _genderSelector(context, l),
                    if (_showGenderError && _gender == null) ...[
                      const SizedBox(height: 6),
                      // textAlign defaults to start which honors the
                      // ambient text direction — left-aligned in EN,
                      // right-aligned in AR — so the error sits
                      // under the same edge as the gender pill.
                      Text(
                        l.errorGenderRequired,
                        textAlign: TextAlign.start,
                        style: GPText.body(size: 12, color: GP.danger),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _label(context, l.labelBirthdate),
                    const SizedBox(height: 8),
                    _birthdateField(context, l),
                    if (_showBirthdateError && _birthdate == null) ...[
                      const SizedBox(height: 6),
                      Text(
                        l.errorBirthdateRequired,
                        textAlign: TextAlign.start,
                        style: GPText.body(size: 12, color: GP.danger),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _agreementBox(context, l),
                    if (_showAgreementError && !_agreed) ...[
                      const SizedBox(height: 8),
                      Text(
                        l.errorAgreementRequired,
                        textAlign: TextAlign.start,
                        style: GPText.body(size: 12, color: GP.danger),
                      ),
                    ],
                    const SizedBox(height: 28),
                    PillButton(
                      label: l.createMyPass,
                      trailingIcon: Icons.arrow_forward,
                      onPressed: _canSubmit() ? _submit : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 78 + MediaQuery.viewPaddingOf(context).bottom,
            left: 20,
            child: HelpButton(tips: [
              HelpTip(icon: Icons.badge_outlined, text: l.helpRegister1),
              HelpTip(icon: Icons.credit_card_off_outlined, text: l.helpRegister2),
              HelpTip(icon: Icons.lock_outlined, text: l.helpRegister3),
              HelpTip(icon: Icons.account_circle_outlined, text: l.helpRegister4),
              HelpTip(icon: Icons.gavel_rounded, text: l.helpRegister5),
            ],),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(text,
      style: GPText.mono(
          size: 10, letterSpacing: 1.8, color: context.gp.muted,),);

  Widget _visibilityToggle({
    required bool visible,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: context.gp.muted,
      ),
    );
  }

  /// Two-position toggle for male/female. The selected pill slides
  /// between halves with a soft elastic easing (the "jelly light"
  /// curve the user asked for): firm enough to feel responsive,
  /// soft enough to read as friendly. Built on `AnimatedAlign` so
  /// the pill physically moves rather than fading on/off — which
  /// is what makes the swap feel like one continuous gesture
  /// rather than two separate state flips.
  Widget _genderSelector(BuildContext context, AppLocalizations l) {
    final gp = context.gp;
    // Index 0 = male (start), 1 = female (end), null = nothing
    // selected. The pill starts hidden until first tap so the
    // unset state is visually distinct from "male is the default".
    final selectedIndex = _gender == Gender.male
        ? 0
        : _gender == Gender.female
            ? 1
            : null;
    // Map the selected index to an Alignment value. Directionality
    // is honored via AlignmentDirectional so the AR layout (where
    // male sits visually right) animates correctly with the same
    // 0/1 indices.
    final pillAlignment = selectedIndex == null
        ? AlignmentDirectional.centerStart
        : (selectedIndex == 0
            ? AlignmentDirectional.centerStart
            : AlignmentDirectional.centerEnd);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.pill),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Each half-width pill spans 50% of the inner width minus
          // the 6px outer padding (already absorbed via constraints).
          final pillWidth = constraints.maxWidth / 2;
          return SizedBox(
            height: 44,
            child: Stack(
              children: [
                // The animated "jelly" pill — only rendered when a
                // gender is selected. AnimatedAlign + elasticOut
                // makes it overshoot slightly then settle, which
                // is the springy feel we want.
                if (selectedIndex != null)
                  AnimatedAlign(
                    alignment: pillAlignment,
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      width: pillWidth,
                      height: 44,
                      decoration: BoxDecoration(
                        color: GP.lime,
                        borderRadius: BorderRadius.circular(GPRadius.pill),
                        boxShadow: [
                          // Subtle amber glow to give the pill a
                          // "lit" feel — the second half of "jelly
                          // light".
                          BoxShadow(
                            color: GP.lime.withValues(alpha: 0.35),
                            blurRadius: 16,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                    ),
                  ),
                // Tap targets sit on top of the pill so the labels
                // stay clickable. Each is half the width and the
                // text colour cross-fades with the same animated-
                // default-text-style trick the pill uses.
                Row(
                  children: [
                    Expanded(
                      child: _genderTapTarget(
                        context,
                        label: l.genderMale,
                        selected: selectedIndex == 0,
                        onTap: () => setState(() {
                          _gender = Gender.male;
                          _showGenderError = false;
                        }),
                      ),
                    ),
                    Expanded(
                      child: _genderTapTarget(
                        context,
                        label: l.genderFemale,
                        selected: selectedIndex == 1,
                        onTap: () => setState(() {
                          _gender = Gender.female;
                          _showGenderError = false;
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _genderTapTarget(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final gp = context.gp;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        // AnimatedDefaultTextStyle cross-fades the label colour /
        // weight in lockstep with the pill's slide so the active
        // half "lights up" as the pill arrives rather than
        // snapping to dark text the instant the tap fires.
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          style: GPText.body(
            size: 13,
            color: selected ? GP.ink : gp.mutedSoft,
            weight: FontWeight.w600,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  /// Floating-label input. Resting state: the label sits inside
  /// the field at body-text size (or, when `restingPlaceholder`
  /// is set, that placeholder shows in the field while the label
  /// hides — used for email so the member sees `username@domain.com`
  /// as a sample format hint). On focus or when text is present,
  /// the label rises to the top edge of the border at small size
  /// — Flutter's built-in `floatingLabelBehavior: auto` handles the
  /// transition with its default ease, no custom animation needed.
  Widget _floatingField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    String? restingPlaceholder,
    FormFieldValidator<String>? validator,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    final gp = context.gp;
    final hasText = controller.text.trim().isNotEmpty;
    // Email and password are always typed LTR even on AR locale,
    // BUT we don't wrap the entire field in a `Directionality(LTR)`
    // — that would also flip the floating label, the border layout,
    // and the error message to LTR, leaving an Arabic member with
    // a label rendered on the visual-left of an otherwise
    // right-to-left page. Instead, push the LTR override onto just
    // the input text + the placeholder via `textDirection` /
    // `hintTextDirection`. The chrome (label, border, errorText)
    // continues to inherit the ambient locale direction, so in AR
    // the label "البريد الإلكتروني" sits on the right edge while
    // the typed email and the `username@domain.com` example flow
    // left-to-right.
    // Email and password fields are always LTR. For passwords the key
    // is `TextInputType.visiblePassword`, NOT `obscure` — the obscure
    // flag flips to false the moment the member taps the eye toggle
    // to reveal the password, and we don't want the visible Latin
    // text to suddenly snap to the right edge of the field on an
    // Arabic page.
    final isLtrInput = keyboardType == TextInputType.emailAddress ||
        keyboardType == TextInputType.visiblePassword;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscure,
      cursorColor: gp.accentInk,
      validator: validator,
      style: GPText.body(size: 15, color: gp.fg, weight: FontWeight.w500),
      textDirection: isLtrInput ? TextDirection.ltr : null,
      // Force the typed text + obscure dots + cursor to align to
      // the visual-left in LTR-only fields, regardless of the
      // ambient locale. Without this, an AR page's RTL ambient
      // direction makes `textAlign: start` resolve to `right` —
      // so the LTR password renders right-aligned and the cursor
      // jumps to the right edge as the user types, which reads
      // as broken.
      textAlign: isLtrInput ? TextAlign.left : TextAlign.start,
      decoration: InputDecoration(
        labelText: label,
        // Show the resting-state placeholder ONLY when the label
        // would otherwise be sitting inside the field (i.e. the
        // field is empty and unfocused). Once the label floats up
        // to the top edge, the placeholder would visually duplicate
        // it, so we suppress it.
        hintText: hasText ? null : restingPlaceholder,
        // Force LTR hint direction for email so the
        // `username@domain.com` example renders left-to-right even
        // when the surrounding field is RTL. Password and name
        // fields fall through to ambient direction so Arabic hints
        // (e.g. "٨ أحرف على الأقل") render naturally RTL.
        hintTextDirection:
            keyboardType == TextInputType.emailAddress
                ? TextDirection.ltr
                : null,
        hintStyle: GPText.body(size: 14, color: gp.muted),
        labelStyle: GPText.body(size: 15, color: gp.muted),
        // Floating-state label sits at the top of the border. The
        // brand amber tint signals "this field is active" — same
        // colour as the focused border.
        floatingLabelStyle: GPText.body(
          size: 12,
          color: gp.accentInk,
          weight: FontWeight.w600,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        suffixIcon: suffixIcon,
        // Errors inherit the ambient text direction, so AR errors
        // auto-align to the right edge of the input below the
        // field, matching the `start`-anchored fields above them.
        errorStyle: GPText.body(size: 12, color: GP.danger, height: 1.3),
        errorMaxLines: 3,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
    );
  }

  /// Tappable surface that opens the system date picker. Looks like
  /// a regular field but isn't editable — typing a date by hand is
  /// error-prone (M/D vs D/M, two-digit year, etc.), so the picker
  /// is the only entry path.
  Widget _birthdateField(BuildContext context, AppLocalizations l) {
    final gp = context.gp;
    final hasValue = _birthdate != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.lg),
        onTap: () => _pickBirthdate(l),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: gp.bg2,
            borderRadius: BorderRadius.circular(GPRadius.lg),
            border: Border.all(
              color: hasValue ? gp.accentInk : gp.line,
              width: hasValue ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: hasValue ? gp.accentInk : gp.muted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  hasValue ? _formatBirthdate(_birthdate!) : l.hintBirthdate,
                  style: GPText.body(
                    size: 15,
                    color: hasValue ? gp.fg : gp.muted,
                    weight:
                        hasValue ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 22,
                color: gp.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agreementBox(BuildContext context, AppLocalizations l) {
    final gp = context.gp;
    final linkStyle = GPText.body(
      size: 13,
      color: gp.accentInk,
      weight: FontWeight.w600,
      height: 1.4,
    );
    return GestureDetector(
      onTap: () => setState(() {
        _agreed = !_agreed;
        if (_agreed) _showAgreementError = false;
      }),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GP.lime22,
          borderRadius: BorderRadius.circular(GPRadius.md),
          border: Border.all(color: gp.accentInk.withValues(alpha: 0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: _agreed ? GP.lime : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: gp.accentInk, width: 1.5),
              ),
              child: _agreed
                  ? Icon(Icons.check, color: gp.onLime, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: GPText.body(size: 13, color: gp.fg, height: 1.4),
                  children: [
                    TextSpan(text: '${l.agreementText} '),
                    TextSpan(
                      text: l.terms,
                      style: linkStyle,
                      // TapGestureRecognizer is the only way to make
                      // a TextSpan inside a Text.rich tappable. The
                      // signup form state survives — go_router pushes
                      // on top, doesn't unmount this widget — so the
                      // member returns to the same partly-filled form
                      // when they pop the legal page.
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => context.push('/legal/terms'),
                    ),
                    TextSpan(text: ' ${l.and} '),
                    TextSpan(
                      text: l.privacyPolicy,
                      style: linkStyle,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => context.push('/legal/privacy'),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
