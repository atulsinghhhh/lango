import '../../models/language.dart';

/// Languages the TTS service can speak.
///
/// Deliberately its own type rather than [TargetLanguage]: English is a
/// language the app *speaks* (glosses, instructions) but never a language the
/// learner is studying, so the two sets are not the same. Passing raw strings
/// around instead would let a typo reach the service and come back as a 422 at
/// runtime; this way the compiler catches it.
enum TtsLanguage {
  english('en', 'en-US'),
  korean('ko', 'ko-KR'),
  japanese('ja', 'ja-JP');

  const TtsLanguage(this.code, this.deviceLocale);

  /// The code the service expects, matching MagpieTTS's own language codes.
  final String code;

  /// Platform locale, used only by the on-device fallback voice.
  final String deviceLocale;

  /// The study language's TTS counterpart.
  static TtsLanguage of(TargetLanguage language) => switch (language) {
        TargetLanguage.korean => TtsLanguage.korean,
        TargetLanguage.japanese => TtsLanguage.japanese,
      };

  static TtsLanguage? fromCode(String code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }
}
