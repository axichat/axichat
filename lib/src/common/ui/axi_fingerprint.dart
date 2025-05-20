import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/verification/bloc/verification_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension on BTBVTrustState {
  IconData get toIcon => switch (this) {
        BTBVTrustState.notTrusted => LucideIcons.shieldAlert,
        BTBVTrustState.blindTrust => LucideIcons.shieldQuestion,
        BTBVTrustState.verified => LucideIcons.shieldCheck,
      };
}

class AxiFingerprint extends StatelessWidget {
  const AxiFingerprint({super.key, required this.fingerprint});

  final OmemoFingerprint fingerprint;

  @override
  Widget build(BuildContext context) {
    if (fingerprint.fingerprint.isEmpty) return const SizedBox.shrink();
    final strings = [];
    for (var i = 0; i < fingerprint.fingerprint.length; i += 8) {
      strings.add(fingerprint.fingerprint.substring(i, i + 8).toUpperCase());
    }

    return Container(
      padding: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colorScheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GridView(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 7.0,
            ),
            children: strings
                .map(
                  (e) => Text(
                    e,
                    textAlign: TextAlign.center,
                    style: context.textTheme.small
                        .copyWith(color: stringToColor(e)),
                  ),
                )
                .toList(),
          ),
          ListTile(
            leading: Icon(fingerprint.trust.toIcon),
            trailing: ShadSelect<BTBVTrustState>(
              anchor: const ShadAnchorAuto(preferBelow: false),
              initialValue: fingerprint.trust,
              onChanged: (trust) => context
                  .read<VerificationCubit>()
                  .setDeviceTrust(device: fingerprint.deviceID, trust: trust),
              options: BTBVTrustState.values
                  .map((trust) => ShadOption<BTBVTrustState>(
                        value: trust,
                        child: Text(trust.name),
                      ))
                  .toList(),
              selectedOptionBuilder:
                  (BuildContext context, BTBVTrustState value) =>
                      Text(value.name),
            ),
          ),
        ],
      ),
    );
  }
}
