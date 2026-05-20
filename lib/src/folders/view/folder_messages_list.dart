// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/view/timeline/message/bubble_surface.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class FolderMessagesList extends StatelessWidget {
  const FolderMessagesList({
    super.key,
    required this.emptyLabel,
    this.showChatLabel = false,
    this.showImportantMarker = false,
    this.collapseLongEmails = false,
    this.onPressed,
    this.onRemovePressed,
  });

  final String emptyLabel;
  final bool showChatLabel;
  final bool showImportantMarker;
  final bool collapseLongEmails;
  final ValueChanged<FolderMessageItem>? onPressed;
  final Future<bool> Function(FolderMessageItem item)? onRemovePressed;

  @override
  Widget build(BuildContext context) {
    return BlocListener<FoldersCubit, FoldersState>(
      listenWhen: (previous, current) => previous.actionId != current.actionId,
      listener: (context, state) {
        final actionState = state.actionState;
        if (actionState is! FoldersActionFailure ||
            actionState.action != FoldersActionType.removeMembership) {
          return;
        }
        final toaster = ShadToaster.maybeOf(context);
        if (toaster != null) {
          toaster.show(
            FeedbackToast.error(
              message: context.l10n.folderRemoveMessageFailed,
            ),
          );
          return;
        }
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.folderRemoveMessageFailed)),
        );
      },
      child: BlocBuilder<FoldersCubit, FoldersState>(
        builder: (context, state) {
          final items = state.visibleItems;
          if (items == null) {
            return Center(
              child: AxiProgressIndicator(
                color: context.colorScheme.foreground,
              ),
            );
          }
          if (items.isEmpty) {
            return Center(
              child: Text(emptyLabel, style: context.textTheme.muted),
            );
          }
          final actionState = state.actionState;
          return ListView.builder(
            padding: EdgeInsets.only(
              top: context.spacing.m,
              bottom: context.spacing.xxl,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _FolderMessageTile(
                item: item,
                showChatLabel: showChatLabel,
                showImportantMarker: showImportantMarker,
                collapseLongEmails: collapseLongEmails,
                timestampLabel: _folderTimestampLabel(
                  context,
                  item.markedAt.toLocal(),
                ),
                removing:
                    actionState is FoldersActionLoading &&
                    actionState.action == FoldersActionType.removeMembership &&
                    actionState.collectionId == item.collectionId.trim() &&
                    actionState.chatJid == item.chatJid.trim() &&
                    actionState.messageReferenceId ==
                        item.messageReferenceId.trim(),
                onPressed: onPressed == null ? null : () => onPressed!(item),
                onRemovePressed: item.isContactRuleDerived
                    ? null
                    : onRemovePressed,
              );
            },
          );
        },
      ),
    );
  }
}

bool _folderMessageItemIsEmail(FolderMessageItem item) {
  final message = item.message;
  return message?.deltaChatId != null ||
      message?.deltaMsgId != null ||
      item.chat?.defaultTransport == MessageTransport.email;
}

String _folderMessagePreviewText(
  BuildContext context,
  FolderMessageItem item, {
  required bool isEmailMessage,
  required bool collapseLongEmails,
}) {
  final message = item.message;
  if (message == null) {
    return context.l10n.chatPinnedMissingMessage;
  }
  final body = message.body;
  final subject = message.subject;
  final preview = isEmailMessage
      ? ChatSubjectCodec.previewEmailText(body: body, subject: subject)
      : ChatSubjectCodec.previewText(body: body, subject: subject);
  final normalized = preview?.trim();
  if (normalized == null || normalized.isEmpty) {
    return context.l10n.chatPinnedMissingMessage;
  }
  if (collapseLongEmails && isEmailMessage) {
    return ChatSubjectCodec.collapsedEmailPreviewText(normalized);
  }
  return normalized;
}

String _folderTimestampLabel(BuildContext context, DateTime timestamp) {
  final material = MaterialLocalizations.of(context);
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(timestamp),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '${material.formatShortDate(timestamp)} $time';
}

class _FolderMessageTile extends StatefulWidget {
  const _FolderMessageTile({
    required this.item,
    required this.showChatLabel,
    required this.showImportantMarker,
    required this.collapseLongEmails,
    required this.timestampLabel,
    required this.removing,
    this.onPressed,
    this.onRemovePressed,
  });

  final FolderMessageItem item;
  final bool showChatLabel;
  final bool showImportantMarker;
  final bool collapseLongEmails;
  final String timestampLabel;
  final bool removing;
  final VoidCallback? onPressed;
  final Future<bool> Function(FolderMessageItem item)? onRemovePressed;

  @override
  State<_FolderMessageTile> createState() => _FolderMessageTileState();
}

class _FolderMessageTileState extends State<_FolderMessageTile> {
  static const int _collapsedEmailPreviewMaxLines = 2;
  static const int _expandedPreviewMaxLines = 5;

  var _hovered = false;
  var _focused = false;

  void _remove() {
    final onRemovePressed = widget.onRemovePressed;
    if (onRemovePressed == null || widget.removing) {
      return;
    }
    unawaited(onRemovePressed(widget.item));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final chatTheme = context.chatTheme;
    final enabled = widget.onPressed != null;
    final highlighted = _hovered || _focused;
    final isEmailMessage = _folderMessageItemIsEmail(widget.item);
    final preview = _folderMessagePreviewText(
      context,
      widget.item,
      isEmailMessage: isEmailMessage,
      collapseLongEmails: widget.collapseLongEmails,
    );
    final message = widget.item.message;
    final trusted = message?.trusted;
    final chatLabel = widget.item.chat?.title.trim().isNotEmpty == true
        ? widget.item.chat!.title
        : widget.item.chatJid;
    final previewStyle = context.textTheme.small.copyWith(
      color: message == null ? colors.mutedForeground : colors.foreground,
    );
    final detailStyle = context.textTheme.muted.copyWith(
      color: colors.mutedForeground,
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
      if (widget.showImportantMarker)
        iconDetailSpan(Icons.star_rounded, colors.primary),
      if (trusted != null)
        iconDetailSpan(
          trusted.toShieldIcon,
          trusted ? axiGreen : colors.destructive,
        ),
    ];

    final previewText = Text(
      preview,
      style: previewStyle,
      maxLines: widget.collapseLongEmails && isEmailMessage
          ? _collapsedEmailPreviewMaxLines
          : _expandedPreviewMaxLines,
      overflow: TextOverflow.ellipsis,
    );
    final body = widget.onRemovePressed == null
        ? previewText
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: previewText),
              SizedBox(width: spacing.s),
              AxiIconButton.ghost(
                iconData: LucideIcons.folderMinus,
                tooltip: context.l10n.folderRemoveMessage,
                semanticLabel: context.l10n.folderRemoveMessage,
                iconSize: sizing.menuItemIconSize,
                buttonSize: sizing.iconButtonSize,
                tapTargetSize: sizing.iconButtonTapTarget,
                loading: widget.removing,
                onPressed: widget.removing ? null : _remove,
              ),
            ],
          );
    final bubble = ChatBubbleSurface(
      isSelf: false,
      backgroundColor: highlighted ? colors.secondary : colors.card,
      borderColor: highlighted ? colors.primary : chatTheme.recvEdge,
      borderRadius: context.radius,
      body: Padding(
        padding: EdgeInsets.all(spacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            body,
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
          constraints: BoxConstraints(maxWidth: sizing.dialogMaxWidth),
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
