// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

const bool kEnableDemoChats =
    bool.fromEnvironment('ENABLE_DEMO_CHATS', defaultValue: false);

DateTime demoNow() {
  final now = DateTime.now();
  if (!kEnableDemoChats) return now;
  const int targetWeekday = DateTime.friday;
  final int deltaDays = targetWeekday - now.weekday;
  return now.add(Duration(days: deltaDays));
}

const String kDemoSelfJid = 'ben@axi.im';
const String kDemoSelfDisplayName = 'Ben';
const String kDemoDatabasePrefix = 'demo_ben';
const String kDemoDatabasePassphrase = 'axi_demo_passphrase_32byte_key__';
