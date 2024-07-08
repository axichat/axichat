// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:chat/src/common/capability.dart';
import 'package:chat/src/common/policy.dart';
import 'package:chat/src/storage/credential_store.dart';
import 'package:chat/src/storage/database.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/storage/state_store.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Table, Column;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart' hide BlocObserver;
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(
    (record) => kDebugMode
        ? print('${record.level.name}: ${record.time}: ${record.message}')
        : null,
  );
  final log = Logger('main');
  Bloc.observer = BlocLogger(log);

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: await getApplicationDocumentsDirectory(),
  );

  final capability = Capability();
  final policy = Policy();

  final xmppService = XmppService(
    'draugr.de',
    buildConnection: () => XmppConnection(),
    buildCredentialStore: () => CredentialStore(
      capability: capability,
      policy: policy,
    ),
    buildStateStore: (username, passphrase) async {
      await Hive.initFlutter(storagePrefixFor(username));
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PresenceAdapter());
      }
      await Hive.openBox(
        XmppStateStore.boxName,
        encryptionCipher: HiveAesCipher(utf8.encode(passphrase)),
      );
      return XmppStateStore();
    },
    buildDatabase: (username, passphrase) {
      return XmppDatabase(
        username: username,
        passphrase: passphrase,
      );
    },
    capability: Capability(),
    policy: Policy(),
  );

  try {
    await xmppService.login(null, null);
  } on XmppUserNotFoundException catch (_) {
    log.info('Redirecting to login screen...');
  }

  runApp(Axichat(xmppService: xmppService));
}

class BlocLogger extends BlocObserver {
  BlocLogger(this.logger);

  final Logger logger;

  @override
  void onChange(BlocBase bloc, Change change) {
    logger.info('${bloc.runtimeType} $change');
    super.onChange(bloc, change);
  }
}
