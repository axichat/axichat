// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
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
      builder: (_, followLink) => AxiLinkDetector(
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

class AxiLinkDetector extends StatelessWidget {
  const AxiLinkDetector({
    super.key,
    required this.onTap,
    required this.child,
  });

  final void Function()? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShadGestureDetector(
      cursor: SystemMouseCursors.click,
      hoverStrategies: mobileHoverStrategies,
      onTap: onTap,
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.lightBlueAccent,
          decoration: TextDecoration.underline,
          decorationColor: Colors.lightBlueAccent,
        ),
        child: child,
      ),
    );
  }
}
