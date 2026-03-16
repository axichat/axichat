// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const axiGreen = Color(0xFF00C853);
const axiWarning = Color(0xFFFD7E14);

extension AxiStatusColors on ShadColorScheme {
  Color get green => axiGreen;

  Color get warning => axiWarning;
}
