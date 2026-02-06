// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_attachment.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';

const String _attachmentsSectionTitle = 'Attachments';

class CalendarAttachmentsField extends StatelessWidget {
  const CalendarAttachmentsField({
    super.key,
    required this.attachments,
    this.title = _attachmentsSectionTitle,
  });

  final List<CalendarAttachment> attachments;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(title: title),
        SizedBox(height: spacing.s),
        ...attachments.map(
          (attachment) => Padding(
            padding: EdgeInsets.only(bottom: spacing.s),
            child: _AttachmentTile(attachment: attachment),
          ),
        ),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});

  final CalendarAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final TextStyle primaryStyle =
        context.textTheme.small.strong.copyWith(color: calendarTitleColor);
    final TextStyle secondaryStyle = context.textTheme.muted.copyWith(
      color: calendarSubtitleColor,
    );
    final spacing = context.spacing;
    final String title = _attachmentTitle();
    final String? subtitle = _attachmentSubtitle();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: context.radius,
        border: Border.all(color: calendarBorderColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attach_file,
            size: spacing.m,
            color: calendarSubtitleColor,
          ),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: primaryStyle),
                if (subtitle != null) ...[
                  SizedBox(height: spacing.xxs),
                  Text(subtitle, style: secondaryStyle),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _attachmentTitle() {
    final String? label = attachment.label?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    final Uri? uri = Uri.tryParse(attachment.value);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return attachment.value;
  }

  String? _attachmentSubtitle() {
    final String? formatType = attachment.formatType?.trim();
    if (formatType != null && formatType.isNotEmpty) {
      return formatType;
    }
    final String? encoding = attachment.encoding?.trim();
    if (encoding != null && encoding.isNotEmpty) {
      return encoding;
    }
    return null;
  }
}
