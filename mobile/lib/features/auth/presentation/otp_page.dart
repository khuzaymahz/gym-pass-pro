import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/entry_toggles.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_controller.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final List<TextEditingController> _cells =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(4, (_) => FocusNode());
  int _seconds = 28;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _seconds = 28;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_seconds == 0) {
        t.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _cells) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _cells.map((c) => c.text).join();

  void _submit() {
    if (_code.length == 4) {
      ref.read(authControllerProvider.notifier).verifyOtp(_code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final l = AppLocalizations.of(context);
    final gp = context.gp;

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      // Router redirect decides destination (profile gate — /register or /home).
      if (next.phase == AuthPhase.anonymous) {
        context.go('/sign-in');
      } else if (prev?.phase != AuthPhase.authed &&
          next.phase == AuthPhase.authed) {
        context.go('/home');
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: RadialGlow(opacity: 0.14, alignment: Alignment(0, -0.95)),
          ),
          SafeArea(
            // Scrollable top + bottom-pinned CTA. The previous layout
            // was a `Padding > Column` with a `Spacer` before the
            // Continue button — that pattern overflowed when the
            // numeric keyboard claimed enough viewport that the
            // Column's natural content exceeded the remaining height.
            // The split below keeps Continue visible at the bottom of
            // the slot and lets the OTP cells / resend row scroll
            // independently if a tiny phone squeezes the layout.
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BackBtn(onPressed: () {
                        ref.read(authControllerProvider.notifier).logout();
                        context.go('/sign-in');
                      },),
                      const Spacer(),
                      const EntryTopToggles(),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Overline(l.otpStep),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              DisplayText(l.otpAlmostTitle,
                                  size: 44, height: 0.9,),
                              const SizedBox(width: 10),
                              SerifAccent(l.otpAlmostAccent, size: 44),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l.otpSentToPhone(
                              state.phone.isEmpty
                                  ? l.otpPhoneFallback
                                  : state.phone,
                            ),
                            style: GPText.body(size: 14, color: gp.mutedSoft),
                          ),
                          const SizedBox(height: 34),
                          // OTP digits always L-to-R, even on AR — cell 1
                          // sits on the visual left so the auto-advance
                          // focus flow matches what the user sees.
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                4,
                                (i) => _otpCell(i, gp),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Text(
                                _seconds > 0
                                    ? l.otpResendIn(_seconds)
                                    : l.otpResendNow,
                                style: GPText.mono(
                                  size: 11,
                                  letterSpacing: 1.5,
                                  color: _seconds > 0
                                      ? gp.accentInk
                                      : gp.mutedSoft,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _seconds == 0
                                    ? () {
                                        ref
                                            .read(
                                              authControllerProvider.notifier,
                                            )
                                            .requestOtp(state.phone);
                                        _startCountdown();
                                      }
                                    : null,
                                child: Text(
                                  l.otpResendBtn,
                                  style: GPText.mono(
                                    size: 11,
                                    letterSpacing: 1.5,
                                    color: _seconds == 0 ? gp.fg : gp.muted,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (state.error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              state.error!,
                              style: GPText.body(size: 13, color: GP.danger),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PillButton(
                    label: l.continueLabel,
                    trailingIcon: Icons.arrow_forward,
                    onPressed: state.loading || _code.length < 4 ? null : _submit,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpCell(int i, GpColors gp) {
    final filled = _cells[i].text.isNotEmpty;
    final focused = _nodes[i].hasFocus;
    return Container(
      width: 64,
      height: 80,
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.xl),
        border: Border.all(
          color: focused || filled ? gp.accentInk : gp.line,
          width: focused || filled ? 1.6 : 1,
        ),
        boxShadow: focused || filled
            ? [BoxShadow(color: GP.lime.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: -4)]
            : gp.cardShadows,
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _cells[i],
        focusNode: _nodes[i],
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        textAlign: TextAlign.center,
        cursorColor: gp.accentInk,
        style: GPText.display(32, color: gp.fg, height: 1.0)
            .copyWith(fontStyle: FontStyle.normal),
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
            _nodes[i + 1].requestFocus();
          } else if (v.isEmpty && i > 0) {
            _nodes[i - 1].requestFocus();
          }
          if (_code.length == 4) _submit();
        },
      ),
    );
  }
}
