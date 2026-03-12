// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/chat/view/chat_bubble_surface.dart';
import 'package:axichat/src/chat/view/widgets/chat_inline_details.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/important/bloc/important_messages_cubit.dart';
import 'package:axichat/src/important/models/important_message_item.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ImportantMessagesList extends StatelessWidget {
  const ImportantMessagesList({
    super.key,
    this.showChatLabel = false,
    this.onPressed,
  });

  final bool showChatLabel;
  final ValueChanged<ImportantMessageItem>? onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImportantMessagesCubit, ImportantMessagesState>(
      builder: (context, state) {
        final items = state.visibleItems;
        if (items == null) {
          return Center(
            child: AxiProgressIndicator(color: context.colorScheme.foreground),
          );
        }
        if (items.isEmpty) {
          return Center(
            child: Text(
              context.l10n.importantMessagesEmpty,
              style: context.textTheme.muted,
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.only(
            top: context.spacing.m,
            bottom: context.spacing.xxl,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _ImportantMessageTile(
              item: item,
              showChatLabel: showChatLabel,
              timestampLabel: _importantTimestampLabel(
                context,
                item.markedAt.toLocal(),
              ),
              onPressed: onPressed == null ? null : () => onPressed!(item),
            );
          },
        );
      },
    );
  }
}

String _importantMessagePreviewText(
  BuildContext context,
  ImportantMessageItem item,
) {
  final message = item.message;
  if (message == null) {
    return context.l10n.chatPinnedMissingMessage;
  }
  final body = message.body;
  final subject = message.subject;
  final isEmailMessage =
      message.deltaChatId != null || message.deltaMsgId != null;
  final preview = isEmailMessage
      ? ChatSubjectCodec.previewEmailText(body: body, subject: subject)
      : ChatSubjectCodec.previewText(body: body, subject: subject);
  final normalized = preview?.trim();
  if (normalized == null || normalized.isEmpty) {
    return context.l10n.chatPinnedMissingMessage;
  }
  return normalized;
}

String _importantTimestampLabel(BuildContext context, DateTime timestamp) {
  final material = MaterialLocalizations.of(context);
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(timestamp),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '${material.formatShortDate(timestamp)} $time';
}

class _ImportantMessageTile extends StatefulWidget {
  const _ImportantMessageTile({
    required this.item,
    required this.showChatLabel,
    required this.timestampLabel,
    this.onPressed,
  });

  final ImportantMessageItem item;
  final bool showChatLabel;
  final String timestampLabel;
  final VoidCallback? onPressed;

  @override
  State<_ImportantMessageTile> createState() => _ImportantMessageTileState();
}

class _ImportantMessageTileState extends State<_ImportantMessageTile> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final chatTheme = context.chatTheme;
    final enabled = widget.onPressed != null;
    final highlighted = _hovered || _focused;
    final preview = _importantMessagePreviewText(context, widget.item);
    final message = widget.item.message;
    final trusted = message?.trusted;
    final chatLabel = widget.item.chat?.title.trim().isNotEmpty == true
        ? widget.item.chat!.title
        : widget.item.chatJid;
    final isEmailMessage =
        message?.deltaChatId != null ||
        message?.deltaMsgId != null ||
        widget.item.chat?.defaultTransport.isEmail == true;
    final previewStyle = context.textTheme.small.copyWith(
      color: message == null ? colors.mutedForeground : colors.foreground,
      height: 1.3,
    );
    final detailStyle = context.textTheme.muted.copyWith(
      color: colors.mutedForeground,
      height: 1.0,
      textBaseline: TextBaseline.alphabetic,
    );
    final transportIconData = isEmailMessage
        ? LucideIcons.mail
        : LucideIcons.messageCircle;
    TextSpan iconDetailSpan(IconData icon, Color color) => TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: detailStyle.copyWith(
        color: color,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    );
    final detailSpans = <InlineSpan>[
      TextSpan(text: widget.timestampLabel, style: detailStyle),
      iconDetailSpan(transportIconData, colors.mutedForeground),
      iconDetailSpan(Icons.star_rounded, colors.primary),
      if (trusted != null)
        iconDetailSpan(
          trusted.toShieldIcon,
          trusted ? axiGreen : colors.destructive,
        ),
    ];

    final bubble = ChatBubbleSurface(
      isSelf: false,
      backgroundColor: highlighted ? colors.secondary : colors.card,
      borderColor: highlighted ? colors.primary : chatTheme.recvEdge,
      borderRadius: context.radius,
      shadowOpacity: 0,
      shadows: const <BoxShadow>[],
      bubbleWidthFraction: 1.0,
      cornerClearance: 0,
      body: Padding(
        padding: EdgeInsets.all(spacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview,
              style: previewStyle,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: spacing.s),
            ChatInlineDetails(details: detailSpans),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.m,
        vertical: spacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sizing.dialogMaxWidth),
          child: ShadFocusable(
            canRequestFocus: enabled,
            onFocusChange: (value) => setState(() => _focused = value),
            builder: (context, focused, child) =>
                child ?? const SizedBox.shrink(),
            child: ShadGestureDetector(
              cursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              hoverStrategies: ShadTheme.of(context).hoverStrategies,
              onHoverChange: (value) => setState(() => _hovered = value),
              onTap: widget.onPressed,
              child: AxiTapBounce(
                enabled: enabled,
                child: Material(
                  color: Colors.transparent,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: context.radius,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showChatLabel)
                        Padding(
                          padding: EdgeInsets.only(
                            left: spacing.m,
                            right: spacing.m,
                            bottom: spacing.xs,
                          ),
                          child: Text(
                            chatLabel,
                            style: context.textTheme.small.copyWith(
                              color: colors.mutedForeground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      bubble,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
