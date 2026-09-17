import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tts_language.dart';

/// Why a request for speech could not be served, in terms the UI can act on.
enum TtsFailure {
  /// No `TTS_API_BASE_URL` was configured for this build.
  notConfigured,

  /// The device could not reach the service.
  offline,

  /// The learner's session was rejected. Usually an expired token.
  unauthorized,

  /// Too many new phrases in a short window.
  rateLimited,

  /// The service is up but could not generate this clip.
  serviceError,
}

class TtsUnavailable implements Exception {
  const TtsUnavailable(this.reason);
  final TtsFailure reason;

  @override
  String toString() => 'TtsUnavailable(${reason.name})';
}

/// One generated clip.
class TtsAudio {
  const TtsAudio({
    required this.url,
    required this.language,
    required this.cached,
    this.durationSeconds,
  });

  /// Short-lived signed URL into the private audio bucket.
  final String url;
  final TtsLanguage language;

  /// True when the service already had this clip stored.
  final bool cached;
  final double? durationSeconds;
}

/// HTTP client for the Lango TTS service.
///
/// Knows nothing about which model runs, where it runs, or how the audio is
/// stored — only that `POST /v1/tts` returns a URL. That boundary is what lets
/// the GPU fleet change without touching the app.
///
/// Authenticates with the learner's existing Supabase access token. There is
/// no API key in this client, and there must never be one: anything shipped in
/// the app is readable by anyone who downloads it.
class TtsApiClient {
  TtsApiClient({
    required this.baseUrl,
    required this.accessToken,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;

  /// Reads the learner's current Supabase access token.
  ///
  /// A callback rather than the Supabase client itself: this layer holds no
  /// credential of its own, needs nothing else from Supabase, and stays
  /// testable without a live session. There is nothing in this class worth
  /// extracting from the app bundle.
  final String? Function() accessToken;

  final http.Client _http;
  final Duration timeout;

  bool get isConfigured => baseUrl.isNotEmpty;

  Future<TtsAudio> generateSpeech({
    required String text,
    required TtsLanguage language,
    String? voice,
  }) async {
    if (!isConfigured) {
      throw const TtsUnavailable(TtsFailure.notConfigured);
    }

    final token = accessToken();
    if (token == null) {
      throw const TtsUnavailable(TtsFailure.unauthorized);
    }

    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('$baseUrl/v1/tts'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'text': text,
              'language': language.code,
              'voice': ?voice,
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const TtsUnavailable(TtsFailure.offline);
    } catch (_) {
      throw const TtsUnavailable(TtsFailure.offline);
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw const TtsUnavailable(TtsFailure.unauthorized);
      case 429:
        throw const TtsUnavailable(TtsFailure.rateLimited);
      default:
        throw const TtsUnavailable(TtsFailure.serviceError);
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const TtsUnavailable(TtsFailure.serviceError);
    }

    final url = body['audio_url'];
    if (url is! String || url.isEmpty) {
      throw const TtsUnavailable(TtsFailure.serviceError);
    }

    return TtsAudio(
      url: url,
      language: TtsLanguage.fromCode(body['language'] as String? ?? '') ??
          language,
      cached: body['cached'] == true,
      durationSeconds: (body['duration_seconds'] as num?)?.toDouble(),
    );
  }

  void dispose() => _http.close();
}
