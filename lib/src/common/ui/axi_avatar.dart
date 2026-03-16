// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AxiAvatarShape { circle, squircle }

class AxiAvatar extends StatelessWidget {
  const AxiAvatar({
    super.key,
    required this.avatar,
    this.subscription = Subscription.none,
    this.presence,
    this.status,
    this.active = false,
    this.shape = AxiAvatarShape.squircle,
    this.size = 50.0,
    this.avatarBytes,
  });

  final AvatarPresentation avatar;
  final Subscription subscription;
  final Presence? presence;
  final String? status;
  final bool active;
  final AxiAvatarShape shape;
  final double size;
  final Uint8List? avatarBytes;

  static const double paddingFraction = 0.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final motion = context.motion;
    final radii = context.radii;
    final sizing = context.sizing;
    final sizeSpan = sizing.iconButtonSize - sizing.iconButtonIconSize;
    final clampedProgress = sizeSpan <= 0
        ? 1.0
        : ((size - sizing.iconButtonIconSize) / sizeSpan)
              .clamp(0.0, 1.0)
              .toDouble();
    final squircleCornerRadius =
        radii.squircleSm +
        ((radii.squircle - radii.squircleSm) * clampedProgress);
    final ShapeBorder avatarShape = shape == AxiAvatarShape.circle
        ? const CircleBorder()
        : SquircleBorder(cornerRadius: squircleCornerRadius);
    final resolvedAvatarBytes = avatarBytes;
    final showLoadingOverlay = avatar.loading;
    final overlayAlpha = motion.tapFocusAlpha + motion.tapHoverAlpha;

    Widget child = SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BlocSelector<SettingsCubit, SettingsState, bool>(
            selector: (state) => state.colorfulAvatars,
            builder: (context, colorfulAvatars) {
              final displayLabel = _displayLabelForAvatar(avatar.label);
              final initial = displayLabel.isNotEmpty
                  ? displayLabel.substring(0, 1).toUpperCase()
                  : '?';
              final avatarColorSeed = _colorSeedForAvatar(
                label: avatar.label,
                colorSeed: avatar.colorSeed,
                displayLabel: displayLabel,
              );
              final backgroundColor = colorfulAvatars
                  ? stringToColor(avatarColorSeed)
                  : context.colorScheme.secondary;
              final textColor = colorfulAvatars
                  ? Colors.white
                  : context.colorScheme.secondaryForeground;
              final textStyle = context.textTheme.h2.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              );
              return ClipPath(
                clipper: ShapeBorderClipper(shape: avatarShape),
                child: resolvedAvatarBytes != null
                    ? Padding(
                        padding: EdgeInsets.all(
                          size * AxiAvatar.paddingFraction,
                        ),
                        child: Image.memory(
                          resolvedAvatarBytes,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: backgroundColor,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Text(initial, style: textStyle),
                              ),
                            ),
                          ),
                        ),
                      )
                    : ColoredBox(
                        color: backgroundColor,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Text(initial, style: textStyle),
                          ),
                        ),
                      ),
              );
            },
          ),
          if (showLoadingOverlay)
            IgnorePointer(
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: avatarShape),
                child: ColoredBox(
                  color: colors.foreground.withValues(alpha: overlayAlpha),
                  child: Center(
                    child: AxiProgressIndicator(color: colors.background),
                  ),
                ),
              ),
            ),
          presence == null || subscription.isNone || subscription.isFrom
              ? const SizedBox()
              : Positioned.fill(
                  child: FractionallySizedBox(
                    widthFactor:
                        context.sizing.iconButtonIconSize /
                        context.sizing.iconButtonTapTarget,
                    heightFactor:
                        context.sizing.iconButtonIconSize /
                        context.sizing.iconButtonTapTarget,
                    alignment: Alignment.bottomRight,
                    child: PresenceIndicator(
                      presence: presence!,
                      status: status,
                    ),
                  ),
                ),
        ],
      ),
    );
    final sizedChild = SizedBox.square(dimension: size, child: child);
    final statusText = status?.trim();
    final presenceLabel = presence == null
        ? null
        : _presenceLabel(context, presence!);
    final tooltipText = () {
      if (statusText != null && statusText.isNotEmpty) {
        return presenceLabel == null
            ? statusText
            : '$statusText ($presenceLabel)';
      }
      return presenceLabel;
    }();
    if (tooltipText == null) return sizedChild;
    return AxiTooltip(builder: (_) => Text(tooltipText), child: sizedChild);
  }

  String _presenceLabel(BuildContext context, Presence presence) {
    return switch (presence) {
      Presence.unavailable => context.l10n.sessionCapabilityStatusOffline,
      Presence.xa => context.l10n.emailDemoStatusIdle,
      Presence.away => context.l10n.emailDemoStatusIdle,
      Presence.dnd => context.l10n.calendarFreeBusyBusy,
      Presence.chat => context.l10n.calendarFreeBusyFree,
      Presence.unknown => context.l10n.commonUnknownLabel,
    };
  }
}

class HydratedAxiAvatar extends StatefulWidget {
  const HydratedAxiAvatar({
    super.key,
    required this.avatar,
    this.subscription = Subscription.none,
    this.presence,
    this.status,
    this.active = false,
    this.shape = AxiAvatarShape.squircle,
    this.size = 50.0,
    this.avatarBytes,
  });

  final AvatarPresentation avatar;
  final Subscription subscription;
  final Presence? presence;
  final String? status;
  final bool active;
  final AxiAvatarShape shape;
  final double size;
  final Uint8List? avatarBytes;

  @override
  State<HydratedAxiAvatar> createState() => _HydratedAxiAvatarState();
}

class _HydratedAxiAvatarState extends State<HydratedAxiAvatar> {
  Uint8List? _resolvedAvatarBytes;
  String? _loadingPath;
  Object? _loadToken;

  String? get _normalizedAvatarPath {
    final trimmed = widget.avatar.avatarPath?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Uint8List? get _providedAvatarBytes {
    final bytes = widget.avatarBytes;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return bytes;
  }

  @override
  void initState() {
    super.initState();
    _resolveAvatarBytes(clearStaleBytes: true);
  }

  @override
  void didUpdateWidget(covariant HydratedAxiAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final jidChanged = oldWidget.avatar.label != widget.avatar.label;
    final pathChanged = oldWidget.avatar.avatarPath != widget.avatar.avatarPath;
    final bytesChanged = oldWidget.avatarBytes != widget.avatarBytes;
    final loadingSettled = oldWidget.avatar.loading && !widget.avatar.loading;
    if (jidChanged || pathChanged || bytesChanged || loadingSettled) {
      _resolveAvatarBytes(clearStaleBytes: jidChanged || pathChanged);
    }
  }

  Future<void> _resolveAvatarBytes({bool clearStaleBytes = false}) async {
    final providedBytes = _providedAvatarBytes;
    if (providedBytes != null) {
      setState(() {
        _resolvedAvatarBytes = providedBytes;
        _loadingPath = null;
      });
      return;
    }

    final path = _normalizedAvatarPath;
    if (path == null) {
      setState(() {
        _resolvedAvatarBytes = null;
        _loadingPath = null;
      });
      return;
    }

    final xmpp = context.read<XmppService>();
    final safeCached = xmpp.cachedSafeAvatarBytes(path);
    if (safeCached != null && safeCached.isNotEmpty) {
      setState(() {
        _resolvedAvatarBytes = safeCached;
        _loadingPath = null;
      });
      return;
    }

    final loadToken = Object();
    _loadToken = loadToken;
    setState(() {
      if (clearStaleBytes) {
        _resolvedAvatarBytes = null;
      }
      _loadingPath = path;
    });
    Uint8List? safeBytes;
    try {
      safeBytes = await xmpp.resolveSafeAvatarBytes(avatarPath: path);
    } catch (_) {
      safeBytes = null;
    }
    if (!mounted || !identical(_loadToken, loadToken)) {
      return;
    }
    setState(() {
      if (safeBytes != null) {
        _resolvedAvatarBytes = safeBytes;
      } else if (clearStaleBytes) {
        _resolvedAvatarBytes = null;
      }
      _loadingPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final path = _normalizedAvatarPath;
    final isLoadingAvatarBytes =
        _providedAvatarBytes == null && path != null && _loadingPath == path;
    final resolvedAvatarPresentation = widget.avatar.isAppIcon
        ? AvatarPresentation.appIcon(
            label: widget.avatar.label,
            colorSeed: widget.avatar.colorSeed,
          )
        : AvatarPresentation.avatar(
            label: widget.avatar.label,
            colorSeed: widget.avatar.colorSeed,
            avatar: widget.avatar.avatar,
            loading: widget.avatar.loading || isLoadingAvatarBytes,
          );
    return AxiAvatar(
      avatar: resolvedAvatarPresentation,
      subscription: widget.subscription,
      presence: widget.presence,
      status: widget.status,
      active: widget.active,
      shape: widget.shape,
      size: widget.size,
      avatarBytes: _providedAvatarBytes ?? _resolvedAvatarBytes,
    );
  }
}

String _displayLabelForAvatar(String label) {
  if (label.isEmpty) return '?';
  final parsed = parseJid(label);
  if (parsed != null) {
    final resource = parsed.resource.trim();
    if (resource.isNotEmpty) return resource;
    final localPart = parsed.local.trim();
    if (localPart.isNotEmpty) return localPart;
  }
  return label;
}

String _colorSeedForAvatar({
  required String label,
  required String? colorSeed,
  required String displayLabel,
}) {
  final preferredSeed = colorSeed?.trim() ?? '';
  final normalizedSeed =
      normalizedAddressKey(preferredSeed) ??
      normalizedAddressValue(preferredSeed) ??
      normalizeAddress(preferredSeed);
  if (normalizedSeed != null && normalizedSeed.isNotEmpty) {
    return normalizedSeed;
  }
  if (displayLabel.isNotEmpty) {
    return displayLabel;
  }
  final fallback = label.trim();
  return fallback.isNotEmpty ? fallback : '?';
}
