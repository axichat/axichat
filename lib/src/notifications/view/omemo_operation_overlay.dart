// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/omemo_activity/bloc/omemo_activity_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OmemoOperationOverlay extends StatelessWidget {
  const OmemoOperationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OmemoActivityCubit, OmemoActivityState>(
      builder: (context, state) {
        final operations = state.operations;
        if (operations.isEmpty) {
          return const SizedBox.shrink();
        }
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return IgnorePointer(
          ignoring: true,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.only(
                left: context.spacing.m,
                right: context.spacing.m,
                bottom: context.spacing.l + bottomInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.sizing.menuMaxWidth,
                  maxHeight: context.sizing.menuMaxHeight,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
                  clipBehavior: Clip.none,
                  itemCount: operations.length,
                  itemBuilder: (context, index) {
                    final reverseIndex = operations.length - 1 - index;
                    final operation = operations[reverseIndex];
                    return Padding(
                      padding: EdgeInsets.only(bottom: context.spacing.s),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InBoundsFadeScale(
                          key: ValueKey(operation.id),
                          child: _OmemoOperationToast(operation: operation),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OmemoOperationToast extends StatelessWidget {
  const _OmemoOperationToast({required this.operation});

  final OmemoOperation operation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isFailure = operation.status == OmemoOperationStatus.failure;
    final surfaceColor = isFailure ? colorScheme.destructive : colorScheme.card;
    final textColor = isFailure
        ? colorScheme.destructiveForeground
        : colorScheme.foreground;
    return AxiModalSurface(
      backgroundColor: surfaceColor,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.m,
          vertical: context.spacing.s,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OperationStatusIcon(status: operation.status),
            SizedBox(width: context.spacing.s),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    operation.statusLabel(),
                    style: context.textTheme.p.copyWith(color: textColor),
                  ),
                  if (operation.status == OmemoOperationStatus.failure &&
                      operation.error != null)
                    Padding(
                      padding: EdgeInsets.only(top: context.spacing.xs),
                      child: Text(
                        operation.error!,
                        style: context.textTheme.small.copyWith(
                          color: textColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationStatusIcon extends StatelessWidget {
  const _OperationStatusIcon({required this.status});

  final OmemoOperationStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return switch (status) {
      OmemoOperationStatus.inProgress => AxiProgressIndicator(
        color: colorScheme.primary,
      ),
      OmemoOperationStatus.success => Icon(
        Icons.check_circle_rounded,
        size: context.sizing.iconButtonIconSize,
        color: colorScheme.primary,
      ),
      OmemoOperationStatus.failure => Icon(
        Icons.error_rounded,
        size: context.sizing.iconButtonIconSize,
        color: colorScheme.destructiveForeground,
      ),
    };
  }
}
