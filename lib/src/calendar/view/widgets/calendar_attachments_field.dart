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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(title: title),
        const SizedBox(height: calendarGutterSm),
        ...attachments.map(
          (attachment) => Padding(
            padding: const EdgeInsets.only(bottom: calendarInsetLg),
            child: _AttachmentTile(attachment: attachment),
          ),
        ),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
  });

  final CalendarAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final TextStyle primaryStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );
    final TextStyle secondaryStyle = context.textTheme.muted.copyWith(
      color: calendarSubtitleColor,
    );
    final String title = _attachmentTitle();
    final String? subtitle = _attachmentSubtitle();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetMd,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attach_file,
            size: calendarGutterLg,
            color: calendarSubtitleColor,
          ),
          const SizedBox(width: calendarInsetMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: primaryStyle),
                if (subtitle != null) ...[
                  const SizedBox(height: calendarInsetSm),
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
