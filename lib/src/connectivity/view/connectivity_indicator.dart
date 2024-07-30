import 'package:chat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:chat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ConnectivityIndicator extends StatelessWidget {
  const ConnectivityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    var duration = context.watch<SettingsCubit>().animationDuration;
    return AnimatedSize(
      duration: duration,
      child: AnimatedContainer(
        duration: duration,
        child: BlocBuilder<ConnectivityCubit, ConnectivityState>(
          builder: (context, state) {
            return switch (state) {
              ConnectivityConnected() => const SizedBox.shrink(),
              ConnectivityConnecting() => const ConnectivityIndicatorContainer(
                  color: Colors.blue,
                  iconData: LucideIcons.cloudCog,
                  text: 'Connecting...',
                ),
              ConnectivityNotConnected() =>
                const ConnectivityIndicatorContainer(
                  color: Colors.orange,
                  iconData: LucideIcons.cloudOff,
                  text: 'Not connected.',
                ),
              ConnectivityError() => const ConnectivityIndicatorContainer(
                  color: Colors.red,
                  iconData: LucideIcons.cloudOff,
                  text: 'Failed to connect.',
                ),
            };
          },
        ),
      ),
    );
  }
}

class ConnectivityIndicatorContainer extends StatelessWidget {
  const ConnectivityIndicatorContainer({
    super.key,
    required this.color,
    required this.iconData,
    required this.text,
  });

  final Color color;
  final IconData iconData;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
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
    );
  }
}
