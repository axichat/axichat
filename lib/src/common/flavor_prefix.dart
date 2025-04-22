import 'package:flutter/services.dart';

String getFlavorPrefix() => switch (appFlavor) {
      'development' => '[DEV]',
      _ => '',
    };
