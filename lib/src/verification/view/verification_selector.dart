// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/bool_tool.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
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
    final l10n = context.l10n;
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final colors = context.colorScheme;
        final self =
            state.fingerprint?.deviceID == fingerprint.deviceID &&
            state.fingerprint?.jid == fingerprint.jid;
        return ShadCard(
          columnMainAxisSize: MainAxisSize.min,
          rowMainAxisSize: MainAxisSize.min,
          border: self
              ? null
              : ShadBorder.fromBorderSide(
                  ShadBorderSide(
                    color: fingerprint.trust.color(colors),
                    width: context.borderSide.width,
                    style: context.borderSide.style,
                    strokeAlign: context.borderSide.strokeAlign,
                  ),
                ),
          child: Column(
            spacing: 8.0,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                l10n.verificationDeviceIdLabel(fingerprint.deviceID.toString()),
              ),
              const SizedBox.square(dimension: 8),
              if (self)
                Text(l10n.verificationCurrentDevice)
              else
                SizedBox(
                  width: 200.0,
                  child: AxiTextFormField(
                    initialValue: fingerprint.label,
                    placeholder: Text(l10n.verificationAddLabelPlaceholder),
                    onSubmitted: (value) =>
                        context.read<VerificationCubit>().labelFingerprint(
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
                AxiButton.secondary(
                  loading: state.regenerating,
                  child: Text(
                    l10n.verificationRegenerateDevice,
                    style: TextStyle(color: context.colorScheme.destructive),
                  ),
                  onPressed: () async {
                    if (await confirm(
                          context,
                          text: l10n.verificationRegenerateWarning,
                        ) !=
                        true) {
                      return;
                    }
                    if (context.mounted) {
                      context.read<ProfileCubit>().regenerateDevice();
                    }
                  },
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8.0,
                  children: [
                    Icon(
                      fingerprint.trust.iconData(),
                      color: fingerprint.trust.color(colors),
                    ),
                    AxiSelect<BTBVTrustState>(
                      initialValue: fingerprint.trust,
                      onChanged: (trust) =>
                          context.read<VerificationCubit>().setDeviceTrust(
                            jid: fingerprint.jid,
                            device: fingerprint.deviceID,
                            trust: trust!,
                          ),
                      options: BTBVTrustState.values
                          .map(
                            (trust) => ShadOption<BTBVTrustState>(
                              value: trust,
                              child: Text(trust.label(l10n)),
                            ),
                          )
                          .toList(),
                      selectedOptionBuilder:
                          (BuildContext context, BTBVTrustState value) =>
                              Text(value.label(l10n)),
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
                          ? colors.green
                          : colors.destructive,
                    ),
                    Text(
                      fingerprint.trusted
                          ? l10n.verificationTrusted
                          : l10n.verificationNotTrusted,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

extension _TrustStateLocalization on BTBVTrustState {
  String label(AppLocalizations l10n) => switch (this) {
    BTBVTrustState.notTrusted => l10n.verificationTrustNone,
    BTBVTrustState.blindTrust => l10n.verificationTrustBlind,
    BTBVTrustState.verified => l10n.verificationTrustVerified,
  };

  IconData iconData() => switch (this) {
    BTBVTrustState.notTrusted => LucideIcons.shieldX,
    BTBVTrustState.blindTrust => LucideIcons.shieldQuestionMark,
    BTBVTrustState.verified => LucideIcons.shieldCheck,
  };

  Color color(ShadColorScheme colors) => switch (this) {
    BTBVTrustState.notTrusted => colors.destructive,
    BTBVTrustState.blindTrust => colors.warning,
    BTBVTrustState.verified => colors.green,
  };
}
