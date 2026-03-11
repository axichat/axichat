// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/update/bloc/update_cubit.dart';
import 'package:axichat/src/update/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UpdatePromptOverlay extends StatelessWidget {
  const UpdatePromptOverlay({
    super.key,
    required this.child,
    required this.canPresentPrompt,
  });

  final Widget child;
  final bool canPresentPrompt;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UpdateCubit, UpdateState>(
      builder: (context, state) {
        final pendingOffer = state.pendingOffer;
        if (!canPresentPrompt || pendingOffer == null) {
          return child;
        }
        final spacing = context.spacing;
        final colors = context.colorScheme;
        return Stack(
          children: [
            child,
            ModalBarrier(
              dismissible: false,
              color: colors.background.withValues(alpha: 0.9),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.sizing.dialogMaxWidth,
                ),
                child: AxiModalSurface(
                  padding: EdgeInsets.all(spacing.l),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: spacing.m,
                    children: [
                      Text(
                        _dialogTitle(context, pendingOffer),
                        style: context.modalHeaderTextStyle,
                      ),
                      Text(
                        _dialogMessage(context, pendingOffer),
                        style: context.textTheme.p,
                      ),
                      if (state.actionFailure != null)
                        Text(
                          _actionFailureLabel(context, state.actionFailure!),
                          style: context.textTheme.small,
                        ),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: spacing.s,
                        runSpacing: spacing.s,
                        children: _actions(context, state, pendingOffer),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _actions(
    BuildContext context,
    UpdateState state,
    UpdateOffer pendingOffer,
  ) {
    if (pendingOffer.kind == UpdateOfferKind.shorebirdRestart) {
      return [
        AxiButton.primary(
          onPressed: state.isPerformingAction
              ? null
              : () => context.read<UpdateCubit>().dismissCurrentOffer(),
          child: Text(context.l10n.updateActionOk),
        ),
      ];
    }
    return [
      AxiButton.secondary(
        onPressed: state.isPerformingAction
            ? null
            : () => context.read<UpdateCubit>().dismissCurrentOffer(),
        child: Text(context.l10n.updateActionLater),
      ),
      AxiButton.primary(
        loading: state.isPerformingAction,
        onPressed: state.isPerformingAction
            ? null
            : () {
                context.read<UpdateCubit>().startUpdate();
              },
        child: Text(context.l10n.updateActionUpdate),
      ),
    ];
  }

  String _dialogTitle(BuildContext context, UpdateOffer offer) =>
      offer.kind == UpdateOfferKind.shorebirdRestart
      ? context.l10n.updatePromptPatchReadyTitle
      : context.l10n.updatePromptTitle;

  String _dialogMessage(BuildContext context, UpdateOffer offer) {
    if (offer.kind == UpdateOfferKind.shorebirdRestart) {
      return context.l10n.updatePromptPatchReadyMessage;
    }
    final availableVersion = offer.availableVersion;
    if (availableVersion != null && availableVersion.isNotEmpty) {
      return context.l10n.updatePromptStoreMessageVersion(availableVersion);
    }
    return context.l10n.updatePromptStoreMessage;
  }

  String _actionFailureLabel(
    BuildContext context,
    UpdateActionFailure actionFailure,
  ) => switch (actionFailure) {
    UpdateActionFailure.openStoreFailed => context.l10n.updateActionOpenFailed,
    UpdateActionFailure.startUpdateFailed => context.l10n.updateActionFailed,
    UpdateActionFailure.userDeclined => context.l10n.updateActionDeclined,
  };
}

class UpdateStatusBanner extends StatelessWidget {
  const UpdateStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    return BlocBuilder<UpdateCubit, UpdateState>(
      builder: (context, state) {
        final currentOffer = state.currentOffer;
        return AxiAnimatedSize(
          duration: animationDuration,
          curve: Curves.easeInOut,
          child: currentOffer == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.all(context.spacing.xs),
                  child: Text(
                    _bannerLabel(context, currentOffer),
                    style: context.textTheme.small,
                  ),
                ),
        );
      },
    );
  }

  String _bannerLabel(BuildContext context, UpdateOffer offer) {
    if (offer.kind == UpdateOfferKind.shorebirdRestart) {
      return context.l10n.updateStatusPatchReady;
    }
    final availableVersion = offer.availableVersion;
    if (availableVersion != null && availableVersion.isNotEmpty) {
      return context.l10n.updateStatusStoreAvailableVersion(availableVersion);
    }
    return context.l10n.updateStatusStoreAvailable;
  }
}
