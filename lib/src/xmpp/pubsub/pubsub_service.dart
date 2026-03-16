// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

mixin PubSubService on XmppBase, BaseStreamService {
  @override
  PubSubSupport get pubSubSupport =>
      _connection.getManager<PubSubManager>()?.support ??
      const PubSubSupport(
        pubSubSupported: false,
        pepSupported: false,
        bookmarks2Supported: false,
      );

  @override
  Stream<PubSubSupport> get pubSubSupportStream =>
      _connection.getManager<PubSubManager>()?.supportStream ??
      const Stream<PubSubSupport>.empty();

  @override
  Future<PubSubSupport> refreshPubSubSupport({bool force = false}) async {
    final manager = _connection.getManager<PubSubManager>();
    if (manager == null) {
      return pubSubSupport;
    }
    return manager.refreshSupport(
      force: force,
      selfJid: _myJid,
      demoOffline: demoOfflineMode,
    );
  }

  @override
  CapabilityDecision decidePubSubSupport({
    required bool supported,
    required String featureLabel,
  }) {
    final manager = _connection.getManager<PubSubManager>();
    if (manager == null) {
      return const CapabilityDecision(CapabilityDecisionKind.unknown);
    }
    return manager.decideSupport(
      supported: supported,
      featureLabel: featureLabel,
    );
  }

  @override
  List<mox.XmppManagerBase> get featureManagers {
    final managers = pubSubFeatureManagers;
    return <mox.XmppManagerBase>[
      ...super.featureManagers,
      PubSubManager(),
      if (managers.isNotEmpty) PubSubHubManager(managers),
    ];
  }
}
