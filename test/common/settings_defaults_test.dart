import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

const bool _expectAutoLoadEmailImages = false;
const bool _expectAutoDownloadArchives = false;

void main() {
  const SettingsState state = SettingsState();

  group('SettingsState defaults', () {
    test('blocks remote email images by default', () {
      expect(state.autoLoadEmailImages, _expectAutoLoadEmailImages);
    });

    test('keeps archive auto-download disabled by default', () {
      expect(state.autoDownloadArchives, _expectAutoDownloadArchives);
    });
  });
}
