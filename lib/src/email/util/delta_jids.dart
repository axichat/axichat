const String deltaDomain = 'delta.chat';
const String deltaUserDomain = 'user.delta.chat';
const String deltaSelfLocalPart = 'dc-self';
const String deltaAnonLocalPart = 'dc-anon';

const String deltaSelfJid = '$deltaSelfLocalPart@$deltaDomain';
const String deltaSelfUserJid = '$deltaSelfLocalPart@$deltaUserDomain';
const String deltaAnonJid = '$deltaAnonLocalPart@$deltaDomain';
const String deltaAnonUserJid = '$deltaAnonLocalPart@$deltaUserDomain';

const List<String> deltaPlaceholderJids = <String>[
  deltaSelfJid,
  deltaSelfUserJid,
  deltaAnonJid,
  deltaAnonUserJid,
];

extension DeltaJidExtensions on String {
  String get normalizedDeltaJid => trim().toLowerCase();

  bool get isDeltaPlaceholderJid =>
      deltaPlaceholderJids.contains(normalizedDeltaJid);
}
