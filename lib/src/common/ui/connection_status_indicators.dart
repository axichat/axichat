// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:shadcn_ui/shadcn_ui.dart';

class ConnectionStatusIndicators extends StatelessWidget {
  const ConnectionStatusIndicators({
    super.key,
    required this.xmppState,
    required this.emailState,
    required this.emailEnabled,
    this.compact = false,
    this.collapseReadyStatus = false,
  });

  final ConnectionState xmppState;
  final EmailSyncState emailState;
  final bool emailEnabled;
  final bool compact;
  final bool collapseReadyStatus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final chatChip = _chatChipData(colors, l10n);
    final emailChip = _emailChipData(colors, l10n);
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CapabilityChip(
            data: chatChip,
            compact: true,
            collapseReadyStatus: collapseReadyStatus,
          ),
          SizedBox(width: spacing.s),
          _CapabilityChip(
            data: emailChip,
            compact: true,
            collapseReadyStatus: collapseReadyStatus,
          ),
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.start,
      runAlignment: WrapAlignment.start,
      spacing: spacing.s,
      runSpacing: spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _CapabilityChip(
          data: chatChip,
          compact: false,
          collapseReadyStatus: collapseReadyStatus,
        ),
        _CapabilityChip(
          data: emailChip,
          compact: false,
          collapseReadyStatus: collapseReadyStatus,
        ),
      ],
    );
  }

  _CapabilityChipData _chatChipData(
    ShadColorScheme colors,
    AppLocalizations l10n,
  ) {
    final level = switch (xmppState) {
      ConnectionState.connected => _CapabilityLevel.ready,
      ConnectionState.connecting => _CapabilityLevel.syncing,
      ConnectionState.error => _CapabilityLevel.error,
      _ => _CapabilityLevel.offline,
    };
    final palette = _paletteForLevel(level, colors);
    return _CapabilityChipData(
      icon: LucideIcons.messageCircle,
      label: l10n.sessionCapabilityChat,
      status: _chatStatusLabel(l10n),
      background: colors.card,
      foreground: palette.foreground,
      level: level,
    );
  }

  _CapabilityChipData _emailChipData(
    ShadColorScheme colors,
    AppLocalizations l10n,
  ) {
    final level = _emailLevel();
    final palette = _paletteForLevel(level, colors);
    return _CapabilityChipData(
      icon: LucideIcons.mail,
      label: l10n.sessionCapabilityEmail,
      status: _emailStatusLabel(l10n),
      background: colors.card,
      foreground: palette.foreground,
      level: level,
    );
  }

  _CapabilityLevel _emailLevel() {
    if (!emailEnabled) return _CapabilityLevel.disabled;
    return switch (emailState.status) {
      EmailSyncStatus.ready => _CapabilityLevel.ready,
      EmailSyncStatus.recovering => _CapabilityLevel.syncing,
      EmailSyncStatus.offline => _CapabilityLevel.offline,
      EmailSyncStatus.error => _CapabilityLevel.error,
    };
  }

  String _chatStatusLabel(AppLocalizations l10n) {
    switch (xmppState) {
      case ConnectionState.connected:
        return l10n.sessionCapabilityStatusConnected;
      case ConnectionState.connecting:
        return l10n.sessionCapabilityStatusConnecting;
      case ConnectionState.error:
        return l10n.sessionCapabilityStatusError;
      default:
        return l10n.sessionCapabilityStatusOffline;
    }
  }

  String _emailStatusLabel(AppLocalizations l10n) {
    if (!emailEnabled) return l10n.sessionCapabilityStatusOff;
    switch (emailState.status) {
      case EmailSyncStatus.ready:
        return l10n.sessionCapabilityStatusConnected;
      case EmailSyncStatus.recovering:
        return l10n.sessionCapabilityStatusSyncing;
      case EmailSyncStatus.offline:
        return l10n.sessionCapabilityStatusOffline;
      case EmailSyncStatus.error:
        return l10n.sessionCapabilityStatusError;
    }
  }
}

class _CapabilityChipData {
  const _CapabilityChipData({
    required this.icon,
    required this.label,
    required this.status,
    required this.background,
    required this.foreground,
    required this.level,
  });

  final IconData icon;
  final String label;
  final String status;
  final Color background;
  final Color foreground;
  final _CapabilityLevel level;

  String get semanticsLabel => '$label $status';
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({
    required this.data,
    this.compact = false,
    this.collapseReadyStatus = false,
  });

  final _CapabilityChipData data;
  final bool compact;
  final bool collapseReadyStatus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final radii = context.radii;
    final chipPadding = compact
        ? EdgeInsets.symmetric(horizontal: spacing.s, vertical: spacing.xs)
        : EdgeInsets.symmetric(horizontal: spacing.m, vertical: spacing.s);
    final labelStyle = context.textTheme.small.copyWith(
      color: colors.foreground,
      fontWeight: FontWeight.w600,
    );
    final separatorStyle = context.textTheme.small.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    final statusStyle = context.textTheme.small.copyWith(
      color: data.foreground,
      fontWeight: FontWeight.w700,
    );
    final maxLines = compact ? 1 : 2;
    final Widget statusChild = switch (data.level) {
      _CapabilityLevel.ready when collapseReadyStatus => Container(
        width: sizing.statusDotSize,
        height: sizing.statusDotSize,
        decoration: BoxDecoration(
          color: data.foreground,
          shape: BoxShape.circle,
        ),
      ),
      _CapabilityLevel.ready => Flexible(
        fit: FlexFit.loose,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: data.label, style: labelStyle),
              TextSpan(text: ' • ', style: separatorStyle),
              TextSpan(text: data.status, style: statusStyle),
            ],
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      _CapabilityLevel.syncing => Flexible(
        fit: FlexFit.loose,
        child: Text(
          data.status,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: statusStyle,
        ),
      ),
      _ => Flexible(
        fit: FlexFit.loose,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: data.label, style: labelStyle),
              TextSpan(text: ' • ', style: separatorStyle),
              TextSpan(text: data.status, style: statusStyle),
            ],
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    };
    return Semantics(
      container: true,
      label: data.semanticsLabel,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: data.background,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(radii.squircleSm),
              side: context.borderSide,
            ),
          ),
          child: Padding(
            padding: chipPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  data.icon,
                  size: sizing.menuItemIconSize,
                  color: colors.foreground,
                ),
                SizedBox(width: spacing.xs),
                statusChild,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CapabilityPalette {
  const _CapabilityPalette({required this.foreground});

  final Color foreground;
}

enum _CapabilityLevel { ready, syncing, offline, error, disabled }

_CapabilityPalette _paletteForLevel(
  _CapabilityLevel level,
  ShadColorScheme colors,
) {
  switch (level) {
    case _CapabilityLevel.ready:
      return const _CapabilityPalette(foreground: axiGreen);
    case _CapabilityLevel.syncing:
      return _CapabilityPalette(foreground: colors.primary);
    case _CapabilityLevel.offline:
    case _CapabilityLevel.disabled:
      return _CapabilityPalette(foreground: colors.mutedForeground);
    case _CapabilityLevel.error:
      return _CapabilityPalette(foreground: colors.destructive);
  }
}
