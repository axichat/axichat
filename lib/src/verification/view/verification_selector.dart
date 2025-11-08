import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
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
    return BlocBuilder<ProfileCubit, ProfileState>(builder: (context, state) {
      final self = state.fingerprint?.deviceID == fingerprint.deviceID &&
          state.fingerprint?.jid == fingerprint.jid;
      return ShadCard(
        columnMainAxisSize: MainAxisSize.min,
        rowMainAxisSize: MainAxisSize.min,
        border: self
            ? null
            : Border.fromBorderSide(
                BorderSide(color: fingerprint.trust.toColor)),
        child: Column(
          spacing: 8.0,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('ID: ${fingerprint.deviceID.toString()}'),
            const SizedBox.square(dimension: 8),
            if (self)
              const Text('Current device')
            else
              SizedBox(
                width: 200.0,
                child: AxiTextFormField(
                  initialValue: fingerprint.label,
                  placeholder: const Text('Add label'),
                  onSubmitted: (value) =>
                      context.read<VerificationCubit?>()?.labelFingerprint(
                            jid: fingerprint.jid,
                            device: fingerprint.deviceID,
                            label: value,
                          ),
                ),
              ),
            const SizedBox.square(dimension: 8),
            DisplayFingerprint(fingerprint: fingerprint.fingerprint),
            const SizedBox.square(dimension: 8),
            if (self)
              ShadButton.secondary(
                enabled: !state.regenerating,
                child: Text(
                  'Regenerate device',
                  style: TextStyle(
                    color: context.colorScheme.destructive,
                  ),
                ),
                onPressed: () async {
                  if (await confirm(
                        context,
                        text: 'Only do this if you are an expert.',
                      ) !=
                      true) {
                    return;
                  }
                  if (context.mounted) {
                    context.read<ProfileCubit>().regenerateDevice();
                  }
                },
              ).withTapBounce(enabled: !state.regenerating)
            else ...[
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
                    initialValue: fingerprint.trust,
                    onChanged: (trust) =>
                        context.read<VerificationCubit?>()?.setDeviceTrust(
                              jid: fingerprint.jid,
                              device: fingerprint.deviceID,
                              trust: trust!,
                            ),
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
              const SizedBox.square(dimension: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                spacing: 8.0,
                children: [
                  Icon(
                    fingerprint.trusted.toShieldIcon,
                    color: fingerprint.trusted
                        ? axiGreen
                        : context.colorScheme.destructive,
                  ),
                  Text(fingerprint.trusted ? 'Trusted' : 'Not trusted'),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}
