// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:chat/src/common/capability.dart';
import 'package:chat/src/common/policy.dart';
import 'package:chat/src/storage/impatient_completer.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Table, Column;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart' hide BlocObserver;
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:moxxmpp_socket_tcp/moxxmpp_socket_tcp.dart' as mox_tcp;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:retry/retry.dart' show RetryOptions;
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:uuid/uuid.dart';

import 'src/app.dart';

part 'main.freezed.dart';
part 'main.g.dart';
part 'src/storage/credential_store.dart';
part 'src/storage/database.dart';
part 'src/storage/models.dart';
part 'src/storage/state_store.dart';
part 'src/xmpp/blocking_service.dart';
part 'src/xmpp/presence_service.dart';
part 'src/xmpp/roster_service.dart';
part 'src/xmpp/xmpp_service.dart';

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

  final xmppService = XmppService._(
    'draugr.de',
    buildCredentialStore: CredentialStore._,
    buildStateStore: (username, passphrase) async {
      await Hive.initFlutter(storagePrefixFor(username));
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PresenceAdapter());
      }
      await Hive.openBox(
        _XmppStateStore.boxName,
        encryptionCipher: HiveAesCipher(utf8.encode(passphrase)),
      );
      return _XmppStateStore._();
    },
    buildDatabase: _XmppDatabase._,
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
