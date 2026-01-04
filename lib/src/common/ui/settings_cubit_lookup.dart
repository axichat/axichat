// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

SettingsCubit? maybeSettingsCubit(BuildContext context) {
  try {
    return context.read<SettingsCubit>();
  } on FlutterError {
    return null;
  }
}
