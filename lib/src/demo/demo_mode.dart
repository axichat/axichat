// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

const bool kEnableDemoChats = bool.fromEnvironment(
  'ENABLE_DEMO_CHATS',
  defaultValue: false,
);

DateTime demoNow() {
  final now = DateTime.now();
  if (!kEnableDemoChats) return now;
  const int targetWeekday = DateTime.friday;
  final int daysBack =
      (now.weekday - targetWeekday + DateTime.daysPerWeek) %
      DateTime.daysPerWeek;
  final targetDate = now.subtract(Duration(days: daysBack));
  final anchored = DateTime(
    targetDate.year,
    targetDate.month,
    targetDate.day,
    17,
    31,
  );
  if (anchored.isAfter(now)) {
    return anchored.subtract(const Duration(days: DateTime.daysPerWeek));
  }
  return anchored;
}

const String kDemoSelfJid = 'ben@axi.im';
const String kDemoSelfDisplayName = 'Ben';
const String kDemoDatabasePrefix = 'demo_ben';
const String kDemoDatabasePassphrase = 'axi_demo_passphrase_32byte_key__';
