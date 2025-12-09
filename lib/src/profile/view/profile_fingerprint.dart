import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
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

  var _showFingerprint = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        if (state.fingerprint == null) return const SizedBox.shrink();
        return ShadCard(
          rowCrossAxisAlignment: CrossAxisAlignment.center,
          columnCrossAxisAlignment: CrossAxisAlignment.center,
          rowMainAxisAlignment: MainAxisAlignment.center,
          columnMainAxisAlignment: MainAxisAlignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Device Fingerprint',
                style: context.textTheme.small,
              ),
              ExpandIcon(
                isExpanded: _showFingerprint,
                onPressed: (_) => setState(() {
                  _showFingerprint = !_showFingerprint;
                }),
              )
            ],
          ),
          child: AxiAnimatedSize(
            duration: context.watch<SettingsCubit>().animationDuration,
            child: _showFingerprint
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 12.0,
                      children: [
                        Text(
                          'Device #${state.fingerprint!.deviceID}',
                          style: context.textTheme.small,
                        ),
                        DisplayFingerprint(
                          fingerprint: state.fingerprint!.fingerprint,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
