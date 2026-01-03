// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

const bool kEnableDemoChats =
    bool.fromEnvironment('ENABLE_DEMO_CHATS', defaultValue: false);

const String kDemoSelfJid = 'franklin@axi.im';
const String kDemoSelfDisplayName = 'Franklin';
const String kDemoDatabasePrefix = 'demo_franklin';
const String kDemoDatabasePassphrase = 'axi_demo_passphrase_32byte_key__';
