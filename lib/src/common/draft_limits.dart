// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/message_content_limits.dart';

const int draftSyncMaxItems = 50;
const int draftSyncWarningThreshold = 40;
const int draftSyncMaxRecipients = 20;
const int draftSyncMaxRecipientBytes = 512;
const int draftSyncMaxAttachments = 50;
const int draftSyncMaxIdBytes = 64;
const int draftSyncMaxAttachmentNameBytes = 120;
const int draftSyncMaxAttachmentMimeBytes = 128;
const int draftSyncMaxAttachmentUrlBytes = 2048;
const int draftSyncMaxAttachmentSizeBytes = 50 * 1024 * 1024;
const int draftSyncMaxSubjectBytes = 998;
const int draftSyncMaxBodyBytes = maxMessageTextBytes;
const int draftSyncMaxHtmlBytes = maxMessageHtmlBytes;
const Set<String> draftSyncAllowedRecipientRoles = <String>{
  'to',
  'cc',
  'bcc',
};
const Set<String> draftSyncAllowedAttachmentSchemes = <String>{
  'http',
  'https',
};
