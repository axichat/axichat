import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:shadcn_ui/shadcn_ui.dart';

enum AvatarTemplateCategory { abstract, stem, sports, music, misc }

typedef AvatarTemplateBuilder = Future<GeneratedAvatar> Function(
  Color background,
  ShadColorScheme colors,
);

class AvatarTemplate {
  const AvatarTemplate({
    required this.id,
    required this.label,
    required this.category,
    required this.hasAlphaBackground,
    required this.generator,
  });

  final String id;
  final String label;
  final AvatarTemplateCategory category;
  final bool hasAlphaBackground;
  final AvatarTemplateBuilder generator;
}

class GeneratedAvatar {
  const GeneratedAvatar({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.hasAlpha,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
  final bool hasAlpha;
}

class _AvatarAsset {
  const _AvatarAsset({
    required this.id,
    required this.label,
    required this.category,
    required this.assetPath,
    required this.hasAlphaBackground,
  });

  final String id;
  final String label;
  final AvatarTemplateCategory category;
  final String assetPath;
  final bool hasAlphaBackground;

  AvatarTemplate toTemplate() {
    return AvatarTemplate(
      id: id,
      label: label,
      category: category,
      hasAlphaBackground: hasAlphaBackground,
      generator: (background, _) => _loadAssetAvatar(
        assetPath: assetPath,
        background: background,
        applyBackground: hasAlphaBackground,
      ),
    );
  }
}

List<AvatarTemplate> buildDefaultAvatarTemplates() =>
    _avatarAssets.map((asset) => asset.toTemplate()).toList();

const _avatarAssets = [
  _AvatarAsset(
    id: 'abstract-1',
    label: 'Abstract 1',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract1.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-2',
    label: 'Abstract 2',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract2.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-3',
    label: 'Abstract 3',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract3.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-4',
    label: 'Abstract 4',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract4.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-5',
    label: 'Abstract 5',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract5.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-6',
    label: 'Abstract 6',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract6.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-7',
    label: 'Abstract 7',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract7.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-8',
    label: 'Abstract 8',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract8.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-9',
    label: 'Abstract 9',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract9.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-10',
    label: 'Abstract 10',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract10.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-11',
    label: 'Abstract 11',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract11.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-12',
    label: 'Abstract 12',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract12.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-13',
    label: 'Abstract 13',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract13.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-14',
    label: 'Abstract 14',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract14.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-16',
    label: 'Abstract 16',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract16.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-17',
    label: 'Abstract 17',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract17.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'abstract-18',
    label: 'Abstract 18',
    category: AvatarTemplateCategory.abstract,
    assetPath: 'assets/images/avatars/abstract/abstract18.png',
    hasAlphaBackground: false,
  ),
  _AvatarAsset(
    id: 'stem-atom',
    label: 'Atom',
    category: AvatarTemplateCategory.stem,
    assetPath: 'assets/images/avatars/stem/atom.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'stem-beaker',
    label: 'Beaker',
    category: AvatarTemplateCategory.stem,
    assetPath: 'assets/images/avatars/stem/beaker.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'stem-compass',
    label: 'Compass',
    category: AvatarTemplateCategory.stem,
    assetPath: 'assets/images/avatars/stem/compass.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'stem-cpu',
    label: 'CPU',
    category: AvatarTemplateCategory.stem,
    assetPath: 'assets/images/avatars/stem/cpu.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'stem-gear',
    label: 'Gear',
    category: AvatarTemplateCategory.stem,
    assetPath: 'assets/images/avatars/stem/gear.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'stem-globe',
    label: 'Globe',
    category: AvatarTemplateCategory.stem,
    assetPath: 'assets/images/avatars/stem/globe.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'stem-laptop',
    label: 'Laptop',
    category: AvatarTemplateCategory.stem,
    assetPath: 'assets/images/avatars/stem/laptop.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'stem-microscope',
    label: 'Microscope',
    category: AvatarTemplateCategory.stem,
    assetPath: 'assets/images/avatars/stem/microscope.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'stem-robot',
    label: 'Robot',
    category: AvatarTemplateCategory.stem,
    assetPath: 'assets/images/avatars/stem/robot.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'stem-stethoscope',
    label: 'Stethoscope',
    category: AvatarTemplateCategory.stem,
    assetPath: 'assets/images/avatars/stem/stethoscope.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'stem-telescope',
    label: 'Telescope',
    category: AvatarTemplateCategory.stem,
    assetPath: 'assets/images/avatars/stem/telescope.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-archery',
    label: 'Archery',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/archery.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-baseball',
    label: 'Baseball',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/baseball.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-basketball',
    label: 'Basketball',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/basketball.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-boxing',
    label: 'Boxing',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/boxing.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-cycling',
    label: 'Cycling',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/cycling.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-darts',
    label: 'Darts',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/darts.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-football',
    label: 'Football',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/football.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-golf',
    label: 'Golf',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/golf.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-pingpong',
    label: 'Ping Pong',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/pingpong.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-ski',
    label: 'Skiing',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/ski.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-soccer',
    label: 'Soccer',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/soccer.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-tennis',
    label: 'Tennis',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/tennis.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'sports-volleyball',
    label: 'Volleyball',
    category: AvatarTemplateCategory.sports,
    assetPath: 'assets/images/avatars/sport/volleyball.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'music-drum',
    label: 'Drums',
    category: AvatarTemplateCategory.music,
    assetPath: 'assets/images/avatars/music/drum.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'music-electricguitar',
    label: 'Electric Guitar',
    category: AvatarTemplateCategory.music,
    assetPath: 'assets/images/avatars/music/electricguitar.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'music-guitar',
    label: 'Guitar',
    category: AvatarTemplateCategory.music,
    assetPath: 'assets/images/avatars/music/guitar.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'music-microphone',
    label: 'Microphone',
    category: AvatarTemplateCategory.music,
    assetPath: 'assets/images/avatars/music/microphone.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'music-piano',
    label: 'Piano',
    category: AvatarTemplateCategory.music,
    assetPath: 'assets/images/avatars/music/piano.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'music-saxophone',
    label: 'Saxophone',
    category: AvatarTemplateCategory.music,
    assetPath: 'assets/images/avatars/music/saxophone.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'music-violin',
    label: 'Violin',
    category: AvatarTemplateCategory.music,
    assetPath: 'assets/images/avatars/music/violin.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'misc-cards',
    label: 'Cards',
    category: AvatarTemplateCategory.misc,
    assetPath: 'assets/images/avatars/misc/cards.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'misc-chess',
    label: 'Chess',
    category: AvatarTemplateCategory.misc,
    assetPath: 'assets/images/avatars/misc/chess.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'misc-chess2',
    label: 'Chess Alt',
    category: AvatarTemplateCategory.misc,
    assetPath: 'assets/images/avatars/misc/chess2.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'misc-dice',
    label: 'Dice',
    category: AvatarTemplateCategory.misc,
    assetPath: 'assets/images/avatars/misc/dice.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'misc-dice2',
    label: 'Dice Alt',
    category: AvatarTemplateCategory.misc,
    assetPath: 'assets/images/avatars/misc/dice2.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'misc-esports',
    label: 'Esports',
    category: AvatarTemplateCategory.misc,
    assetPath: 'assets/images/avatars/misc/esports.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'misc-sword',
    label: 'Sword',
    category: AvatarTemplateCategory.misc,
    assetPath: 'assets/images/avatars/misc/sword.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'misc-videogames',
    label: 'Video Games',
    category: AvatarTemplateCategory.misc,
    assetPath: 'assets/images/avatars/misc/videogames.png',
    hasAlphaBackground: true,
  ),
  _AvatarAsset(
    id: 'misc-videogames2',
    label: 'Video Games Alt',
    category: AvatarTemplateCategory.misc,
    assetPath: 'assets/images/avatars/misc/videogames2.png',
    hasAlphaBackground: true,
  ),
];

Future<GeneratedAvatar> _loadAssetAvatar({
  required String assetPath,
  required Color background,
  required bool applyBackground,
}) async {
  final data = await rootBundle.load(assetPath);
  final decoded = img.decodeImage(data.buffer.asUint8List());
  if (decoded == null) {
    throw StateError('Failed to decode avatar asset at $assetPath');
  }
  final needsBackground = applyBackground && decoded.hasAlpha;
  final processed =
      needsBackground ? _composeOnBackground(decoded, background) : decoded;
  final encoded = Uint8List.fromList(img.encodePng(processed));
  return GeneratedAvatar(
    bytes: encoded,
    mimeType: 'image/png',
    width: processed.width,
    height: processed.height,
    hasAlpha: applyBackground && processed.hasAlpha,
  );
}

img.Image _composeOnBackground(img.Image image, Color background) {
  final canvas = img.Image(
    width: image.width,
    height: image.height,
    numChannels: 4,
    format: img.Format.uint8,
  );
  img.fill(canvas, color: _imgColor(background));
  img.compositeImage(canvas, image);
  return canvas;
}

img.Color _imgColor(Color color) => img.ColorUint8.rgba(
      _channelToByte(color.r),
      _channelToByte(color.g),
      _channelToByte(color.b),
      _channelToByte(color.a),
    );

int _channelToByte(num channel) {
  final scaled = channel <= 1.0 ? channel * 255.0 : channel;
  return scaled.round().clamp(0, 255);
}
