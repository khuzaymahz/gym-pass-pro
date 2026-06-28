import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/deep_link/deep_link_handler.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/gp_text.dart';
import '../../../core/theme/gp_tokens.dart';
import '../../../core/widgets/glow.dart';
import '../../../core/widgets/help_button.dart';
import '../../../core/widgets/icon_btn.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/top_bounce_physics.dart';
import '../../../core/widgets/wordmark_refresh.dart';
import '../../../l10n/app_localizations.dart';
import '../data/referral_state.dart';

class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key});

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  final _claimController = TextEditingController();
  bool _claimSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Consume a referral code captured by the deep-link handler — set
    // when the OS routed `https://gym-pass.net/invite/<code>` (or the
    // `gympass://invite/<code>` custom-scheme variant) to the app
    // while it was launching or running. We pre-fill the claim input
    // so the friend's code arrives on the page without retyping; we
    // do NOT auto-submit because every claim has irreversible
    // consequences (one-shot per account) and the member should still
    // tap Claim consciously. The slot is cleared in the same frame so
    // a stale code can't be replayed across a page revisit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(pendingReferralCodeProvider);
      if (pending != null && pending.isNotEmpty) {
        _claimController.text = pending;
        ref.read(pendingReferralCodeProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _claimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gp = context.gp;
    final referral = ref.watch(referralProvider);
    final webBase = ref.watch(envProvider).webBaseUrl;
    final shareUrl = referral.shareUrlFor(webBase);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: RadialGlow(
              opacity: 0.12,
              size: 520,
              alignment: Alignment(0, -0.95),
            ),
          ),
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
                children: [Overline(l.inviteOverline)],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  DisplayText(l.inviteHeadline, size: 34),
                  const SizedBox(width: 10),
                  SerifAccent(l.inviteHeadlineAccent, size: 34),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l.inviteBlurb,
                style: GPText.body(size: 14, color: gp.mutedSoft),
              ),
              const SizedBox(height: 22),
              _codeCard(context, l, gp, referral, shareUrl),
              const SizedBox(height: 14),
              _actions(context, l, referral, shareUrl),
              const SizedBox(height: 22),
              _countsRow(l, gp, referral),
              const SizedBox(height: 22),
              if (referral.invitedByName != null) ...[
                _invitedByCard(l, gp, referral.invitedByName!),
                const SizedBox(height: 22),
              ] else ...[
                _claimCard(l, gp, referral),
                const SizedBox(height: 22),
              ],
              Row(children: [Overline(l.inviteListTitle, bullet: false)]),
              const SizedBox(height: 12),
              // Builder gives a context inside the WordmarkRefresh's
              // RefreshScope so the InheritedWidget lookup actually
              // resolves — without it, the outer page context sits
              // above WordmarkRefresh and the conditional would
              // silently never fire.
              Builder(
                builder: (innerCtx) {
                  if (RefreshScope.of(innerCtx)) {
                    return _InvitedListSkeleton(
                      count: referral.invited.length.clamp(2, 4),
                    );
                  }
                  return _invitedList(l, gp, referral.invited);
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
          Positioned(
            bottom: 78 + MediaQuery.viewPaddingOf(context).bottom,
            left: 20,
            child: HelpButton(tips: [
              HelpTip(icon: Icons.person_add_outlined, text: l.helpHome1),
              HelpTip(icon: Icons.share_outlined, text: l.helpHome2),
              HelpTip(icon: Icons.card_giftcard_outlined, text: l.helpHome3),
            ],),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() =>
      ref.read(referralProvider.notifier).refreshFromBackend();

  Widget _codeCard(
    BuildContext context,
    AppLocalizations l,
    GpColors gp,
    ReferralState referral,
    String shareUrl,
  ) {
    final code = referral.code;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
        boxShadow: gp.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.inviteYourCode,
            style: GPText.mono(size: 10, letterSpacing: 1.6, color: gp.muted),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SelectableText(
                  code.isEmpty ? '—' : code,
                  style: GPText.display(30, color: gp.fg, height: 1.0),
                ),
              ),
              _iconAction(
                gp,
                icon: Icons.copy_rounded,
                enabled: code.isNotEmpty,
                onTap: () => _copy(context, code, l.inviteCodeCopied),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: gp.line),
          const SizedBox(height: 14),
          Text(
            l.inviteShareLink,
            style: GPText.mono(size: 10, letterSpacing: 1.6, color: gp.muted),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  shareUrl,
                  style: GPText.mono(size: 12, color: gp.mutedSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _iconAction(
                gp,
                icon: Icons.link_rounded,
                enabled: code.isNotEmpty,
                onTap: () =>
                    _copy(context, shareUrl, l.inviteLinkCopied),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconAction(
    GpColors gp, {
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GPRadius.sm),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: gp.bg3,
            borderRadius: BorderRadius.circular(GPRadius.sm),
            border: Border.all(color: gp.line),
          ),
          child: Icon(icon, size: 18, color: enabled ? gp.fg : gp.muted),
        ),
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    AppLocalizations l,
    ReferralState referral,
    String shareUrl,
  ) {
    final hasCode = referral.code.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: PillButton(
            label: l.inviteShare,
            leadingIcon: Icons.ios_share_rounded,
            // Native share sheet — hands the URL + a one-line blurb
            // off to whichever app the member picks (WhatsApp,
            // Messages, Mail, ...). Was a clipboard copy before,
            // which forced the member into a second step (open
            // their app, paste, send) for what should be a single
            // gesture.
            onPressed: hasCode
                ? () => _shareInvite(context, l, referral.code, shareUrl)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PillButton(
            label: l.inviteCopyCode,
            variant: PillVariant.secondary,
            leadingIcon: Icons.copy_rounded,
            onPressed: hasCode
                ? () => _copy(context, referral.code, l.inviteCodeCopied)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _countsRow(
    AppLocalizations l,
    GpColors gp,
    ReferralState referral,
  ) {
    final entries = <(String, int, Color)>[
      (
        l.inviteCountsPending,
        referral.countOf(ReferralStatus.pending),
        gp.accentInk,
      ),
      (
        l.inviteCountsConverted,
        referral.countOf(ReferralStatus.converted),
        GP.lime,
      ),
      (
        l.inviteCountsExpired,
        referral.countOf(ReferralStatus.expired),
        gp.muted,
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            Expanded(child: _countCell(gp, entries[i])),
            if (i < entries.length - 1)
              Container(width: 1, height: 28, color: gp.line),
          ],
        ],
      ),
    );
  }

  Widget _countCell(GpColors gp, (String, int, Color) data) {
    return Column(
      children: [
        Text(
          data.$1,
          style: GPText.mono(size: 9, letterSpacing: 1.4, color: gp.muted),
        ),
        const SizedBox(height: 6),
        Text(
          '${data.$2}',
          style: GPText.display(22, color: data.$3, height: 1.0),
        ),
      ],
    );
  }

  Widget _invitedByCard(
    AppLocalizations l,
    GpColors gp,
    String invitedByName,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 18, color: gp.accentInk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.inviteInvitedBy,
                  style: GPText.mono(
                    size: 9,
                    letterSpacing: 1.4,
                    color: gp.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  invitedByName,
                  style: GPText.body(
                    size: 14,
                    color: gp.fg,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Input so a newly-signed-up member can credit the friend who invited
  /// them. We hide the card once a claim has been recorded — only one
  /// referrer per member, matching the backend's `invited_by_user_id` FK.
  Widget _claimCard(
    AppLocalizations l,
    GpColors gp,
    ReferralState referral,
  ) {
    final canSubmit = !_claimSubmitting &&
        _claimController.text.trim().isNotEmpty &&
        referral.code.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.inviteClaimTitle,
            style: GPText.mono(size: 10, letterSpacing: 1.6, color: gp.muted),
          ),
          const SizedBox(height: 8),
          Text(
            l.inviteClaimBlurb,
            style: GPText.body(size: 13, color: gp.mutedSoft),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _claimController,
            enabled: !_claimSubmitting,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
              LengthLimitingTextInputFormatter(12),
            ],
            style: GPText.mono(size: 14, color: gp.fg, letterSpacing: 1.2),
            decoration: InputDecoration(
              hintText: l.inviteClaimInputHint,
              hintStyle: GPText.mono(size: 14, color: gp.muted),
              labelText: l.inviteClaimInputLabel,
              labelStyle: GPText.mono(
                size: 9,
                letterSpacing: 1.4,
                color: gp.muted,
              ),
              filled: true,
              fillColor: gp.bg3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GPRadius.sm),
                borderSide: BorderSide(color: gp.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GPRadius.sm),
                borderSide: BorderSide(color: gp.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GPRadius.sm),
                borderSide: BorderSide(color: gp.accentInk, width: 1.4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (canSubmit) _submitClaim(l);
            },
          ),
          const SizedBox(height: 12),
          PillButton(
            label: l.inviteClaimCta,
            leadingIcon: Icons.check_rounded,
            onPressed: canSubmit ? () => _submitClaim(l) : null,
          ),
        ],
      ),
    );
  }

  Widget _invitedList(
    AppLocalizations l,
    GpColors gp,
    List<InvitedFriend> invited,
  ) {
    if (invited.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        decoration: BoxDecoration(
          color: gp.bg2,
          borderRadius: BorderRadius.circular(GPRadius.lg),
          border: Border.all(color: gp.line),
        ),
        child: Text(
          l.inviteListEmpty,
          style: GPText.body(size: 13, color: gp.mutedSoft),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
      ),
      child: Column(
        children: invited.asMap().entries.map((entry) {
          final i = entry.key;
          final friend = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: i < invited.length - 1
                    ? BorderSide(color: gp.line)
                    : BorderSide.none,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    friend.displayName,
                    style: GPText.body(size: 14, color: gp.fg),
                  ),
                ),
                _statusChip(l, gp, friend.status),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statusChip(
    AppLocalizations l,
    GpColors gp,
    ReferralStatus status,
  ) {
    final (label, color) = switch (status) {
      ReferralStatus.pending => (l.inviteStatusPending, gp.accentInk),
      ReferralStatus.converted => (l.inviteStatusConverted, GP.lime),
      ReferralStatus.expired => (l.inviteStatusExpired, gp.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(GPRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GPText.mono(
          size: 9,
          letterSpacing: 1.4,
          color: color,
          weight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _submitClaim(AppLocalizations l) async {
    final raw = _claimController.text;
    setState(() => _claimSubmitting = true);
    final result =
        await ref.read(referralProvider.notifier).claimFriendCode(raw);
    if (!mounted) return;
    setState(() => _claimSubmitting = false);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    switch (result) {
      case ClaimCodeResult.ok:
        final name = ref.read(referralProvider).invitedByName ?? '';
        _claimController.clear();
        messenger.showSnackBar(
          SnackBar(content: Text(l.inviteClaimSuccess(name))),
        );
      case ClaimCodeResult.invalidShape:
        messenger.showSnackBar(
          SnackBar(content: Text(l.inviteClaimErrorInvalid)),
        );
      case ClaimCodeResult.notFound:
        messenger.showSnackBar(
          SnackBar(content: Text(l.inviteClaimErrorNotFound)),
        );
      case ClaimCodeResult.ownCode:
        messenger.showSnackBar(
          SnackBar(content: Text(l.inviteClaimErrorOwnCode)),
        );
      case ClaimCodeResult.alreadyClaimed:
        messenger.showSnackBar(
          SnackBar(content: Text(l.inviteClaimErrorAlready)),
        );
    }
  }

  Future<void> _copy(
    BuildContext context,
    String value,
    String confirmation,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(confirmation)));
  }

  /// Pop the OS share sheet pre-filled with the member's referral URL
  /// and a short blurb. The blurb mirrors what the page already says
  /// ("free week for them, reward for you") so the message that lands
  /// in WhatsApp / Messages reads as continuous with the page the
  /// member just shared from. The `subject` argument is only honoured
  /// by destinations that have a separate subject field (Mail, Gmail);
  /// chat apps quietly ignore it. The full text body always carries
  /// the URL plus the explanation, so the gesture works the same
  /// regardless of where it lands.
  Future<void> _shareInvite(
    BuildContext context,
    AppLocalizations l,
    String code,
    String shareUrl,
  ) async {
    final body = '${l.inviteBlurb}\n\n$shareUrl';
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await Share.share(
      body,
      subject: l.inviteOverline,
      // sharePositionOrigin is required on iPad to anchor the
      // popover to the trigger; ignored on phones. Pass the page's
      // bounds — close enough to the button to read as anchored,
      // and avoids us threading a key through the widget tree.
      sharePositionOrigin: origin,
    );
  }
}

/// Skeleton stand-in for the invited-friends list during pull-to-
/// refresh. Renders [count] placeholder rows of the same shape as
/// the live `_invitedList` rows so the page below doesn't shift.
class _InvitedListSkeleton extends StatelessWidget {
  const _InvitedListSkeleton({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final gp = context.gp;
    return Container(
      decoration: BoxDecoration(
        color: gp.bg2,
        borderRadius: BorderRadius.circular(GPRadius.lg),
        border: Border.all(color: gp.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: i < count - 1
                      ? BorderSide(color: gp.line)
                      : BorderSide.none,
                ),
              ),
              child: const Row(
                children: [
                  SkeletonBox(height: 32, width: 32, radius: 16),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 12, width: 120),
                        SizedBox(height: 6),
                        SkeletonBox(height: 9, width: 80),
                      ],
                    ),
                  ),
                  SkeletonBox(height: 10, width: 50, radius: 5),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
