// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

const TextSpan _emptyDetailsText = TextSpan(text: '');

class ChatInlineDetails extends StatelessWidget {
  const ChatInlineDetails({
    super.key,
    required this.details,
  });

  final List<InlineSpan> details;

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) {
      return const SizedBox.shrink();
    }
    return DynamicInlineText(
      text: _emptyDetailsText,
      details: details,
    );
  }
}
