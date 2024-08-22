import 'package:chat/src/app.dart';
import 'package:chat/src/authentication/view/logout_button.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/routes.dart';
import 'package:chat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) => active
          ? ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
              child: ListTile(
                leading: AxiAvatar(
                  jid: state.jid,
                  subscription: Subscription.both,
                  presence: state.presence,
                  status: state.status,
                  active: true,
                ),
                title: Text(state.title),
                subtitle: Text(
                  state.jid,
                  style: context.textTheme.muted,
                ),
                onTap: () => context.push(const ProfileRoute().location,
                    extra: context.read),
                shape: Border(
                  top: BorderSide(color: context.colorScheme.border),
                ),
                trailing: const LogoutButton(),
              ),
            )
          : ShadCard(
              rowMainAxisSize: MainAxisSize.max,
              columnCrossAxisAlignment: CrossAxisAlignment.center,
              leading: AxiAvatar(
                jid: state.jid,
                subscription: Subscription.both,
                presence: state.presence,
                status: state.status,
                active: true,
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.title),
                ],
              ),
              description: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            child: AxiTooltip(
                              builder: (_) => ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 300.0),
                                child: const Text(
                                  'This is your Jabber ID. Comprised of your '
                                  'username and domain, it\'s a unique address '
                                  'that represents you on the XMPP network.',
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              child: SelectableText(
                                state.jid,
                              ),
                            ),
                          ),
                          if (state.resource.isNotEmpty)
                            WidgetSpan(
                              child: AxiTooltip(
                                builder: (_) => ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 300.0),
                                  child: const Text(
                                    'This is your XMPP resource. Every device '
                                    'you use has a different one, which is why '
                                    'your phone can have a different presence '
                                    'to your desktop.',
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                child: Text(
                                  '/${state.resource}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300.0),
                child: AxiTextFormField(
                  placeholder: const Text('Status message'),
                  initialValue: state.status,
                  onSubmitted: (value) => context
                      .read<ProfileCubit>()
                      .updatePresence(status: value),
                ),
              ),
              trailing: const LogoutButton(),
            ),
    );
  }
}
