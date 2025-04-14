import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ProfileFingerprint extends StatefulWidget {
  const ProfileFingerprint({super.key});

  @override
  State<ProfileFingerprint> createState() => _ProfileFingerprintState();
}

class _ProfileFingerprintState extends State<ProfileFingerprint> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<ProfileCubit?>()?.loadFingerprints();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300.0),
          child: ShadCard(
            title: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'OMEMO:2 Fingerprints',
                  style: context.textTheme.table,
                ),
              ),
            ),
            description: Column(
              children: [
                AxiFingerprint(
                  fingerprint: OmemoFingerprint(
                    fingerprint: state.fingerprint,
                    deviceID: 0,
                    trust: BTBVTrustState.verified,
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
