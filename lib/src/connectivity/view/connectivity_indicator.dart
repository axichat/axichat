// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _connectivityIndicatorIconSize = 20.0;
const double _connectivityIndicatorSpacing = 8.0;
const EdgeInsets _connectivityIndicatorPadding = EdgeInsets.all(4.0);
const Curve _connectivityIndicatorInCurve = Curves.easeOutCubic;
const Curve _connectivityIndicatorOutCurve = Curves.easeInCubic;
const Offset _connectivityIndicatorSlideOffset = Offset(0.0, -0.08);
const Duration _connectivityConnectedSuccessDuration = Duration(
  milliseconds: 900,
);

class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({super.key});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  Timer? _connectedSuccessTimer;
  late ConnectivityState _connectivityState;
  bool _showConnectedSuccess = false;

  @override
  void initState() {
    super.initState();
    if (kEnableDemoChats) {
      _connectivityState = const ConnectivityNotConnected();
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
    _connectedSuccessTimer?.cancel();
    _connectedSuccessTimer = null;

    final nextShowConnectedSuccess =
        previous is ConnectivityConnecting && state is ConnectivityConnected;

    if (nextShowConnectedSuccess) {
      _connectedSuccessTimer = Timer(
        _connectivityConnectedSuccessDuration,
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

    final colors = context.colorScheme;
    final brightness = Theme.of(context).brightness;
    final darkForeground =
        brightness == Brightness.dark ? colors.background : colors.foreground;
    final presentation = switch (_connectivityState) {
      ConnectivityConnected() => _ConnectivityIndicatorPresentation(
          show: _showConnectedSuccess,
          color: axiGreen,
          foregroundColor: darkForeground,
          iconData: LucideIcons.cloud,
          text: 'Connected',
        ),
      ConnectivityConnecting() => _ConnectivityIndicatorPresentation(
          show: true,
          color: colors.primary,
          foregroundColor: colors.primaryForeground,
          iconData: LucideIcons.cloudCog,
          text: 'Connecting...',
        ),
      ConnectivityNotConnected() => _ConnectivityIndicatorPresentation(
          show: true,
          color: axiWarning,
          foregroundColor: darkForeground,
          iconData: LucideIcons.cloudOff,
          text: 'Not connected.',
        ),
      ConnectivityError() => _ConnectivityIndicatorPresentation(
          show: true,
          color: colors.destructive,
          foregroundColor: colors.destructiveForeground,
          iconData: LucideIcons.cloudOff,
          text: 'Failed to connect.',
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
    this.duration = const Duration(milliseconds: 300),
  });

  final Color color;
  final Color foregroundColor;
  final IconData iconData;
  final String text;
  final bool show;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
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
      switchInCurve: _connectivityIndicatorInCurve,
      switchOutCurve: _connectivityIndicatorOutCurve,
      transitionBuilder: (child, animation) {
        final slideAnimation = Tween<Offset>(
          begin: _connectivityIndicatorSlideOffset,
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: _connectivityIndicatorInCurve,
          ),
        );
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: _connectivityIndicatorInCurve,
          reverseCurve: _connectivityIndicatorOutCurve,
        );
        return SizeTransition(
          sizeFactor: curvedAnimation,
          axisAlignment: -1.0,
          child: FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
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
    return ColoredBox(
      color: color,
      child: SizedBox(
        width: double.infinity,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: _connectivityIndicatorPadding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconData,
                  color: foregroundColor,
                  size: _connectivityIndicatorIconSize,
                ),
                const SizedBox.square(dimension: _connectivityIndicatorSpacing),
                Text(
                  text,
                  style: TextStyle(color: foregroundColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
