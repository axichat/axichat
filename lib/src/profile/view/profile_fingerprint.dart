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
  var _loading = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) => _loading = false,
      builder: (context, state) {
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
          child: AnimatedSize(
            duration: context.watch<SettingsCubit>().animationDuration,
            child: _showFingerprint
                ? Column(
                    children: [
                      DisplayFingerprint(fingerprint: state.fingerprint),
                      const SizedBox.square(dimension: 16.0),
                      ShadButton.secondary(
                        enabled: !_loading,
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
                            setState(() {
                              _loading = true;
                            });
                            await context
                                .read<ProfileCubit>()
                                .regenerateDevice();
                          }
                        },
                      ),
                      const SizedBox.square(dimension: 8.0),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
