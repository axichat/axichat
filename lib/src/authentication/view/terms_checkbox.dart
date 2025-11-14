import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

const termsUrl = 'https://axichat.com/terms.pdf';
const privacyUrl = 'https://axichat.com/privacy.pdf';

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
        inputLabel: const Text('I accept the terms and conditions'),
        onChanged: (_) {},
        inputSublabel: RichText(
          text: TextSpan(
            style: context.textTheme.muted,
            children: const [
              TextSpan(
                text: 'You agree to our ',
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: AxiLink(
                  link: termsUrl,
                  text: 'terms',
                ),
              ),
              TextSpan(
                text: ' and ',
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: AxiLink(
                  link: privacyUrl,
                  text: 'privacy policy',
                ),
              ),
              TextSpan(
                text: '.',
              ),
            ],
          ),
        ),
        validator: (v) {
          if (v != true) {
            return 'You must accept the terms and conditions';
          }
          return null;
        },
      ),
    );
  }
}
