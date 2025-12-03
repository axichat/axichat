import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:shadcn_ui/shadcn_ui.dart';

const _capabilityChipSpacing = 8.0;
const _capabilityChipRunSpacing = 6.0;

class SessionCapabilityIndicators extends StatelessWidget {
  const SessionCapabilityIndicators({
    super.key,
    required this.xmppState,
    required this.emailState,
    required this.emailEnabled,
    this.compact = false,
  });

  final ConnectionState xmppState;
  final EmailSyncState emailState;
  final bool emailEnabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final chatChip = _chatChipData(colors, l10n);
    final emailChip = _emailChipData(colors, l10n);
    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: _capabilityChipRunSpacing,
        children: [
          _CapabilityChip(data: chatChip, compact: true),
          _CapabilityChip(data: emailChip, compact: true),
        ],
      );
    }
    final chipAlignment = compact ? WrapAlignment.end : WrapAlignment.start;
    const double runSpacing = _capabilityChipRunSpacing;
    return Wrap(
      alignment: chipAlignment,
      runAlignment: chipAlignment,
      spacing: _capabilityChipSpacing,
      runSpacing: runSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _CapabilityChip(data: chatChip, compact: compact),
        _CapabilityChip(data: emailChip, compact: compact),
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
  });

  final IconData icon;
  final String label;
  final String status;
  final Color background;
  final Color foreground;
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.data, this.compact = false});

  final _CapabilityChipData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final chipPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: data.background,
        shape: SquircleBorder(
          cornerRadius: 12,
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: chipPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, size: 14, color: colors.foreground),
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.label,
                  style: context.textTheme.small.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  ' • ',
                  style: context.textTheme.small.copyWith(
                    color: colors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  data.status,
                  style: context.textTheme.small.copyWith(
                    color: data.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityPalette {
  const _CapabilityPalette({
    required this.foreground,
  });

  final Color foreground;
}

enum _CapabilityLevel { ready, syncing, offline, error, disabled }

_CapabilityPalette _paletteForLevel(
  _CapabilityLevel level,
  ShadColorScheme colors,
) {
  switch (level) {
    case _CapabilityLevel.ready:
      return const _CapabilityPalette(
        foreground: axiGreen,
      );
    case _CapabilityLevel.syncing:
      return _CapabilityPalette(
        foreground: colors.primary,
      );
    case _CapabilityLevel.offline:
    case _CapabilityLevel.disabled:
      return _CapabilityPalette(
        foreground: colors.mutedForeground,
      );
    case _CapabilityLevel.error:
      return _CapabilityPalette(
        foreground: colors.destructive,
      );
  }
}
