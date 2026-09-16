import 'package:flutter_tts/flutter_tts.dart';

import '../models/language.dart';

/// On-device text-to-speech used for pronunciation playback and listening
/// exercises. Recorded/native audio can replace this later via
/// vocabulary.audio_url without changing callers.
class TtsService {
  final FlutterTts _tts = FlutterTts();

  Future<void> speak(String text, TargetLanguage language) async {
    await _tts.stop();
    await _tts.setLanguage(language.ttsLocale);
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
