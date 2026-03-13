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
  const ConnectivityIndicator({
    super.key,
    this.reserveTopInsetWhenHidden = false,
  });

  final bool reserveTopInsetWhenHidden;

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
      if (previousState == null) {
        return _ConnectivityIndicatorDisplay.hidden;
      }
      if (previousState is ConnectivityConnected) {
        return previousDisplay;
      }
      return _ConnectivityIndicatorDisplay.connected;
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
    final duration = context.watch<SettingsCubit>().animationDuration;
    if (kEnableDemoChats) {
      return _ConnectivityIndicatorContainer(
        presentation: null,
        duration: duration,
        reserveTopInsetWhenHidden: widget.reserveTopInsetWhenHidden,
      );
    }

    final colors = context.colorScheme;
    final brightness = ShadTheme.of(context).brightness;
    final connectingColors = ShadColorScheme.fromName(
      ShadColor.blue.name,
      brightness: brightness,
    );
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
          color: connectingColors.primary,
          foregroundColor: connectingColors.primaryForeground,
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
      child: _ConnectivityIndicatorContainer(
        presentation: presentation,
        duration: duration,
        reserveTopInsetWhenHidden: widget.reserveTopInsetWhenHidden,
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

class _ConnectivityIndicatorContainer extends StatelessWidget {
  const _ConnectivityIndicatorContainer({
    required this.presentation,
    required this.duration,
    required this.reserveTopInsetWhenHidden,
  });

  final _ConnectivityIndicatorPresentation? presentation;
  final Duration duration;
  final bool reserveTopInsetWhenHidden;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final topInset = MediaQuery.paddingOf(context).top;
    final hasBanner = presentation != null;
    const hiddenKey = ValueKey<String>('hidden');
    final Widget child = hasBanner
        ? _ConnectivityIndicatorBanner(
            key: ValueKey<String>(presentation!.text),
            color: presentation!.color,
            foregroundColor: presentation!.foregroundColor,
            iconData: presentation!.iconData,
            text: presentation!.text,
            topInset: topInset,
          )
        : SizedBox(
            key: hiddenKey,
            height: reserveTopInsetWhenHidden ? topInset : 0.0,
          );
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSlide(
        offset: hasBanner ? Offset.zero : motion.statusBannerSlideOffset,
        duration: duration,
        curve: Curves.easeInOutCubic,
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.topCenter,
            children: currentChild == null
                ? previousChildren
                : <Widget>[...previousChildren, currentChild],
          ),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: child,
        ),
      ),
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
    required this.topInset,
  });

  final Color color;
  final Color foregroundColor;
  final IconData iconData;
  final String text;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    final textStyle = context.textTheme.p.copyWith(color: foregroundColor);
    return ColoredBox(
      color: color,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.xs,
            topInset + spacing.xs,
            spacing.xs,
            spacing.xs,
          ),
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
    );
  }
}
