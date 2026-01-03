// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/widgets.dart';

/// Placeholder widget kept for compatibility while verification flows are disabled.
class VerificationList extends StatelessWidget {
  const VerificationList({super.key, required this.jid});

  final String? jid;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
