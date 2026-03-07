import 'package:axichat/src/demo/demo_chats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'demo mode includes a long scroll debug chat with the earliest message pinned',
    () {
      final script = DemoChats.scriptFor('scroll-debug@axi.im');

      expect(script, isNotNull);
      expect(script!.messages.length, greaterThan(200));
      expect(script.messages.last.stanzaID, 'demo-scroll-1');
      expect(script.pinnedMessageStanzaIds, contains('demo-scroll-1'));
    },
  );
}
