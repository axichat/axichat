import 'package:chat/src/app.dart';
import 'package:chat/src/common/capability.dart';
import 'package:chat/src/common/shorebird_push.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:chat/src/connectivity/view/connectivity_indicator.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/profile/view/profile_card.dart';
import 'package:chat/src/settings/bloc/settings_cubit.dart';
import 'package:chat/src/settings/view/settings_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.locate});

  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: RepositoryProvider.value(
          value: locate<Capability>(),
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(
                value: locate<ProfileCubit>(),
              ),
              BlocProvider.value(
                value: locate<ConnectivityCubit>(),
              ),
              BlocProvider.value(
                value: locate<SettingsCubit>(),
              ),
            ],
            child: const SingleChildScrollView(
              child: _ProfileBody(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody();

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  var mustRestart = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        return PopScope(
          canPop: !mustRestart,
          onPopInvoked: (didPop) => didPop
              ? null
              : showShadDialog(
                  context: context,
                  builder: (_) => const ShadDialog.alert(
                    title: Text('You must restart the app'),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const ConnectivityIndicator(),
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: ProfileCard(),
              ),
              // const Padding(
              //   padding: EdgeInsets.all(12.0),
              //   child: ProfileFingerprint(),
              // ),
              FutureBuilder(
                future: checkShorebird(context.read<Capability>()),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AxiProgressIndicator(),
                          SizedBox.square(
                            dimension: 8.0,
                          ),
                          Text('Checking for updates'),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.requireData) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: mustRestart
                        ? const Text('Restart the app')
                        : RichText(
                            text: TextSpan(
                              style: context.textTheme.small,
                              children: [
                                const TextSpan(text: 'Update available: '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: AxiLinkDetector(
                                    onTap: () => showShadDialog(
                                      context: context,
                                      builder: (_) => ShadDialog(
                                        title: const Text('Disconnect'),
                                        description: const Text(
                                          'Are you sure? You must restart the app afterwards',
                                        ),
                                        actions: [
                                          ShadButton.outline(
                                            onPressed: context.pop,
                                            text: const Text('Cancel'),
                                          ),
                                          ShadButton.destructive(
                                            onPressed: () async {
                                              await context
                                                  .read<ProfileCubit>()
                                                  .disconnect();
                                              setState(() {
                                                mustRestart = true;
                                              });
                                              if (context.mounted) {
                                                context.pop();
                                              }
                                            },
                                            text: const Text(
                                              'Continue',
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    child: const Text(
                                      'disconnect',
                                      style: TextStyle(
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const TextSpan(
                                  text: ' and restart the app.',
                                ),
                              ],
                            ),
                          ),
                  );
                },
              ),
              ShadButton.ghost(
                onPressed: () {
                  showAboutDialog(
                    context: context,
                    applicationName: appDisplayName,
                  );
                },
                text: const Text('Legal'),
              ),
              const SizedBox(height: 8),
              const SettingsControls(),
            ],
          ),
        );
      },
    );
  }
}
