// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:moxxmpp/moxxmpp.dart' as mox;

abstract interface class PubSubHubDelegate {
  Future<void> close();
}

abstract interface class PubSubHubEventDelegate implements PubSubHubDelegate {
  bool handlesPubSubEvent(mox.XmppEvent event);
}

final class PubSubHubManager extends mox.XmppManagerBase {
  PubSubHubManager(List<mox.XmppManagerBase> delegates)
    : _delegates = List<mox.XmppManagerBase>.unmodifiable(delegates),
      super(managerId);

  static const String managerId = 'axi.pubsub.hub';

  final List<mox.XmppManagerBase> _delegates;

  @override
  void register(mox.XmppManagerAttributes attributes) {
    super.register(attributes);
    for (final delegate in _delegates) {
      delegate.register(attributes);
    }
  }

  @override
  Future<void> postRegisterCallback() async {
    await super.postRegisterCallback();
    for (final delegate in _delegates) {
      if (delegate.initialized) {
        continue;
      }
      await delegate.postRegisterCallback();
    }
  }

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> onXmppEvent(mox.XmppEvent event) async {
    for (final delegate in _delegates) {
      if (delegate case final PubSubHubEventDelegate routedDelegate) {
        if (!routedDelegate.handlesPubSubEvent(event)) {
          continue;
        }
      }
      await delegate.onXmppEvent(event);
    }
  }

  T? getDelegate<T extends mox.XmppManagerBase>() {
    for (final delegate in _delegates) {
      if (delegate is T) {
        return delegate;
      }
    }
    return null;
  }

  Future<void> close() async {
    for (final delegate in _delegates) {
      if (delegate case final PubSubHubDelegate closeable) {
        await closeable.close();
      }
    }
  }
}
