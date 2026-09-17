import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../models/language.dart';
import 'tts/tts_api_client.dart';
import 'tts/tts_language.dart';

/// Pronunciation playback.
///
/// Speech comes from the Lango TTS service (NVIDIA MagpieTTS Multilingual),
/// which returns a URL to generated audio; this plays it. Callers pass text and
/// a language and get sound — they know nothing about HTTP, the model, or where
/// the audio is stored.
///
/// The on-device voice remains as a fallback for when the service cannot be
/// reached. It is a different voice, so it is a degraded experience rather than
/// an equivalent one — but for a learner mid-lesson on a bad connection,
/// hearing the word in a platform voice beats hearing nothing. Set
/// [fallbackToDevice] to false to make failures audible-silent instead.
class TtsService {
  TtsService({
    required this.api,
    AudioPlayer? player,
    FlutterTts? onDevice,
    this.fallbackToDevice = true,
  })  : _player = player ?? AudioPlayer(),
        _onDevice = onDevice ?? FlutterTts();

  final TtsApiClient api;
  final AudioPlayer _player;
  final FlutterTts _onDevice;
  final bool fallbackToDevice;

  /// Set when the last request fell back to the device voice, so a screen can
  /// mention it if it wants to. Null after a successful remote playback.
  TtsFailure? lastFallbackReason;

  /// Speak text in one of the learner's study languages.
  ///
  /// Signature unchanged from the on-device implementation, so every existing
  /// caller keeps working.
  Future<void> speak(String text, TargetLanguage language) =>
      speakIn(text, TtsLanguage.of(language));

  /// Speak text in any language the service supports, including English.
  Future<void> speakIn(String text, TtsLanguage language) async {
    if (text.trim().isEmpty) return;
    await stop();

    try {
      final audio = await api.generateSpeech(text: text, language: language);
      await _player.setUrl(audio.url);
      await _player.play();
      lastFallbackReason = null;
      return;
    } on TtsUnavailable catch (error) {
      lastFallbackReason = error.reason;
      if (!fallbackToDevice) rethrow;
      debugPrint('TTS service unavailable (${error.reason.name}); '
          'using the device voice.');
    } catch (error) {
      // A playback failure (bad codec, expired URL) is also worth falling back
      // on rather than leaving the learner with silence.
      lastFallbackReason = TtsFailure.serviceError;
      if (!fallbackToDevice) rethrow;
      debugPrint('TTS playback failed; using the device voice.');
    }

    await _speakOnDevice(text, language);
  }

  Future<void> _speakOnDevice(String text, TtsLanguage language) async {
    await _onDevice.stop();
    await _onDevice.setLanguage(language.deviceLocale);
    await _onDevice.setSpeechRate(0.45);
    await _onDevice.speak(text);
  }

  Future<void> stop() async {
    await _player.stop();
    await _onDevice.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _onDevice.stop();
    api.dispose();
  }
}
