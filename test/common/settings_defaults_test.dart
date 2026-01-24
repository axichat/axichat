import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const SettingsState state = SettingsState();

  group('SettingsState defaults', () {
    test('blocks remote email images by default', () {
      const expectAutoLoadEmailImages = false;
      expect(state.autoLoadEmailImages, expectAutoLoadEmailImages);
    });

    test('keeps archive auto-download disabled by default', () {
      const expectAutoDownloadArchives = false;
      expect(
        state.autoDownloadArchives,
        expectAutoDownloadArchives,
      );
    });
  });
}
