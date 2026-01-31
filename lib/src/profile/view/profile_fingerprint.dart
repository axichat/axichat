// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
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
  var _showFingerprint = false;

  @override
  void initState() {
    super.initState();
    context.read<ProfileCubit>().loadFingerprints();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        if (state.fingerprint == null) return const SizedBox.shrink();
        return ShadCard(
          rowCrossAxisAlignment: CrossAxisAlignment.center,
          columnCrossAxisAlignment: CrossAxisAlignment.center,
          rowMainAxisAlignment: MainAxisAlignment.center,
          columnMainAxisAlignment: MainAxisAlignment.center,
          padding: EdgeInsets.symmetric(horizontal: spacing.m),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.profileDeviceFingerprint,
                style: context.textTheme.small,
              ),
              ExpandIcon(
                isExpanded: _showFingerprint,
                onPressed: (_) => setState(() {
                  _showFingerprint = !_showFingerprint;
                }),
              ),
            ],
          ),
          child: AxiAnimatedSize(
            duration: context.watch<SettingsCubit>().animationDuration,
            child: _showFingerprint
                ? Padding(
                    padding: EdgeInsets.only(bottom: spacing.s),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: spacing.m,
                      children: [
                        Text(
                          context.l10n.verificationDeviceIdLabel(
                            state.fingerprint!.deviceID,
                          ),
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
