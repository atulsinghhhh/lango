import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/language.dart';

/// Why speech recognition is not usable right now, so the UI can say which
/// problem it is instead of a generic failure (REDESIGN.md §28).
enum SpeechUnavailableReason {
  /// The device has no recogniser, or the user declined the microphone.
  notAvailable,

  /// The recogniser works but has no model for this language.
  languageNotSupported,
}

class SpeechUnavailable implements Exception {
  const SpeechUnavailable(this.reason);
  final SpeechUnavailableReason reason;
}

/// One transcript from the recogniser.
class SpeechTranscript {
  const SpeechTranscript({
    required this.text,
    required this.isFinal,
    this.confidence,
  });

  final String text;
  final bool isFinal;

  /// The recogniser's confidence in **its own transcript**, 0–1, or null when
  /// the platform does not report one.
  ///
  /// This is not a pronunciation score and must never be presented as one: a
  /// low value means the recogniser was unsure what it heard, which can happen
  /// to a perfectly pronounced sentence in a noisy room (US-081).
  final double? confidence;
}

/// On-device speech recognition for speaking practice (US-080).
///
/// Wraps the platform recogniser (iOS Speech, Android SpeechRecognizer). There
/// is no server and no API key: audio is handled by the platform, and what
/// comes back is a transcript.
class SpeechService {
  SpeechService([SpeechToText? speech]) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;

  bool get isListening => _speech.isListening;
  bool get isAvailable => _speech.isAvailable;

  /// Initialise the recogniser and resolve the platform's locale id for
  /// [language].
  ///
  /// Throws [SpeechUnavailable] rather than returning a bare false, so callers
  /// can tell "no microphone permission" from "no Korean model installed".
  Future<String> prepare(TargetLanguage language) async {
    if (!_initialized) {
      _initialized = await _speech.initialize(
        // Errors during a listen session are surfaced through `start`'s
        // onError; this callback only exists so initialize() reports failure
        // rather than throwing from inside the plugin.
        onError: (_) {},
        finalTimeout: const Duration(seconds: 2),
      );
    }
    if (!_initialized) {
      throw const SpeechUnavailable(SpeechUnavailableReason.notAvailable);
    }

    final localeId = await _resolveLocale(language);
    if (localeId == null) {
      throw const SpeechUnavailable(
          SpeechUnavailableReason.languageNotSupported);
    }
    return localeId;
  }

  /// Start listening. [onResult] fires for partial results as well as the
  /// final one; check [SpeechTranscript.isFinal].
  Future<void> start({
    required String localeId,
    required void Function(SpeechTranscript) onResult,
    void Function()? onDone,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(SpeechTranscript(
          text: result.recognizedWords,
          isFinal: result.finalResult,
          confidence: _confidence(result.confidence),
        ));
        if (result.finalResult) onDone?.call();
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        // A target sentence, not a single command.
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        listenFor: listenFor,
        pauseFor: pauseFor,
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();

  /// The platforms report "confidence unavailable" as -1, and Android often
  /// reports 0 for the same thing. Both become null: an unknown confidence is
  /// not a confidence of zero.
  static double? _confidence(double raw) => raw > 0 ? raw : null;

  /// Match the platform's locale list against the target language.
  ///
  /// Platforms disagree on separators (`ko_KR` vs `ko-KR`) and on which region
  /// they ship, so match on the language subtag and prefer the app's preferred
  /// region when it is offered.
  Future<String?> _resolveLocale(TargetLanguage language) async {
    final locales = await _speech.locales();
    if (locales.isEmpty) return null;

    final preferred = language.ttsLocale.toLowerCase().replaceAll('_', '-');
    String? fallback;
    for (final locale in locales) {
      final id = locale.localeId.toLowerCase().replaceAll('_', '-');
      if (id == preferred) return locale.localeId;
      if (id.split('-').first == language.code) {
        fallback ??= locale.localeId;
      }
    }
    return fallback;
  }
}
