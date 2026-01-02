import 'package:axichat/src/storage/models.dart';

const String _deltaMessageStanzaPrefix = 'dc-msg';
const String _deltaMessageStanzaSeparator = '-';

String deltaMessageStanzaId(
  int msgId, {
  required int accountId,
}) {
  if (accountId == deltaAccountIdLegacy) {
    return '$_deltaMessageStanzaPrefix$_deltaMessageStanzaSeparator$msgId';
  }
  return '$_deltaMessageStanzaPrefix$_deltaMessageStanzaSeparator'
      '$accountId$_deltaMessageStanzaSeparator$msgId';
}
