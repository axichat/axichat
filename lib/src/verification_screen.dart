import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/verification/bloc/verification_cubit.dart';
import 'package:axichat/src/verification/view/verification_selector.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({
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
                omemoService: locate<XmppService>(),
              ),
            ),
          ],
          child: SingleChildScrollView(
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BlocBuilder<VerificationCubit, VerificationState>(
                    builder: (context, state) {
                      if (state.loading) return const AxiProgressIndicator();
                      return Column(
                        children: [
                          for (final fingerprint in state.fingerprints)
                            VerificationSelector(fingerprint: fingerprint),
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
