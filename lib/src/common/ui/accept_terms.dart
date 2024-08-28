import 'package:chat/src/app.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const termsUrl = 'https://axichat.com/terms.pdf';
const privacyUrl = 'https://axichat.com/privacy.pdf';

Future<bool?> acceptTerms(BuildContext context) => showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Confirm'),
        content: RichText(
          text: TextSpan(
            style: context.textTheme.small,
            children: const [
              TextSpan(
                text: 'By continuing, you agree to the ',
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
            ],
          ),
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => context.pop(false),
            text: const Text('Return'),
          ),
          ShadButton(
            onPressed: () => context.pop(true),
            text: const Text('Continue'),
          )
        ],
      ),
    );
