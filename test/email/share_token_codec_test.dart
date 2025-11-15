import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generateShareId returns 26-char ULID string', () {
    final shareId = ShareTokenCodec.generateShareId();
    expect(shareId.length, 26);
    expect(RegExp(r'^[0-9A-Z]+$').hasMatch(shareId), isTrue);
  });

  test('injectToken + stripToken round trip', () {
    const token = '01HX5R8W7YAYR5K1R7Q7MB5G4W';
    const body = 'Hello team';
    final decorated = ShareTokenCodec.injectToken(token: token, body: body);
    expect(decorated.startsWith('[s:$token]'), isTrue);
    final parsed = ShareTokenCodec.stripToken(decorated);
    expect(parsed, isNotNull);
    expect(parsed!.token, token);
    expect(parsed.cleanedBody, body);
  });

  test('subjectToken reuses ULID shareId as capability token', () {
    const shareId = '01HX5R8W7YAYR5K1R7Q7MB5G4W';
    expect(ShareTokenCodec.subjectToken(shareId), shareId);
    final parsed = ShareTokenCodec.stripToken('[s:$shareId]');
    expect(parsed, isNotNull);
    expect(parsed!.token, shareId);
  });

  test('subjectToken rejects identifiers without enough entropy', () {
    expect(
      () => ShareTokenCodec.subjectToken('share-xyz'),
      throwsArgumentError,
    );
  });
}
