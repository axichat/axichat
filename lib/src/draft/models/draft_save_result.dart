// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

class DraftSaveResult {
  const DraftSaveResult({
    required this.draftId,
    required this.attachmentMetadataIds,
    required this.draftCount,
  });

  final int draftId;
  final List<String> attachmentMetadataIds;
  final int draftCount;
}
