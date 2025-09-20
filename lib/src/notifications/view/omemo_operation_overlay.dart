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
                left: 16,
                right: 16,
                bottom: 32 + bottomInset,
              ),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 320, maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  clipBehavior: Clip.none,
                  itemCount: operations.length,
                  itemBuilder: (context, index) {
                    final reverseIndex = operations.length - 1 - index;
                    final operation = operations[reverseIndex];
                    final bottomSpacing = index == 0 ? 8.0 : 8.0;
                    return Padding(
                      padding: EdgeInsets.only(bottom: bottomSpacing),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _OmemoOperationToast(operation: operation),
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
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor = switch (operation.status) {
      OmemoOperationStatus.inProgress => colorScheme.surfaceContainerHigh,
      OmemoOperationStatus.success => colorScheme.surfaceBright,
      OmemoOperationStatus.failure => colorScheme.errorContainer,
    };
    final textColor = switch (operation.status) {
      OmemoOperationStatus.failure => colorScheme.onErrorContainer,
      _ => colorScheme.onSurface,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 8),
            color: Color(0x1A000000),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OperationStatusIcon(status: operation.status),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    operation.statusLabel(),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: textColor),
                  ),
                  if (operation.status == OmemoOperationStatus.failure &&
                      operation.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        operation.error!,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: textColor.withValues(alpha: 0.9),
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
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status) {
      OmemoOperationStatus.inProgress => SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
      OmemoOperationStatus.success => Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: colorScheme.primary,
        ),
      OmemoOperationStatus.failure => Icon(
          Icons.error_rounded,
          size: 20,
          color: colorScheme.onErrorContainer,
        ),
    };
  }
}
