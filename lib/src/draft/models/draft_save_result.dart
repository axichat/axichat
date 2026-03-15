// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/models/file_models.dart';

class DraftSaveResult {
  const DraftSaveResult({
    this.draft,
    int? draftId,
    List<String> attachmentMetadataIds = const <String>[],
    required this.draftCount,
  }) : assert(draft != null || draftId != null),
       _draftId = draftId,
       _attachmentMetadataIds = attachmentMetadataIds;

  final Draft? draft;
  final int draftCount;
  final int? _draftId;
  final List<String> _attachmentMetadataIds;

  int get draftId => draft?.id ?? _draftId!;

  List<String> get attachmentMetadataIds =>
      draft?.attachmentMetadata.values ??
      List<String>.unmodifiable(_attachmentMetadataIds);
}
