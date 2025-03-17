import 'dart:isolate';

import 'package:chat/src/common/policy.dart';
import 'package:chat/src/notifications/bloc/notification_service.dart';
import 'package:chat/src/storage/credential_store.dart';
import 'package:chat/src/storage/state_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

class MockXmppConnection extends Mock implements XmppConnection {}

class MockCredentialStore extends Mock implements CredentialStore {}

class MockXmppStateStore extends Mock implements XmppStateStore {}

class MockNotificationService extends Mock implements NotificationService {}

class MockCapability extends Mock implements Capability {}

class MockPolicy extends Mock implements Policy {}

class FakeCredentialKey extends Fake implements RegisteredCredentialKey {}

class FakeStateKey extends Fake implements RegisteredStateKey {}

class FakeUserAgent extends Fake implements mox.UserAgent {}

