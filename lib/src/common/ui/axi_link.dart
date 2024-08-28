import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/link.dart';

class AxiLink extends StatelessWidget {
  const AxiLink({
    super.key,
    required this.text,
    required this.link,
  });

  final String text;
  final String link;

  @override
  Widget build(BuildContext context) {
    return Link(
      uri: Uri.parse(link),
      builder: (_, followLink) => ShadGestureDetector(
        cursor: SystemMouseCursors.click,
        hoverStrategies: mobileHoverStrategies,
        onTap: followLink,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.lightBlueAccent,
            decoration: TextDecoration.underline,
            decorationColor: Colors.lightBlueAccent,
          ),
        ),
      ),
    );
  }
}
