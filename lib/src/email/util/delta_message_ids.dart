// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

const String _deltaMessageStanzaPrefix = 'dc-msg';
const String _deltaMessageStanzaSeparator = '-';

String deltaMessageStanzaId(int msgId) =>
    '$_deltaMessageStanzaPrefix$_deltaMessageStanzaSeparator$msgId';
