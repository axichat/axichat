// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/folders/view/folder_messages_list.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';

class ImportantMessagesList extends StatelessWidget {
  const ImportantMessagesList({
    super.key,
    this.showChatLabel = false,
    this.onPressed,
  });

  final bool showChatLabel;
  final ValueChanged<FolderMessageItem>? onPressed;

  @override
  Widget build(BuildContext context) {
    return FolderMessagesList(
      emptyLabel: context.l10n.importantMessagesEmpty,
      showChatLabel: showChatLabel,
      showImportantMarker: true,
      onPressed: onPressed,
    );
  }
}
