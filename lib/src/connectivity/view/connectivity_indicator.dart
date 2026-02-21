// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({super.key});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  Timer? _connectedSuccessTimer;
  ConnectivityState? _connectivityState;
  bool _showConnectedSuccess = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_connectivityState != null) {
      return;
    }
    if (kEnableDemoChats) {
      _connectivityState = const ConnectivityNotConnected(
        emailState: EmailSyncState.ready(),
        emailEnabled: true,
      );
      return;
    }
    _connectivityState = context.read<ConnectivityCubit>().state;
  }

  @override
  void dispose() {
    _connectedSuccessTimer?.cancel();
    super.dispose();
  }

  void _handleConnectivityState(ConnectivityState state) {
    final previous = _connectivityState;
    if (previous == null) {
      setState(() {
        _connectivityState = state;
        _showConnectedSuccess = false;
      });
      return;
    }
    _connectedSuccessTimer?.cancel();
    _connectedSuccessTimer = null;

    final nextShowConnectedSuccess =
        previous is ConnectivityConnecting && state is ConnectivityConnected;

    if (nextShowConnectedSuccess) {
      _connectedSuccessTimer = Timer(
        context.motion.statusBannerSuccessDuration,
        () {
          if (!mounted) return;
          if (_connectivityState is! ConnectivityConnected) return;
          setState(() {
            _showConnectedSuccess = false;
          });
        },
      );
    }

    if (previous.runtimeType == state.runtimeType &&
        _showConnectedSuccess == nextShowConnectedSuccess) {
      return;
    }

    setState(() {
      _connectivityState = state;
      _showConnectedSuccess = nextShowConnectedSuccess;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kEnableDemoChats) {
      return const SizedBox.shrink();
    }

    final connectivityState = _connectivityState;
    if (connectivityState == null) {
      return const SizedBox.shrink();
    }

    final colors = context.colorScheme;
    final brightness = ShadTheme.of(context).brightness;
    final darkForeground = brightness == Brightness.dark
        ? colors.background
        : colors.foreground;
    final l10n = context.l10n;
    final presentation = switch (connectivityState) {
      ConnectivityConnected() => _ConnectivityIndicatorPresentation(
        show: _showConnectedSuccess,
        color: colors.green,
        foregroundColor: darkForeground,
        iconData: LucideIcons.cloud,
        text: l10n.connectivityStatusConnected,
      ),
      ConnectivityConnecting() => _ConnectivityIndicatorPresentation(
        show: true,
        color: colors.primary,
        foregroundColor: colors.primaryForeground,
        iconData: LucideIcons.cloudCog,
        text: l10n.connectivityStatusConnecting,
      ),
      ConnectivityNotConnected() => _ConnectivityIndicatorPresentation(
        show: true,
        color: colors.warning,
        foregroundColor: darkForeground,
        iconData: LucideIcons.cloudOff,
        text: l10n.connectivityStatusNotConnected,
      ),
      ConnectivityError() => _ConnectivityIndicatorPresentation(
        show: true,
        color: colors.destructive,
        foregroundColor: colors.destructiveForeground,
        iconData: LucideIcons.cloudOff,
        text: l10n.connectivityStatusFailed,
      ),
    };

    return BlocListener<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) => _handleConnectivityState(state),
      child: ConnectivityIndicatorContainer(
        show: presentation.show,
        duration: context.watch<SettingsCubit>().animationDuration,
        color: presentation.color,
        foregroundColor: presentation.foregroundColor,
        iconData: presentation.iconData,
        text: presentation.text,
      ),
    );
  }
}

class _ConnectivityIndicatorPresentation {
  const _ConnectivityIndicatorPresentation({
    required this.show,
    required this.color,
    required this.foregroundColor,
    required this.iconData,
    required this.text,
  });

  final bool show;
  final Color color;
  final Color foregroundColor;
  final IconData iconData;
  final String text;
}

class ConnectivityIndicatorContainer extends StatelessWidget {
  const ConnectivityIndicatorContainer({
    super.key,
    required this.color,
    required this.foregroundColor,
    required this.iconData,
    required this.text,
    this.show = false,
    required this.duration,
  });

  final Color color;
  final Color foregroundColor;
  final IconData iconData;
  final String text;
  final bool show;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final Widget child = show
        ? _ConnectivityIndicatorBanner(
            key: ValueKey<String>(text),
            color: color,
            foregroundColor: foregroundColor,
            iconData: iconData,
            text: text,
          )
        : const SizedBox.shrink(key: ValueKey<String>('hidden'));
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slideAnimation = Tween<Offset>(
          begin: motion.statusBannerSlideOffset,
          end: Offset.zero,
        ).animate(animation);
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1.0,
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slideAnimation, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

class _ConnectivityIndicatorBanner extends StatelessWidget {
  const _ConnectivityIndicatorBanner({
    super.key,
    required this.color,
    required this.foregroundColor,
    required this.iconData,
    required this.text,
  });

  final Color color;
  final Color foregroundColor;
  final IconData iconData;
  final String text;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    final textStyle = context.textTheme.p.copyWith(color: foregroundColor);
    return ColoredBox(
      color: color,
      child: SizedBox(
        width: double.infinity,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.all(spacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconData,
                  color: foregroundColor,
                  size: sizing.iconButtonIconSize,
                ),
                SizedBox.square(dimension: spacing.s),
                Text(text, style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
