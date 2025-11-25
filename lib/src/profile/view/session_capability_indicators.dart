import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
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
    final chatChip = _chatChipData(colors);
    final emailChip = _emailChipData(colors);
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

  _CapabilityChipData _chatChipData(ShadColorScheme colors) {
    final level = switch (xmppState) {
      ConnectionState.connected => _CapabilityLevel.ready,
      ConnectionState.connecting => _CapabilityLevel.syncing,
      ConnectionState.error => _CapabilityLevel.error,
      _ => _CapabilityLevel.offline,
    };
    final palette = _paletteForLevel(level, colors);
    return _CapabilityChipData(
      icon: LucideIcons.messageCircle,
      label: 'Chat',
      status: _chatStatusLabel(),
      background: palette.background,
      foreground: palette.foreground,
    );
  }

  _CapabilityChipData _emailChipData(ShadColorScheme colors) {
    final level = _emailLevel();
    final palette = _paletteForLevel(level, colors);
    return _CapabilityChipData(
      icon: LucideIcons.mail,
      label: 'Email',
      status: _emailStatusLabel(),
      background: palette.background,
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

  String _chatStatusLabel() {
    switch (xmppState) {
      case ConnectionState.connected:
        return 'Connected';
      case ConnectionState.connecting:
        return 'Connecting';
      case ConnectionState.error:
        return 'Error';
      default:
        return 'Offline';
    }
  }

  String _emailStatusLabel() {
    if (!emailEnabled) return 'Off';
    switch (emailState.status) {
      case EmailSyncStatus.ready:
        return 'Connected';
      case EmailSyncStatus.recovering:
        return 'Syncing';
      case EmailSyncStatus.offline:
        return 'Offline';
      case EmailSyncStatus.error:
        return 'Error';
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
    final chipPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: data.background,
        shape: SquircleBorder(cornerRadius: 12),
      ),
      child: Padding(
        padding: chipPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, size: 14, color: data.foreground),
            const SizedBox(width: 6),
            Text(
              '${data.label} • ${data.status}',
              style: context.textTheme.small.copyWith(
                color: data.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityPalette {
  const _CapabilityPalette({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

enum _CapabilityLevel { ready, syncing, offline, error, disabled }

_CapabilityPalette _paletteForLevel(
  _CapabilityLevel level,
  ShadColorScheme colors,
) {
  switch (level) {
    case _CapabilityLevel.ready:
      return _CapabilityPalette(
        background: colors.primary.withValues(alpha: 0.12),
        foreground: colors.primary,
      );
    case _CapabilityLevel.syncing:
      return _CapabilityPalette(
        background: colors.muted.withValues(alpha: 0.2),
        foreground: colors.mutedForeground,
      );
    case _CapabilityLevel.offline:
    case _CapabilityLevel.disabled:
      return _CapabilityPalette(
        background: colors.muted.withValues(alpha: 0.14),
        foreground: colors.mutedForeground,
      );
    case _CapabilityLevel.error:
      return _CapabilityPalette(
        background: colors.destructive.withValues(alpha: 0.14),
        foreground: colors.destructive,
      );
  }
}
