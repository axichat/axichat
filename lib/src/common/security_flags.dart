// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

// Build-time security toggles.
//
// These should only be used for development and never enabled in release.

const String kAllowInsecureEmailProvisioningDefine =
    'ALLOW_INSECURE_EMAIL_PROVISIONING';

const bool kAllowInsecureEmailProvisioning = bool.fromEnvironment(
  kAllowInsecureEmailProvisioningDefine,
  defaultValue: false,
);

const String kAllowInsecureXmppHttpUploadSlotsDefine =
    'ALLOW_INSECURE_XMPP_HTTP_UPLOAD_SLOTS';

const bool kAllowInsecureXmppHttpUploadSlots = bool.fromEnvironment(
  kAllowInsecureXmppHttpUploadSlotsDefine,
  defaultValue: false,
);

const String kAllowInsecureXmppAttachmentDownloadsDefine =
    'ALLOW_INSECURE_XMPP_ATTACHMENT_DOWNLOADS';

const bool kAllowInsecureXmppAttachmentDownloads = bool.fromEnvironment(
  kAllowInsecureXmppAttachmentDownloadsDefine,
  defaultValue: false,
);
