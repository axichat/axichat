import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ConnectivityIndicator extends StatelessWidget {
  const ConnectivityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    var duration = context.watch<SettingsCubit>().animationDuration;
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        var color = const Color(0xff00ff00);
        var iconData = LucideIcons.cloud;
        var text = 'Connected';
        var show = true;

        switch (state) {
          case ConnectivityConnected():
            show = false;
          case ConnectivityConnecting():
            color = const Color(0xff4d4dff);
            iconData = LucideIcons.cloudCog;
            text = 'Connecting...';
          case ConnectivityNotConnected():
            color = Colors.orange;
            iconData = LucideIcons.cloudOff;
            text = 'Not connected.';
          case ConnectivityError():
            color = Colors.red;
            iconData = LucideIcons.cloudOff;
            text = 'Failed to connect.';
        }

        return ConnectivityIndicatorContainer(
          show: show,
          duration: duration,
          color: color,
          iconData: iconData,
          text: text,
        );
      },
    );
  }
}

class ConnectivityIndicatorContainer extends StatelessWidget {
  const ConnectivityIndicatorContainer({
    super.key,
    required this.color,
    required this.iconData,
    required this.text,
    this.show = false,
    this.duration = const Duration(milliseconds: 300),
  });

  final Color color;
  final IconData iconData;
  final String text;
  final bool show;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      color: color,
      alignment: Alignment.center,
      child: !show
          ? const SizedBox.shrink()
          : SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      iconData,
                      color: Colors.white,
                      size: 20.0,
                    ),
                    const SizedBox.square(dimension: 8.0),
                    Text(
                      text,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
