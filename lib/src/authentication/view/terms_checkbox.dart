// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/legal_urls.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';

class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AxiCheckboxFormField(
        enabled: enabled,
        initialValue: false,
        inputLabel: Text(context.l10n.termsAcceptLabel),
        onChanged: (_) {},
        inputSublabel: RichText(
          text: TextSpan(
            style: context.textTheme.muted,
            children: [
              TextSpan(text: context.l10n.termsAgreementPrefix),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: AxiLink(
                  link: termsUrl,
                  text: context.l10n.termsAgreementTerms,
                ),
              ),
              TextSpan(text: context.l10n.termsAgreementAnd),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: AxiLink(
                  link: privacyUrl,
                  text: context.l10n.termsAgreementPrivacy,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        validator: (v) {
          if (v != true) {
            return context.l10n.termsAgreementError;
          }
          return null;
        },
      ),
    );
  }
}
