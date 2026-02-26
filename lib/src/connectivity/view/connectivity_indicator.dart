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

enum _ConnectivityIndicatorDisplay {
  hidden,
  connecting,
  connected,
  notConnected,
  error,
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  Timer? _connectedSuccessTimer;
  ConnectivityState? _connectivityState;
  _ConnectivityIndicatorDisplay _display = _ConnectivityIndicatorDisplay.hidden;

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
      _display = _ConnectivityIndicatorDisplay.notConnected;
      return;
    }
    final initialState = context.read<ConnectivityCubit>().state;
    _connectivityState = initialState;
    _display = _displayFor(
      state: initialState,
      previousState: null,
      previousDisplay: _ConnectivityIndicatorDisplay.hidden,
    );
  }

  @override
  void dispose() {
    _connectedSuccessTimer?.cancel();
    super.dispose();
  }

  void _startConnectedSuccessTimer() {
    _connectedSuccessTimer?.cancel();
    _connectedSuccessTimer = Timer(
      context.motion.statusBannerSuccessDuration,
      () {
        if (!mounted) return;
        if (_display != _ConnectivityIndicatorDisplay.connected) return;
        if (_connectivityState is! ConnectivityConnected) return;
        setState(() {
          _display = _ConnectivityIndicatorDisplay.hidden;
        });
      },
    );
  }

  _ConnectivityIndicatorDisplay _displayFor({
    required ConnectivityState state,
    required ConnectivityState? previousState,
    required _ConnectivityIndicatorDisplay previousDisplay,
  }) {
    if (state is ConnectivityConnected) {
      final enteredFromConnecting = previousState is ConnectivityConnecting;
      if (enteredFromConnecting ||
          previousDisplay == _ConnectivityIndicatorDisplay.connected) {
        return _ConnectivityIndicatorDisplay.connected;
      }
      return _ConnectivityIndicatorDisplay.hidden;
    }
    if (state is ConnectivityConnecting) {
      return _ConnectivityIndicatorDisplay.connecting;
    }
    if (state is ConnectivityNotConnected) {
      return _ConnectivityIndicatorDisplay.notConnected;
    }
    return _ConnectivityIndicatorDisplay.error;
  }

  void _handleConnectivityState(ConnectivityState state) {
    final previous = _connectivityState;
    if (previous == null) {
      setState(() {
        _connectivityState = state;
        _display = _displayFor(
          state: state,
          previousState: null,
          previousDisplay: _display,
        );
      });
      return;
    }

    final nextDisplay = _displayFor(
      state: state,
      previousState: previous,
      previousDisplay: _display,
    );
    if (nextDisplay == _ConnectivityIndicatorDisplay.connected) {
      _startConnectedSuccessTimer();
    } else {
      _connectedSuccessTimer?.cancel();
      _connectedSuccessTimer = null;
    }
    _connectivityState = state;
    if (_display == nextDisplay) return;
    setState(() => _display = nextDisplay);
  }

  @override
  Widget build(BuildContext context) {
    if (kEnableDemoChats) {
      return const SizedBox.shrink();
    }

    final colors = context.colorScheme;
    final brightness = ShadTheme.of(context).brightness;
    final darkForeground = brightness == Brightness.dark
        ? colors.background
        : colors.foreground;
    final l10n = context.l10n;
    final presentation = switch (_display) {
      _ConnectivityIndicatorDisplay.hidden => null,
      _ConnectivityIndicatorDisplay.connected =>
        _ConnectivityIndicatorPresentation(
          color: colors.green,
          foregroundColor: darkForeground,
          iconData: LucideIcons.cloud,
          text: l10n.connectivityStatusConnected,
        ),
      _ConnectivityIndicatorDisplay.connecting =>
        _ConnectivityIndicatorPresentation(
          color: colors.primary,
          foregroundColor: colors.primaryForeground,
          iconData: LucideIcons.cloudCog,
          text: l10n.connectivityStatusConnecting,
        ),
      _ConnectivityIndicatorDisplay.notConnected =>
        _ConnectivityIndicatorPresentation(
          color: colors.warning,
          foregroundColor: darkForeground,
          iconData: LucideIcons.cloudOff,
          text: l10n.connectivityStatusNotConnected,
        ),
      _ConnectivityIndicatorDisplay.error => _ConnectivityIndicatorPresentation(
        color: colors.destructive,
        foregroundColor: colors.destructiveForeground,
        iconData: LucideIcons.cloudOff,
        text: l10n.connectivityStatusFailed,
      ),
    };

    return BlocListener<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) => _handleConnectivityState(state),
      child: ConnectivityIndicatorContainer(
        presentation: presentation,
        duration: context.watch<SettingsCubit>().animationDuration,
      ),
    );
  }
}

class _ConnectivityIndicatorPresentation {
  const _ConnectivityIndicatorPresentation({
    required this.color,
    required this.foregroundColor,
    required this.iconData,
    required this.text,
  });

  final Color color;
  final Color foregroundColor;
  final IconData iconData;
  final String text;
}

class ConnectivityIndicatorContainer extends StatelessWidget {
  const ConnectivityIndicatorContainer({
    super.key,
    required this.presentation,
    required this.duration,
  });

  final _ConnectivityIndicatorPresentation? presentation;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final Widget child = presentation == null
        ? const SizedBox.shrink(key: ValueKey<String>('hidden'))
        : _ConnectivityIndicatorBanner(
            key: ValueKey<String>(presentation!.text),
            color: presentation!.color,
            foregroundColor: presentation!.foregroundColor,
            iconData: presentation!.iconData,
            text: presentation!.text,
          );
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
