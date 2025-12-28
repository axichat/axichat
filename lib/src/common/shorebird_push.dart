import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// F-Droid and other store builds pass `--dart-define=ENABLE_SHOREBIRD=false`
/// to disable OTA updates entirely.
const bool kEnableShorebird =
    bool.fromEnvironment('ENABLE_SHOREBIRD', defaultValue: true);

enum ShorebirdUpdateGateStatus {
  upToDate,
  restartRequired,
  unavailable,
  failed,
}

extension ShorebirdUpdateGateStatusExtensions on ShorebirdUpdateGateStatus {
  bool get requiresRestart => this == ShorebirdUpdateGateStatus.restartRequired;
}

const double _updateGateMaxWidth = 420.0;
const double _updateGatePaddingValue = 20.0;
const double _updateGateBackdropAlpha = 0.9;
const double _updateGateNoticePaddingValue = 8.0;
const EdgeInsets _updateGatePadding = EdgeInsets.all(_updateGatePaddingValue);
const EdgeInsets _updateGateNoticePadding =
    EdgeInsets.all(_updateGateNoticePaddingValue);

Future<ShorebirdUpdateGateStatus>? _shorebirdUpdateFuture;

Future<ShorebirdUpdateGateStatus> checkShorebirdStatus([
  ShorebirdUpdater? shorebird,
]) {
  if (shorebird == null) {
    _shorebirdUpdateFuture ??= _checkShorebirdStatus();
    return _shorebirdUpdateFuture!;
  }
  return _checkShorebirdStatus(shorebird);
}

Future<ShorebirdUpdateGateStatus> _checkShorebirdStatus([
  ShorebirdUpdater? shorebird,
]) async {
  if (!kEnableShorebird) {
    return ShorebirdUpdateGateStatus.unavailable;
  }
  final updater = shorebird ?? ShorebirdUpdater();

  if (!updater.isAvailable) {
    return ShorebirdUpdateGateStatus.unavailable;
  }

  UpdateStatus status;
  try {
    status = await updater.checkForUpdate();
  } on Exception {
    return ShorebirdUpdateGateStatus.failed;
  }

  if (status == UpdateStatus.restartRequired) {
    return ShorebirdUpdateGateStatus.restartRequired;
  }

  if (status == UpdateStatus.outdated) {
    try {
      await updater.update();
      return ShorebirdUpdateGateStatus.restartRequired;
    } on Exception {
      return ShorebirdUpdateGateStatus.failed;
    }
  }

  return ShorebirdUpdateGateStatus.upToDate;
}

Future<bool> checkShorebird([ShorebirdUpdater? shorebird]) async {
  final status = await checkShorebirdStatus(shorebird);
  return status.requiresRestart;
}

class ShorebirdChecker extends StatelessWidget {
  const ShorebirdChecker({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kEnableShorebird) {
      return const SizedBox.shrink();
    }
    return AxiAnimatedSize(
      duration: context.watch<SettingsCubit>().animationDuration,
      curve: Curves.easeInOut,
      child: FutureBuilder<ShorebirdUpdateGateStatus>(
        future: checkShorebirdStatus(),
        builder: (context, snapshot) {
          final hasUpdate = snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData &&
              snapshot.requireData.requiresRestart;
          if (!hasUpdate) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: _updateGateNoticePadding,
            child: Text(context.l10n.shorebirdUpdateAvailable),
          );
        },
      ),
    );
  }
}

class ShorebirdUpdateGate extends StatefulWidget {
  const ShorebirdUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<ShorebirdUpdateGate> createState() => _ShorebirdUpdateGateState();
}

class _ShorebirdUpdateGateState extends State<ShorebirdUpdateGate> {
  late final Future<ShorebirdUpdateGateStatus> _future = checkShorebirdStatus();

  @override
  Widget build(BuildContext context) {
    if (!kEnableShorebird) {
      return widget.child;
    }
    return FutureBuilder<ShorebirdUpdateGateStatus>(
      future: _future,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null || !status.requiresRestart) {
          return widget.child;
        }
        final colors = ShadTheme.of(context).colorScheme;
        return Stack(
          children: [
            widget.child,
            ModalBarrier(
              dismissible: false,
              color: colors.background.withValues(
                alpha: _updateGateBackdropAlpha,
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _updateGateMaxWidth,
                ),
                child: AxiModalSurface(
                  padding: _updateGatePadding,
                  child: Text(
                    context.l10n.shorebirdUpdateAvailable,
                    style: ShadTheme.of(context).textTheme.h4,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
