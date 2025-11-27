import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';

const termsUrl = 'https://axichat.com/terms.pdf';
const privacyUrl = 'https://axichat.com/privacy.pdf';

class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.centerLeft,
      child: AxiCheckboxFormField(
        enabled: enabled,
        initialValue: false,
        inputLabel: Text(l10n.termsAcceptLabel),
        onChanged: (_) {},
        inputSublabel: RichText(
          text: TextSpan(
            style: context.textTheme.muted,
            children: [
              TextSpan(
                text: l10n.termsAgreementPrefix,
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: AxiLink(
                  link: termsUrl,
                  text: l10n.termsAgreementTerms,
                ),
              ),
              TextSpan(
                text: l10n.termsAgreementAnd,
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: AxiLink(
                  link: privacyUrl,
                  text: l10n.termsAgreementPrivacy,
                ),
              ),
              const TextSpan(
                text: '.',
              ),
            ],
          ),
        ),
        validator: (v) {
          if (v != true) {
            return l10n.termsAgreementError;
          }
          return null;
        },
      ),
    );
  }
}
