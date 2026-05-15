import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'legal_page.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LegalPage(
      title: l.privacyTitle,
      subtitle: l.privacySubtitle,
      lastUpdatedLabel: l.legalLastUpdated,
      lastUpdated: l.privacyUpdatedAt,
      sections: [
        LegalSection(
          headline: l.privacyDataWeCollectHeadline,
          body: l.privacyDataWeCollectBody,
        ),
        LegalSection(
          headline: l.privacyPurposeHeadline,
          body: l.privacyPurposeBody,
        ),
        LegalSection(
          headline: l.privacySharingHeadline,
          body: l.privacySharingBody,
        ),
        LegalSection(
          headline: l.privacyMaskingHeadline,
          body: l.privacyMaskingBody,
        ),
        LegalSection(
          headline: l.privacyRetentionHeadline,
          body: l.privacyRetentionBody,
        ),
        LegalSection(
          headline: l.privacySecurityHeadline,
          body: l.privacySecurityBody,
        ),
        LegalSection(
          headline: l.privacyRightsHeadline,
          body: l.privacyRightsBody,
        ),
        LegalSection(
          headline: l.privacyChildrenHeadline,
          body: l.privacyChildrenBody,
        ),
        LegalSection(
          headline: l.privacyChangesHeadline,
          body: l.privacyChangesBody,
        ),
        LegalSection(
          headline: l.privacyContactHeadline,
          body: l.privacyContactBody,
        ),
      ],
    );
  }
}
