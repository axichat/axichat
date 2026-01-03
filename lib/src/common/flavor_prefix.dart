// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/services.dart';

String getFlavorPrefix() => switch (appFlavor) {
      'development' => '[DEV]',
      _ => '',
    };
