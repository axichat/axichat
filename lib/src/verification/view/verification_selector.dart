import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/verification/bloc/verification_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class VerificationSelector extends StatelessWidget {
  const VerificationSelector({super.key, required this.fingerprint});

  final OmemoFingerprint fingerprint;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      border:
          Border.fromBorderSide(BorderSide(color: fingerprint.trust.toColor)),
      content: Column(
        spacing: 8.0,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('ID: ${fingerprint.deviceID.toString()}'),
          const SizedBox.square(dimension: 8),
          DisplayFingerprint(fingerprint: fingerprint.fingerprint),
          const SizedBox.square(dimension: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            spacing: 8.0,
            children: [
              Icon(
                fingerprint.trust.toIcon,
                color: fingerprint.trust.toColor,
              ),
              ShadSelect<BTBVTrustState>(
                anchor: const ShadAnchorAuto(preferBelow: false),
                initialValue: fingerprint.trust,
                onChanged: (trust) => context
                    .read<VerificationCubit>()
                    .setDeviceTrust(device: fingerprint.deviceID, trust: trust),
                options: BTBVTrustState.values
                    .map((trust) => ShadOption<BTBVTrustState>(
                          value: trust,
                          child: Text(trust.asString),
                        ))
                    .toList(),
                selectedOptionBuilder:
                    (BuildContext context, BTBVTrustState value) =>
                        Text(value.asString),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
