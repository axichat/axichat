// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/in_bounds_fade_scale.dart';
import 'package:axichat/src/xmpp_activity/bloc/xmpp_activity_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _overlayHorizontalPadding = 16.0;
const double _overlayBottomPadding = 32.0;
const double _overlayMaxWidth = 320.0;
const double _overlayMaxHeight = 320.0;
const double _overlayVerticalPadding = 4.0;
const double _overlayItemSpacing = 8.0;
const double _toastBorderRadius = 12.0;
const double _toastShadowBlur = 12.0;
const double _toastShadowOffsetY = 8.0;
const double _toastOpacity = 0.92;
const double _toastShadowAlpha = 0.14;
const double _toastHorizontalPadding = 16.0;
const double _toastVerticalPadding = 12.0;
const double _iconTextSpacing = 12.0;
const double _progressIndicatorSize = 18.0;
const double _progressIndicatorStrokeWidth = 2.2;
const double _statusIconSize = 20.0;
const double _surfaceBackgroundAlpha = 0.12;

const EdgeInsets _toastPadding = EdgeInsets.symmetric(
  horizontal: _toastHorizontalPadding,
  vertical: _toastVerticalPadding,
);
const EdgeInsets _overlayListPadding = EdgeInsets.symmetric(
  vertical: _overlayVerticalPadding,
);

class XmppOperationOverlay extends StatelessWidget {
  const XmppOperationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<XmppActivityCubit, XmppActivityState>(
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
                left: _overlayHorizontalPadding,
                right: _overlayHorizontalPadding,
                bottom: _overlayBottomPadding + bottomInset,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _overlayMaxWidth,
                  maxHeight: _overlayMaxHeight,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: _overlayListPadding,
                  clipBehavior: Clip.none,
                  itemCount: operations.length,
                  itemBuilder: (context, index) {
                    final reverseIndex = operations.length - 1 - index;
                    final operation = operations[reverseIndex];
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: _overlayItemSpacing,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InBoundsFadeScale(
                          key: ValueKey(operation.id),
                          child: _XmppOperationToast(operation: operation),
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

class _XmppOperationToast extends StatelessWidget {
  const _XmppOperationToast({required this.operation});

  final XmppOperation operation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shadowColor = colorScheme.shadow.withValues(alpha: _toastShadowAlpha);
    final surfaceColor = switch (operation.status) {
      XmppOperationStatus.inProgress => colorScheme.surfaceContainerHigh,
      XmppOperationStatus.success => colorScheme.surfaceBright,
      XmppOperationStatus.failure => colorScheme.errorContainer,
    };
    final textColor = switch (operation.status) {
      XmppOperationStatus.failure => colorScheme.onErrorContainer,
      _ => colorScheme.onSurface,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: _toastOpacity),
        borderRadius: BorderRadius.circular(_toastBorderRadius),
        boxShadow: [
          BoxShadow(
            blurRadius: _toastShadowBlur,
            offset: const Offset(0, _toastShadowOffsetY),
            color: shadowColor,
          ),
        ],
      ),
      child: Padding(
        padding: _toastPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OperationStatusIcon(status: operation.status),
            const SizedBox(width: _iconTextSpacing),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    operation.statusLabel(),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: textColor),
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

  final XmppOperationStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status) {
      XmppOperationStatus.inProgress => SizedBox(
          height: _progressIndicatorSize,
          width: _progressIndicatorSize,
          child: CircularProgressIndicator(
            strokeWidth: _progressIndicatorStrokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            backgroundColor: colorScheme.onSurface
                .withValues(alpha: _surfaceBackgroundAlpha),
          ),
        ),
      XmppOperationStatus.success => Icon(
          Icons.check_circle_rounded,
          size: _statusIconSize,
          color: colorScheme.primary,
        ),
      XmppOperationStatus.failure => Icon(
          Icons.error_rounded,
          size: _statusIconSize,
          color: colorScheme.onErrorContainer,
        ),
    };
  }
}
