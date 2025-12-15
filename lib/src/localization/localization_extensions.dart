import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

extension LocalizationX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
