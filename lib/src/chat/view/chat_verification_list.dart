import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/verification/bloc/verification_cubit.dart';
import 'package:axichat/src/verification/view/verification_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VerificationList extends StatelessWidget {
  const VerificationList({
    super.key,
    required this.jid,
  });

  final String jid;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<VerificationCubit, VerificationState>(
        builder: (context, state) {
          if (state.loading) return const Center(child: AxiProgressIndicator());
          if (state.fingerprints.isEmpty) {
            return Center(
              child: Text(
                'No devices found',
                style: context.textTheme.muted,
              ),
            );
          }
          return SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 16.0,
                  children: [
                    Text(
                      'Expert settings',
                      style: context.textTheme.h4,
                    ),
                    Text(
                      'If you verify a device, no other devices will receive '
                      'your messages until you verify them as well!',
                      textAlign: TextAlign.center,
                      style: context.textTheme.muted,
                    ),
                    const SizedBox.square(dimension: 4.0),
                    for (final fingerprint in state.fingerprints)
                      VerificationSelector(fingerprint: fingerprint),
                    const SizedBox.square(dimension: 8.0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
