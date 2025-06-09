import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/verification/bloc/verification_cubit.dart';
import 'package:axichat/src/verification/view/verification_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VerificationList extends StatelessWidget {
  const VerificationList({
    super.key,
    required this.jid,
  });

  final String? jid;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VerificationCubit, VerificationState>(
      builder: (context, state) {
        if (jid == null) return const SizedBox.shrink();
        if (state.loading) return const Center(child: AxiProgressIndicator());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          spacing: 16.0,
          children: [
            const SizedBox.square(dimension: 8.0),
            Text(
              'Expert settings',
              style: context.textTheme.h4,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'If you verify a device, no other devices will receive '
                'your messages until you verify them as well!',
                textAlign: TextAlign.center,
                style: context.textTheme.muted,
              ),
            ),
            DefaultTabController(
              length: 2,
              animationDuration:
                  context.watch<SettingsCubit>().animationDuration,
              child: Expanded(
                child: Column(
                  children: [
                    TabBar(
                      dividerHeight: 0.0,
                      indicatorColor: context.colorScheme.primary,
                      tabs: const [
                        Tab(text: 'Theirs'),
                        Tab(text: 'Yours'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          if (state.fingerprints.isEmpty)
                            Center(
                              child: Text(
                                'No devices found',
                                style: context.textTheme.muted,
                              ),
                            )
                          else
                            SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: state.fingerprints
                                    .map(
                                      (e) => Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: VerificationSelector(
                                            fingerprint: e),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          if (state.myFingerprints.isEmpty)
                            Center(
                              child: Text(
                                'No devices found',
                                style: context.textTheme.muted,
                              ),
                            )
                          else
                            SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: state.myFingerprints
                                    .map((e) => Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: VerificationSelector(
                                              fingerprint: e),
                                        ))
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
