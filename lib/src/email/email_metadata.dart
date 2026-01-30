// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

/// Returns the deterministic file metadata id we use to link Delta Chat
/// messages to their attachment rows in the database. Keeping the id stable
/// lets us upsert metadata if a message is rehydrated.
String deltaFileMetadataId(int messageId) {
  const prefix = 'dc-file-';
  return '$prefix$messageId';
}
