// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/attachments/view/attachment_file_preview.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<void> showPendingAttachmentPreview({
  required BuildContext context,
  required PendingAttachment pending,
  required VoidCallback onRemove,
  required String removeTooltip,
  String? closeTooltip,
}) async {
  if (!context.mounted) return;
  final l10n = context.l10n;
  final closeLabel = closeTooltip ?? l10n.commonClose;
  final file = File(pending.attachment.path);
  final exists = await file.exists();
  if (!context.mounted) return;
  if (!exists) {
    showAttachmentPreviewToast(
      context,
      l10n.chatAttachmentUnavailable,
      destructive: true,
    );
    return;
  }

  final report = await inspectFileType(
    file: file,
    declaredMimeType: pending.attachment.mimeType,
    fileName: pending.attachment.fileName,
  );
  if (!context.mounted) return;
  final previewData = await resolveAttachmentPreviewData(
    file: file,
    attachment: pending.attachment,
    typeReport: report,
  );
  if (!context.mounted) return;
  final dialogData = previewData?.kind.opensDialog == true
      ? previewData!
      : AttachmentPreviewData.unsupported(
          file: file,
          attachment: pending.attachment,
          report: report,
        );

  await showAttachmentPreviewDialog(
    context: context,
    data: dialogData,
    closeTooltip: closeLabel,
    actions: [
      AttachmentPreviewDialogAction(
        iconData: LucideIcons.trash2,
        tooltip: removeTooltip,
        destructive: true,
        onPressed: (dialogContext) {
          Navigator.of(dialogContext).pop();
          onRemove();
        },
      ),
    ],
  );
}

void showAttachmentPreviewToast(
  BuildContext context,
  String message, {
  bool destructive = false,
}) {
  final l10n = context.l10n;
  final toaster = ShadToaster.maybeOf(context);
  final toast = destructive
      ? FeedbackToast.error(title: l10n.toastWhoopsTitle, message: message)
      : FeedbackToast.info(title: l10n.toastHeadsUpTitle, message: message);
  toaster?.show(toast);
}
