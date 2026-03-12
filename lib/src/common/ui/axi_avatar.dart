// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:typed_data';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_decode_safety.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum AxiAvatarShape { circle, squircle }

class AxiAvatar extends StatefulWidget {
  const AxiAvatar({
    super.key,
    required this.jid,
    this.subscription = Subscription.none,
    this.presence,
    this.status,
    this.active = false,
    this.shape = AxiAvatarShape.squircle,
    this.size = 50.0,
    this.avatarPath,
    this.avatarBytes,
    this.loading = false,
    this.colorSeed,
  });

  final String jid;
  final Subscription subscription;
  final Presence? presence;
  final String? status;
  final bool active;
  final AxiAvatarShape shape;
  final double size;
  final String? avatarPath;
  final Uint8List? avatarBytes;
  final bool loading;
  final String? colorSeed;

  static const double paddingFraction = 0.0;

  @override
  State<AxiAvatar> createState() => _AxiAvatarState();
}

class _AxiAvatarState extends State<AxiAvatar> {
  late final ShadPopoverController popoverController;
  Uint8List? _resolvedAvatarBytes;
  String? _resolvedPath;
  String? _loadingPath;

  String _displayLabelForJid(String jid) {
    if (jid.isEmpty) return '?';
    final parsed = parseJid(jid);
    if (parsed != null) {
      final resource = parsed.resource.trim();
      if (resource.isNotEmpty) return resource;
      final localPart = parsed.local.trim();
      if (localPart.isNotEmpty) return localPart;
    }
    return jid;
  }

  String _colorSeedForAvatar({required String displayLabel}) {
    final providedSeed = widget.colorSeed?.trim();
    final preferredSeed = providedSeed?.isNotEmpty == true
        ? providedSeed
        : widget.jid;
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
    final fallback = widget.jid.trim();
    return fallback.isNotEmpty ? fallback : '?';
  }

  Future<Uint8List?> _sanitizeAvatarBytes(Uint8List? bytes) async {
    return sanitizeAvatarBytes(bytes);
  }

  @override
  void initState() {
    super.initState();
    popoverController = ShadPopoverController();
    _refreshAvatarBytes();
  }

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AxiAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final jidChanged = oldWidget.jid != widget.jid;
    final loadingSettled = oldWidget.loading && !widget.loading;
    if (oldWidget.avatarBytes != widget.avatarBytes ||
        oldWidget.avatarPath != widget.avatarPath ||
        jidChanged ||
        loadingSettled) {
      _refreshAvatarBytes(clearStaleBytes: jidChanged);
    }
  }

  Future<void> _refreshAvatarBytes({bool clearStaleBytes = false}) async {
    final providedBytes =
        widget.avatarBytes != null && widget.avatarBytes!.isNotEmpty
        ? widget.avatarBytes
        : null;
    if (providedBytes != null) {
      final safeBytes = await _sanitizeAvatarBytes(providedBytes);
      if (!mounted) return;
      if (safeBytes == null) {
        setState(() {
          _resolvedAvatarBytes = null;
          _resolvedPath = null;
          _loadingPath = null;
        });
        return;
      }
      final resolvedPath = widget.avatarPath?.trim();
      if (resolvedPath != null && resolvedPath.isNotEmpty) {
        context.read<XmppService>().cacheSafeAvatarBytes(
          resolvedPath,
          safeBytes,
        );
      }
      setState(() {
        _resolvedAvatarBytes = safeBytes;
        _resolvedPath = resolvedPath;
        _loadingPath = resolvedPath;
      });
      return;
    }

    final path = widget.avatarPath?.trim();
    if (path == null || path.isEmpty) {
      setState(() {
        _resolvedAvatarBytes = null;
        _resolvedPath = null;
        _loadingPath = null;
      });
      return;
    }

    final xmpp = context.read<XmppService>();
    final safeCached = xmpp.cachedSafeAvatarBytes(path);
    if (safeCached != null && safeCached.isNotEmpty) {
      setState(() {
        _resolvedAvatarBytes = safeCached;
        _resolvedPath = path;
        _loadingPath = path;
      });
      return;
    }
    final cached = xmpp.cachedAvatarBytes(path);
    if (cached != null && cached.isNotEmpty) {
      final safeBytes = await _sanitizeAvatarBytes(cached);
      if (!mounted) return;
      if (safeBytes == null) {
        setState(() {
          if (clearStaleBytes) {
            _resolvedAvatarBytes = null;
            _resolvedPath = null;
          }
          _loadingPath = null;
        });
        return;
      }
      xmpp.cacheSafeAvatarBytes(path, safeBytes);
      setState(() {
        _resolvedAvatarBytes = safeBytes;
        _resolvedPath = path;
        _loadingPath = path;
      });
      return;
    }

    if (_resolvedPath == path && _resolvedAvatarBytes != null) {
      return;
    }

    setState(() {
      if (clearStaleBytes) {
        _resolvedAvatarBytes = null;
        _resolvedPath = null;
      }
      _loadingPath = path;
    });
    try {
      final bytes = await xmpp.loadAvatarBytes(path);
      if (!mounted || _loadingPath != path) {
        return;
      }
      final safeBytes = await _sanitizeAvatarBytes(bytes);
      if (!mounted || _loadingPath != path) {
        return;
      }
      setState(() {
        if (safeBytes != null) {
          xmpp.cacheSafeAvatarBytes(path, safeBytes);
          _resolvedAvatarBytes = safeBytes;
          _resolvedPath = path;
        } else if (clearStaleBytes) {
          _resolvedAvatarBytes = null;
          _resolvedPath = null;
        }
        if (safeBytes == null) {
          _loadingPath = null;
        }
      });
    } catch (_) {
      if (!mounted || _loadingPath != path) return;
      setState(() {
        if (clearStaleBytes) {
          _resolvedAvatarBytes = null;
          _resolvedPath = null;
        }
        _loadingPath = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final motion = context.motion;
    final radii = context.radii;
    final sizing = context.sizing;
    final sizeSpan = sizing.iconButtonSize - sizing.iconButtonIconSize;
    final clampedProgress = sizeSpan <= 0
        ? 1.0
        : ((widget.size - sizing.iconButtonIconSize) / sizeSpan)
              .clamp(0.0, 1.0)
              .toDouble();
    final squircleCornerRadius =
        radii.squircleSm +
        ((radii.squircle - radii.squircleSm) * clampedProgress);
    final ShapeBorder avatarShape = widget.shape == AxiAvatarShape.circle
        ? const CircleBorder()
        : SquircleBorder(cornerRadius: squircleCornerRadius);
    final Uint8List? avatarBytes = _resolvedAvatarBytes;
    final path = widget.avatarPath?.trim();
    final isLoadingAvatarBytes =
        avatarBytes == null &&
        path != null &&
        path.isNotEmpty &&
        _loadingPath == path;
    final showLoadingOverlay = widget.loading || isLoadingAvatarBytes;
    final overlayAlpha = motion.tapFocusAlpha + motion.tapHoverAlpha;

    Widget child = SizedBox.square(
      dimension: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) {
              final displayLabel = _displayLabelForJid(widget.jid);
              final initial = displayLabel.isNotEmpty
                  ? displayLabel.substring(0, 1).toUpperCase()
                  : '?';
              final colorSeed = _colorSeedForAvatar(displayLabel: displayLabel);
              final backgroundColor = state.colorfulAvatars
                  ? stringToColor(colorSeed)
                  : context.colorScheme.secondary;
              final textColor = state.colorfulAvatars
                  ? Colors.white
                  : context.colorScheme.secondaryForeground;
              final textStyle = context.textTheme.h2.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              );
              return ClipPath(
                clipper: ShapeBorderClipper(shape: avatarShape),
                child: avatarBytes != null
                    ? Padding(
                        padding: EdgeInsets.all(
                          widget.size * AxiAvatar.paddingFraction,
                        ),
                        child: Image.memory(
                          avatarBytes,
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
                          child: isLoadingAvatarBytes && !widget.loading
                              ? const SizedBox.shrink()
                              : FittedBox(
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
          widget.presence == null ||
                  widget.subscription.isNone ||
                  widget.subscription.isFrom
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
                      presence: widget.presence!,
                      status: widget.status,
                    ),
                  ),
                ),
        ],
      ),
    );
    if (widget.active && widget.presence != null) {
      final locate = context.read;
      child = AxiPopover(
        controller: popoverController,
        popover: (context) {
          return BlocProvider.value(
            value: locate<ProfileCubit>(),
            child: IntrinsicWidth(
              child: Material(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final value
                        in Presence.values.toList()..remove(Presence.unknown))
                      ListTile(
                        title: Text(_presenceLabel(context, value)),
                        leading: PresenceCircle(presence: value),
                        selected: widget.presence?.name == value.name,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        selectedColor: context.colorScheme.accentForeground,
                        selectedTileColor: context.colorScheme.accent,
                        onTap: () {
                          context.read<ProfileCubit>().updatePresence(
                            presence: value,
                            status: widget.status,
                          );
                          popoverController.toggle();
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        child: ShadGestureDetector(
          cursor: SystemMouseCursors.click,
          onTap: popoverController.toggle,
          child: child,
        ).withTapBounce(),
      );
    }
    final sizedChild = SizedBox.square(dimension: widget.size, child: child);
    final statusText = widget.status?.trim();
    final presenceLabel = widget.presence == null
        ? null
        : _presenceLabel(context, widget.presence!);
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
