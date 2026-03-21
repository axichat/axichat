// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

mixin PubSubService on XmppBase, BaseStreamService {
  static const PubSubSupport _assumedPubSubSupport = PubSubSupport(
    pubSubSupported: true,
    pepSupported: true,
    bookmarks2Supported: true,
  );

  @override
  PubSubSupport get pubSubSupport => _hasInitializedConnection
      ? _connection.getManager<PubSubManager>()?.support ??
            _assumedPubSubSupport
      : _assumedPubSubSupport;

  @override
  Stream<PubSubSupport> get pubSubSupportStream =>
      (_hasInitializedConnection
          ? _connection.getManager<PubSubManager>()?.supportStream
          : null) ??
      const Stream<PubSubSupport>.empty();

  @override
  Future<PubSubSupport> refreshPubSubSupport({bool force = false}) async {
    return _assumedPubSubSupport;
  }

  @override
  CapabilityDecision decidePubSubSupport({
    required bool supported,
    required String featureLabel,
  }) {
    return const CapabilityDecision(CapabilityDecisionKind.allowed);
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
