// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/task/time_formatter.dart';
import 'package:axichat/src/calendar/view/grid/calendar_drag_payload.dart';
import 'package:axichat/src/calendar/view/shell/calendar_task_off_grid_drag_controller.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/chat/view/composer/pending_attachment_list.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DraftComposerView extends StatelessWidget {
  const DraftComposerView({
    super.key,
    required this.enabled,
    required this.showValidationMessages,
    required this.recipients,
    required this.availableChats,
    required this.rosterItems,
    required this.databaseSuggestionAddresses,
    required this.selfJid,
    required this.selfIdentity,
    required this.latestStatuses,
    required this.collapsedRecipientsByDefault,
    required this.suggestionAddresses,
    required this.suggestionDomains,
    required this.recipientAddError,
    required this.onRecipientAdded,
    required this.onRecipientRemoved,
    required this.subjectController,
    required this.subjectFocusNode,
    required this.bodyController,
    required this.bodyFocusNode,
    required this.onSubjectSubmitted,
    this.forwardedPreview,
    required this.loadingAttachments,
    required this.attachments,
    required this.addingAttachment,
    required this.onAddAttachment,
    required this.onAttachmentRetry,
    required this.onAttachmentRemove,
    required this.onAttachmentPressed,
    required this.onAttachmentPreview,
    required this.readyToSend,
    required this.sending,
    required this.onSendPressed,
    this.onSendLongPressed,
    required this.showSendBlockerMessage,
    required this.sendBlockerMessage,
    required this.sendErrorMessage,
    required this.showSendingStatus,
    required this.showAutosaveHint,
    this.autosaveEnabled = false,
    this.autosaveSaving = false,
    this.autosaveUpdating = false,
    this.onAutosaveChanged,
    required this.canDiscard,
    required this.canSave,
    required this.onDiscardPressed,
    required this.onSavePressed,
    this.visibilityLabel,
    this.tapRegionGroup,
    this.banner,
    this.subjectTrailing,
    this.onAttachmentLongPressed,
    this.pendingAttachmentMenuBuilder,
    this.disabledSendReason,
    this.onTaskDropped,
  });

  final bool enabled;
  final bool showValidationMessages;
  final List<ComposerRecipient> recipients;
  final List<Chat> availableChats;
  final List<RosterItem> rosterItems;
  final List<String> databaseSuggestionAddresses;
  final String? selfJid;
  final SelfAvatar selfIdentity;
  final Map<ComposerRecipientKey, FanOutRecipientState> latestStatuses;
  final bool collapsedRecipientsByDefault;
  final Set<String> suggestionAddresses;
  final Set<String> suggestionDomains;
  final String? Function(Contact target) recipientAddError;
  final FutureOr<bool> Function(Contact target) onRecipientAdded;
  final ValueChanged<String> onRecipientRemoved;
  final String? visibilityLabel;
  final Object? tapRegionGroup;
  final TextEditingController subjectController;
  final FocusNode subjectFocusNode;
  final TextEditingController bodyController;
  final FocusNode bodyFocusNode;
  final VoidCallback onSubjectSubmitted;
  final Widget? forwardedPreview;
  final Widget? banner;
  final Widget? subjectTrailing;
  final bool loadingAttachments;
  final bool addingAttachment;
  final List<PendingAttachment> attachments;
  final Future<void> Function()? onAddAttachment;
  final ValueChanged<PendingAttachment> onAttachmentRetry;
  final ValueChanged<String> onAttachmentRemove;
  final ValueChanged<PendingAttachment> onAttachmentPressed;
  final ValueChanged<PendingAttachment>? onAttachmentLongPressed;
  final Future<void> Function(PendingAttachment) onAttachmentPreview;
  final List<Widget> Function(PendingAttachment pending)?
  pendingAttachmentMenuBuilder;
  final bool readyToSend;
  final bool sending;
  final String? disabledSendReason;
  final VoidCallback? onSendPressed;
  final VoidCallback? onSendLongPressed;
  final bool showSendBlockerMessage;
  final String? sendBlockerMessage;
  final String? sendErrorMessage;
  final bool showSendingStatus;
  final bool showAutosaveHint;
  final bool autosaveEnabled;
  final bool autosaveSaving;
  final bool autosaveUpdating;
  final ValueChanged<bool>? onAutosaveChanged;
  final bool canDiscard;
  final bool canSave;
  final VoidCallback? onDiscardPressed;
  final VoidCallback? onSavePressed;
  final ValueChanged<CalendarDragPayload>? onTaskDropped;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final spacing = context.spacing;
    final horizontalPadding = EdgeInsets.symmetric(horizontal: spacing.m);
    final sectionSpacing = spacing.m;
    final smallGap = spacing.s;
    final onAutosaveChanged = this.onAutosaveChanged;

    return _DraftTaskDropRegion(
      onTaskDropped: enabled ? onTaskDropped : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormField<void>(
            validator: (_) => recipients.includedRecipients.isNotEmpty
                ? null
                : l10n.draftNoRecipients,
            builder: (field) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RecipientChipsBar(
                    recipients: recipients,
                    availableChats: availableChats,
                    rosterItems: rosterItems,
                    databaseSuggestionAddresses: databaseSuggestionAddresses,
                    selfJid: selfJid,
                    selfIdentity: selfIdentity,
                    recipientAddError: recipientAddError,
                    onRecipientAdded: (target) async {
                      final added = await onRecipientAdded(target);
                      if (!added) {
                        return false;
                      }
                      if (field.mounted) {
                        field.didChange(null);
                      }
                      return true;
                    },
                    onRecipientRemoved: (key) {
                      onRecipientRemoved(key);
                      if (field.mounted) {
                        field.didChange(null);
                      }
                    },
                    latestStatuses: latestStatuses,
                    collapsedByDefault: collapsedRecipientsByDefault,
                    suggestionAddresses: suggestionAddresses,
                    suggestionDomains: suggestionDomains,
                    visibilityLabel: visibilityLabel,
                    tapRegionGroup: tapRegionGroup,
                  ),
                  if (showValidationMessages && field.hasError)
                    Padding(
                      padding: EdgeInsets.only(top: spacing.s),
                      child: Text(
                        field.errorText ?? '',
                        style: textTheme.small.copyWith(
                          color: colors.destructive,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (banner case final Widget banner) ...[
            SizedBox(height: sectionSpacing),
            Padding(padding: horizontalPadding, child: banner),
          ],
          SizedBox(height: sectionSpacing),
          Padding(
            padding: horizontalPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Semantics(
                        label: l10n.draftSubjectSemantics,
                        textField: true,
                        child: AxiTextFormField(
                          controller: subjectController,
                          focusNode: subjectFocusNode,
                          enabled: enabled,
                          maxLines: 1,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => onSubjectSubmitted(),
                          leading: Text(
                            '${l10n.chatSubjectHint}: ',
                            style: textTheme.small.copyWith(
                              color: colors.mutedForeground,
                            ),
                          ),
                          trailing: subjectTrailing,
                          groupId: tapRegionGroup,
                        ),
                      ),
                    ),
                    SizedBox(width: sectionSpacing),
                    _DraftSendIconButton(
                      readyToSend: readyToSend,
                      sending: sending,
                      disabledReason: disabledSendReason,
                      onPressed: sending ? null : onSendPressed,
                      onLongPressed: sending ? null : onSendLongPressed,
                    ),
                  ],
                ),
                if (showSendBlockerMessage && sendBlockerMessage != null)
                  Padding(
                    padding: EdgeInsets.only(top: spacing.s),
                    child: Text(
                      sendBlockerMessage!,
                      style: textTheme.small.copyWith(
                        color: colors.destructive,
                      ),
                    ),
                  ),
                if (sendErrorMessage case final String message)
                  Padding(
                    padding: EdgeInsets.only(top: spacing.s),
                    child: Text(
                      message,
                      style: textTheme.small.copyWith(
                        color: colors.destructive,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: sectionSpacing),
          Padding(
            padding: horizontalPadding,
            child: _DraftAttachmentsSection(
              enabled: enabled,
              loading: loadingAttachments,
              attachments: attachments,
              addingAttachment: addingAttachment,
              onAddAttachment: onAddAttachment,
              onRetry: onAttachmentRetry,
              onRemove: onAttachmentRemove,
              onAttachmentPressed: onAttachmentPressed,
              onAttachmentLongPressed: onAttachmentLongPressed,
              onPreview: onAttachmentPreview,
              contextMenuBuilder: pendingAttachmentMenuBuilder,
            ),
          ),
          SizedBox(height: sectionSpacing),
          Padding(
            padding: horizontalPadding,
            child: Semantics(
              label: l10n.draftMessageSemantics,
              textField: true,
              child: AxiTextFormField(
                controller: bodyController,
                focusNode: bodyFocusNode,
                enabled: enabled,
                minLines: 7,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                placeholder: Text(l10n.draftMessageHint),
                groupId: tapRegionGroup,
              ),
            ),
          ),
          if (forwardedPreview case final Widget preview) ...[
            SizedBox(height: sectionSpacing),
            Padding(padding: horizontalPadding, child: preview),
          ],
          SizedBox(height: sectionSpacing),
          Padding(
            padding: horizontalPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSendingStatus)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.s),
                    child: Row(
                      children: [
                        AxiProgressIndicator(color: colors.primary),
                        SizedBox(width: smallGap),
                        Text(l10n.draftSendingStatus, style: textTheme.muted),
                      ],
                    ),
                  ),
                if (onAutosaveChanged != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.s),
                    child: _DraftAutosaveControl(
                      enabled: enabled,
                      autosaveEnabled: autosaveEnabled,
                      autosaveSaving: autosaveSaving,
                      autosaveSaved: showAutosaveHint,
                      autosaveUpdating: autosaveUpdating,
                      onChanged: onAutosaveChanged,
                    ),
                  ),
                Row(
                  children: [
                    AxiButton.destructive(
                      onPressed: canDiscard ? onDiscardPressed : null,
                      child: Text(l10n.draftDiscard),
                    ),
                    const Spacer(),
                    AxiButton.outline(
                      onPressed: canSave ? onSavePressed : null,
                      child: Text(l10n.draftSave),
                    ),
                  ],
                ),
                SizedBox(height: sectionSpacing),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftAutosaveControl extends StatelessWidget {
  const _DraftAutosaveControl({
    required this.enabled,
    required this.autosaveEnabled,
    required this.autosaveSaving,
    required this.autosaveSaved,
    required this.autosaveUpdating,
    required this.onChanged,
  });

  final bool enabled;
  final bool autosaveEnabled;
  final bool autosaveSaving;
  final bool autosaveSaved;
  final bool autosaveUpdating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.draftAutosave, style: context.textTheme.muted),
        if (autosaveSaving || autosaveSaved) ...[
          SizedBox(width: spacing.xs),
          if (autosaveSaving)
            AxiProgressIndicator(
              color: colors.primary,
              semanticsLabel: l10n.draftAutosave,
            )
          else
            Semantics(
              label: l10n.draftAutosaved,
              child: Icon(
                LucideIcons.check,
                color: colors.green,
                size: context.sizing.progressIndicatorSize,
              ),
            ),
        ],
        SizedBox(width: spacing.s),
        ShadSwitch(
          value: autosaveEnabled,
          onChanged: enabled && !autosaveSaving && !autosaveUpdating
              ? onChanged
              : null,
        ),
      ],
    );
  }
}

class _DraftTaskDropRegion extends StatelessWidget {
  const _DraftTaskDropRegion({required this.child, this.onTaskDropped});

  final Widget child;
  final ValueChanged<CalendarDragPayload>? onTaskDropped;

  @override
  Widget build(BuildContext context) {
    final onTaskDropped = this.onTaskDropped;
    if (onTaskDropped == null) {
      return child;
    }
    return _ActiveDraftTaskDropRegion(
      onTaskDropped: onTaskDropped,
      child: child,
    );
  }
}

class _ActiveDraftTaskDropRegion extends StatefulWidget {
  const _ActiveDraftTaskDropRegion({
    required this.child,
    required this.onTaskDropped,
  });

  final Widget child;
  final ValueChanged<CalendarDragPayload> onTaskDropped;

  @override
  State<_ActiveDraftTaskDropRegion> createState() =>
      _ActiveDraftTaskDropRegionState();
}

class _ActiveDraftTaskDropRegionState
    extends State<_ActiveDraftTaskDropRegion> {
  CalendarDragPayload? _hoverPayload;
  Offset? _localPosition;
  final Object _composeTaskDragHoverToken = Object();
  CalendarTaskOffGridDragController? _offGridDragController;

  RenderBox? get _box => context.findRenderObject() as RenderBox?;

  void _setComposeTaskDragHover(bool isHovering) {
    final CalendarTaskOffGridDragController? offGridDragController =
        _offGridDragController;
    if (offGridDragController == null) {
      return;
    }
    offGridDragController.setRegionActive(
      region: CalendarTaskOffGridDragRegion.composeWindow,
      token: _composeTaskDragHoverToken,
      isActive: isHovering,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final CalendarTaskOffGridDragController offGridDragController = context
        .read<CalendarTaskOffGridDragController>();
    if (_offGridDragController == offGridDragController) {
      return;
    }
    _offGridDragController?.setRegionActive(
      region: CalendarTaskOffGridDragRegion.composeWindow,
      token: _composeTaskDragHoverToken,
      isActive: false,
    );
    _offGridDragController = offGridDragController;
    if (_hoverPayload != null) {
      _offGridDragController?.setRegionActive(
        region: CalendarTaskOffGridDragRegion.composeWindow,
        token: _composeTaskDragHoverToken,
        isActive: true,
      );
    }
  }

  void _updateHover(DragTargetDetails<CalendarDragPayload> details) {
    final RenderBox? box = _box;
    final Offset local = box != null
        ? box.globalToLocal(details.offset)
        : details.offset;
    _setComposeTaskDragHover(true);
    setState(() {
      _hoverPayload = details.data;
      _localPosition = local;
    });
  }

  void _handleLeave(CalendarDragPayload? payload) {
    if (_hoverPayload == null) {
      return;
    }
    _setComposeTaskDragHover(false);
    setState(() {
      _hoverPayload = null;
      _localPosition = null;
    });
  }

  void _handleDrop(DragTargetDetails<CalendarDragPayload> details) {
    widget.onTaskDropped(details.data);
    _handleLeave(details.data);
  }

  @override
  void dispose() {
    _setComposeTaskDragHover(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final borderRadius = context.radius;
    final borderWidth = context.borderSide.width;
    final hoverAlpha = context.motion.tapHoverAlpha;
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    return DragTarget<CalendarDragPayload>(
      hitTestBehavior: HitTestBehavior.translucent,
      onWillAcceptWithDetails: (details) {
        _updateHover(details);
        return true;
      },
      onMove: _updateHover,
      onAcceptWithDetails: _handleDrop,
      onLeave: _handleLeave,
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty || _hoverPayload != null;
        final payload = _hoverPayload;
        final Offset? anchor = _localPosition;
        final RenderBox? box = _box;
        final Size? regionSize = box?.size;
        final Widget highlight = AnimatedContainer(
          duration: animationDuration,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            border: Border.all(
              color: hovering ? colors.primary : Colors.transparent,
              width: borderWidth,
            ),
            borderRadius: borderRadius,
            color: hovering
                ? colors.primary.withValues(alpha: hoverAlpha)
                : null,
          ),
          child: widget.child,
        );
        if (payload == null || anchor == null || regionSize == null) {
          return highlight;
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            highlight,
            _TaskDragGhostOverlay(
              payload: payload,
              anchor: anchor,
              regionSize: regionSize,
            ),
          ],
        );
      },
    );
  }
}

class _TaskDragGhostOverlay extends StatelessWidget {
  const _TaskDragGhostOverlay({
    required this.payload,
    required this.anchor,
    required this.regionSize,
  });

  final CalendarDragPayload payload;
  final Offset anchor;
  final Size regionSize;

  Size _ghostSize(BuildContext context) {
    final sizing = context.sizing;
    final spacing = context.spacing;
    final double defaultGhostWidth = sizing.menuMaxWidth;
    final double defaultGhostHeight = sizing.listButtonHeight + spacing.s;
    final double minGhostWidth = sizing.menuMaxWidth - spacing.l;
    final double maxGhostWidth = sizing.dialogMaxWidth;
    final double minGhostHeight = sizing.listButtonHeight + spacing.xs;
    final double maxGhostHeight = sizing.listButtonHeight * 4;
    final double width = payload.sourceBounds?.width ?? defaultGhostWidth;
    final double height = payload.sourceBounds?.height ?? defaultGhostHeight;
    return Size(
      width.clamp(minGhostWidth, maxGhostWidth),
      height.clamp(minGhostHeight, maxGhostHeight),
    );
  }

  Offset _ghostOffset(BuildContext context, Size ghostSize) {
    const double pointerClampPadding = 0.125;
    const double centerFraction = 0.5;
    final double pointerFraction =
        (payload.pointerNormalizedX ?? centerFraction)
            .clamp(0.0, 1.0)
            .toDouble();
    final double pointerOffsetY =
        (payload.pointerOffsetY ?? (ghostSize.height / 2))
            .clamp(0.0, ghostSize.height)
            .toDouble();
    double left = anchor.dx - (ghostSize.width * pointerFraction);
    double top = anchor.dy - pointerOffsetY;
    final double minLeft = -ghostSize.width * pointerClampPadding;
    final double maxLeft =
        regionSize.width - (ghostSize.width * (1 - pointerClampPadding));
    final double minTop = -ghostSize.height * pointerClampPadding;
    final double maxTop =
        regionSize.height - (ghostSize.height * pointerClampPadding);
    left = left.clamp(minLeft, maxLeft);
    top = top.clamp(minTop, maxTop);
    return Offset(left, top);
  }

  @override
  Widget build(BuildContext context) {
    final Size ghostSize = _ghostSize(context);
    final Offset offset = _ghostOffset(context, ghostSize);
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: IgnorePointer(
        child: _DraftTaskDragGhost(payload: payload, size: ghostSize),
      ),
    );
  }
}

class _DraftTaskDragGhost extends StatelessWidget {
  const _DraftTaskDragGhost({required this.payload, required this.size});

  final CalendarDragPayload payload;
  final Size size;

  String _timingLabel(BuildContext context) {
    final CalendarTask task = payload.snapshot;
    final DateTime? start = task.scheduledTime;
    final DateTime? deadline = task.deadline;
    if (start != null) {
      return TimeFormatter.formatFriendlyDateTime(context.l10n, start);
    }
    if (deadline != null) {
      return context.l10n.draftTaskDue(
        TimeFormatter.formatFriendlyDateTime(context.l10n, deadline),
      );
    }
    return context.l10n.draftTaskNoSchedule;
  }

  @override
  Widget build(BuildContext context) {
    final CalendarTask task = payload.snapshot;
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final spacing = context.spacing;
    final l10n = context.l10n;
    final String title = task.title.trim().isEmpty
        ? l10n.draftTaskUntitled
        : task.title.trim();
    final String? description = task.description?.trim().isNotEmpty == true
        ? task.description!.trim()
        : null;
    final borderRadius = context.radius;
    final shadowColor = colors.foreground.withValues(
      alpha: context.motion.tapSplashAlpha,
    );
    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: borderRadius,
      child: Container(
        width: size.width,
        constraints: BoxConstraints(minHeight: size.height),
        padding: EdgeInsets.all(spacing.m),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: borderRadius,
          border: Border.all(
            color: colors.primary,
            width: context.borderSide.width,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: context.sizing.modalShadowBlur,
              offset: Offset(0, context.sizing.modalShadowOffsetY),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.small.copyWith(color: colors.foreground),
            ),
            SizedBox(height: spacing.s),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.calendarClock,
                  size: context.sizing.menuItemIconSize,
                  color: colors.primary,
                ),
                SizedBox(width: spacing.s),
                Flexible(
                  child: Text(
                    _timingLabel(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.muted.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              SizedBox(height: spacing.s),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.muted.copyWith(color: colors.mutedForeground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DraftSendIconButton extends StatelessWidget {
  const _DraftSendIconButton({
    required this.readyToSend,
    required this.sending,
    this.disabledReason,
    required this.onPressed,
    this.onLongPressed,
  });

  final bool readyToSend;
  final bool sending;
  final String? disabledReason;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final disabledColor = colors.mutedForeground;
    final iconColor = readyToSend && !sending ? colors.primary : disabledColor;
    final borderColor = sending || !readyToSend
        ? colors.border
        : colors.primary;
    final tooltip = sending
        ? l10n.draftSendingEllipsis
        : disabledReason ?? l10n.draftSend;
    return _DraftComposerIconButton(
      tooltip: tooltip,
      icon: LucideIcons.send,
      onPressed: onPressed != null && !sending ? onPressed : null,
      onLongPressed: onLongPressed != null && !sending ? onLongPressed : null,
      loading: sending,
      iconColorOverride: iconColor,
      borderColorOverride: borderColor,
    );
  }
}

class _DraftAttachmentsSection extends StatelessWidget {
  const _DraftAttachmentsSection({
    required this.enabled,
    required this.loading,
    required this.attachments,
    required this.addingAttachment,
    required this.onAddAttachment,
    required this.onRetry,
    required this.onRemove,
    required this.onAttachmentPressed,
    required this.onAttachmentLongPressed,
    required this.onPreview,
    required this.contextMenuBuilder,
  });

  final bool enabled;
  final bool loading;
  final bool addingAttachment;
  final List<PendingAttachment> attachments;
  final Future<void> Function()? onAddAttachment;
  final ValueChanged<PendingAttachment> onRetry;
  final ValueChanged<String> onRemove;
  final ValueChanged<PendingAttachment> onAttachmentPressed;
  final ValueChanged<PendingAttachment>? onAttachmentLongPressed;
  final Future<void> Function(PendingAttachment) onPreview;
  final List<Widget> Function(PendingAttachment pending)? contextMenuBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final commandSurface = resolveCommandSurface(context);
    final useDesktopMenu = commandSurface == CommandSurface.menu;

    List<Widget> defaultMenuItems(PendingAttachment pending) {
      final actions = <AxiMenuAction>[
        AxiMenuAction(
          label: l10n.draftAttachmentPreview,
          icon: LucideIcons.eye,
          onPressed: () => onPreview(pending),
        ),
        AxiMenuAction(
          label: l10n.draftRemoveAttachment,
          icon: LucideIcons.trash2,
          destructive: true,
          onPressed: () => onRemove(pending.id),
        ),
      ];
      return [AxiMenu(actions: actions)];
    }

    Widget body;
    if (loading) {
      body = Center(
        child: AxiProgressIndicator(color: context.colorScheme.foreground),
      );
    } else if (attachments.isEmpty) {
      body = Text(l10n.draftNoAttachments, style: context.textTheme.muted);
    } else {
      body = PendingAttachmentList(
        attachments: attachments,
        onRetry: onRetry,
        onRemove: onRemove,
        onPressed: onAttachmentPressed,
        onLongPress: useDesktopMenu ? null : onAttachmentLongPressed,
        contextMenuBuilder: useDesktopMenu
            ? contextMenuBuilder ?? defaultMenuItems
            : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.draftAttachmentsLabel),
            const Spacer(),
            _DraftComposerIconButton(
              tooltip: l10n.draftAddAttachment,
              icon: LucideIcons.paperclip,
              onPressed: enabled && !addingAttachment ? onAddAttachment : null,
            ),
          ],
        ),
        SizedBox(height: context.spacing.s),
        body,
      ],
    );
  }
}

class _DraftComposerIconButton extends StatelessWidget {
  const _DraftComposerIconButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.onLongPressed,
    this.loading = false,
    this.iconColorOverride,
    this.borderColorOverride,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;
  final bool loading;
  final Color? iconColorOverride;
  final Color? borderColorOverride;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final sizing = context.sizing;
    final enabled = onPressed != null;
    final iconColor =
        iconColorOverride ??
        (enabled ? colors.foreground : colors.mutedForeground);
    final borderColor = borderColorOverride ?? colors.border;
    return AxiIconButton(
      iconData: icon,
      tooltip: tooltip,
      semanticLabel: tooltip,
      onPressed: onPressed,
      onLongPress: onLongPressed,
      loading: loading,
      color: iconColor,
      backgroundColor: colors.card,
      borderColor: borderColor,
      borderWidth: context.borderSide.width,
      cornerRadius: context.radii.squircle,
      buttonSize: sizing.iconButtonSize,
      tapTargetSize: sizing.iconButtonTapTarget,
      iconSize: sizing.iconButtonIconSize,
    );
  }
}
