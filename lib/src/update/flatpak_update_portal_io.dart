// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/update/flatpak_update_portal.dart';
import 'package:dbus/dbus.dart';

Future<bool> isFlatpakSandbox() async {
  if (!Platform.isLinux) {
    return false;
  }
  return File('/.flatpak-info').exists();
}

FlatpakUpdatePortal? createFlatpakUpdatePortal() {
  if (!Platform.isLinux) {
    return null;
  }
  return const _DBusFlatpakUpdatePortal();
}

final class _DBusFlatpakUpdatePortal implements FlatpakUpdatePortal {
  const _DBusFlatpakUpdatePortal();

  @override
  Future<FlatpakUpdateMonitor> createUpdateMonitor() async {
    final client = DBusClient.session();
    final object = DBusRemoteObject(
      client,
      name: 'org.freedesktop.portal.Flatpak',
      path: DBusObjectPath('/org/freedesktop/portal/Flatpak'),
    );
    final response = await object.callMethod(
      'org.freedesktop.portal.Flatpak',
      'CreateUpdateMonitor',
      [DBusDict.stringVariant(const <String, DBusValue>{})],
      replySignature: DBusSignature('o'),
    );
    final monitorPath = response.returnValues[0].asObjectPath();
    return _DBusFlatpakUpdateMonitor(client: client, path: monitorPath);
  }
}

final class _DBusFlatpakUpdateMonitor implements FlatpakUpdateMonitor {
  _DBusFlatpakUpdateMonitor({
    required DBusClient client,
    required DBusObjectPath path,
  }) : _client = client,
       _object = DBusRemoteObject(
         client,
         name: 'org.freedesktop.portal.Flatpak',
         path: path,
       ),
       updateAvailable = DBusRemoteObjectSignalStream(
         object: DBusRemoteObject(
           client,
           name: 'org.freedesktop.portal.Flatpak',
           path: path,
         ),
         interface: 'org.freedesktop.portal.Flatpak.UpdateMonitor',
         name: 'UpdateAvailable',
         signature: DBusSignature('a{sv}'),
       ).asBroadcastStream().map(_mapUpdateInfo);

  final DBusClient _client;
  final DBusRemoteObject _object;

  @override
  final Stream<FlatpakUpdateInfo> updateAvailable;

  @override
  Future<void> update({String parentWindow = ''}) async {
    await _object.callMethod(
      'org.freedesktop.portal.Flatpak.UpdateMonitor',
      'Update',
      [
        DBusString(parentWindow),
        DBusDict.stringVariant(const <String, DBusValue>{}),
      ],
      replySignature: DBusSignature(''),
    );
  }

  @override
  Future<void> close() async {
    try {
      await _object.callMethod(
        'org.freedesktop.portal.Flatpak.UpdateMonitor',
        'Close',
        const [],
        replySignature: DBusSignature(''),
      );
    } finally {
      await _client.close();
    }
  }

  static FlatpakUpdateInfo _mapUpdateInfo(DBusSignal signal) {
    final values = signal.values[0].asStringVariantDict();
    return FlatpakUpdateInfo(
      runningCommit: values['running-commit']?.asString(),
      localCommit: values['local-commit']?.asString(),
      remoteCommit: values['remote-commit']?.asString(),
    );
  }
}
