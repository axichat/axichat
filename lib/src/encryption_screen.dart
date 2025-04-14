import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/verification/bloc/verification_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class EncryptionScreen extends StatelessWidget {
  const EncryptionScreen({
    super.key,
    required this.locate,
    required this.jid,
  });

  final T Function<T>() locate;
  final String jid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text('Encryption for $jid'),
      ),
      body: SafeArea(
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => VerificationCubit(
                jid: jid,
                xmppService: locate<XmppService>(),
              ),
            ),
            BlocProvider.value(
              value: locate<ChatBloc>(),
            ),
          ],
          child: SingleChildScrollView(
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, state) {
                      if (state.chat == null) return const SizedBox.shrink();
                      return ShadSwitch(
                        padding: const EdgeInsets.all(12.0),
                        label: const Text('End-to-end Encrypted (OMEMO)'),
                        value: state.chat!.encryptionProtocol.isNotNone,
                        onChanged: (encrypted) => context.read<ChatBloc>().add(
                            ChatEncryptionChanged(
                                protocol: encrypted
                                    ? EncryptionProtocol.omemo
                                    : EncryptionProtocol.none)),
                      );
                    },
                  ),
                  BlocBuilder<VerificationCubit, VerificationState>(
                    builder: (context, state) {
                      if (state.loading) return const AxiProgressIndicator();
                      return Column(
                        children: [
                          for (final fingerprint in state.fingerprints)
                            AxiFingerprint(fingerprint: fingerprint),
                          ShadButton.destructive(
                            text: const Text('Recreate session'),
                            onPressed: context
                                .read<VerificationCubit>()
                                .recreateSession,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
