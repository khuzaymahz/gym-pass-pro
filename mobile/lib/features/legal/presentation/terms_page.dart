import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'legal_page.dart';

/// Terms of Service.
///
/// Section count + headlines are wired here; copy lives in the ARB
/// files so AR/EN are first-class. Future legal review should
/// adjust the ARB strings without touching this file.
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LegalPage(
      title: l.termsTitle,
      subtitle: l.termsSubtitle,
      lastUpdatedLabel: l.legalLastUpdated,
      lastUpdated: l.termsUpdatedAt,
      sections: [
        LegalSection(
          headline: l.termsAcceptanceHeadline,
          body: l.termsAcceptanceBody,
        ),
        LegalSection(
          headline: l.termsAccountHeadline,
          body: l.termsAccountBody,
        ),
        LegalSection(
          headline: l.termsMembershipHeadline,
          body: l.termsMembershipBody,
        ),
        LegalSection(
          headline: l.termsPaymentHeadline,
          body: l.termsPaymentBody,
        ),
        LegalSection(
          headline: l.termsCheckinHeadline,
          body: l.termsCheckinBody,
        ),
        LegalSection(
          headline: l.termsConductHeadline,
          body: l.termsConductBody,
        ),
        LegalSection(
          headline: l.termsTerminationHeadline,
          body: l.termsTerminationBody,
        ),
        LegalSection(
          headline: l.termsLiabilityHeadline,
          body: l.termsLiabilityBody,
        ),
        LegalSection(
          headline: l.termsChangesHeadline,
          body: l.termsChangesBody,
        ),
        LegalSection(
          headline: l.termsContactHeadline,
          body: l.termsContactBody,
        ),
      ],
    );
  }
}
