const int _bidiLeftToRightEmbedding = 0x202a;
const int _bidiRightToLeftEmbedding = 0x202b;
const int _bidiPopDirectionalFormatting = 0x202c;
const int _bidiLeftToRightOverride = 0x202d;
const int _bidiRightToLeftOverride = 0x202e;
const int _bidiLeftToRightIsolate = 0x2066;
const int _bidiRightToLeftIsolate = 0x2067;
const int _bidiFirstStrongIsolate = 0x2068;
const int _bidiPopDirectionalIsolate = 0x2069;
const int _bidiLeftToRightMark = 0x200e;
const int _bidiRightToLeftMark = 0x200f;
const int _bidiArabicLetterMark = 0x061c;
const int _zeroWidthSpace = 0x200b;
const int _zeroWidthNonJoiner = 0x200c;
const int _zeroWidthJoiner = 0x200d;
const int _wordJoiner = 0x2060;
const int _zeroWidthNoBreakSpace = 0xfeff;
const int _mongolianVowelSeparator = 0x180e;

const Set<int> _bidiControlCodePoints = <int>{
  _bidiLeftToRightEmbedding,
  _bidiRightToLeftEmbedding,
  _bidiPopDirectionalFormatting,
  _bidiLeftToRightOverride,
  _bidiRightToLeftOverride,
  _bidiLeftToRightIsolate,
  _bidiRightToLeftIsolate,
  _bidiFirstStrongIsolate,
  _bidiPopDirectionalIsolate,
  _bidiLeftToRightMark,
  _bidiRightToLeftMark,
  _bidiArabicLetterMark,
};

const Set<int> _zeroWidthCodePoints = <int>{
  _zeroWidthSpace,
  _zeroWidthNonJoiner,
  _zeroWidthJoiner,
  _wordJoiner,
  _zeroWidthNoBreakSpace,
  _mongolianVowelSeparator,
};

bool containsBidiControlCharacters(String value) =>
    _containsUnicodeControls(value, _bidiControlCodePoints);

bool containsZeroWidthCharacters(String value) =>
    _containsUnicodeControls(value, _zeroWidthCodePoints);

bool containsUnicodeControlCharacters(String value) =>
    containsBidiControlCharacters(value) || containsZeroWidthCharacters(value);

bool _containsUnicodeControls(String value, Set<int> codePoints) {
  for (final rune in value.runes) {
    if (codePoints.contains(rune)) {
      return true;
    }
  }
  return false;
}
