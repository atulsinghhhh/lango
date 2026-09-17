import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lango/models/language.dart';
import 'package:lango/services/tts/tts_api_client.dart';
import 'package:lango/services/tts/tts_language.dart';

void main() {
  const base = 'https://tts.example.com';

  TtsApiClient client(
    Future<http.Response> Function(http.Request) handler, {
    String? token = 'jwt-token',
    String baseUrl = base,
  }) =>
      TtsApiClient(
        baseUrl: baseUrl,
        accessToken: () => token,
        httpClient: MockClient(handler),
      );

  http.Response ok({
    String url = 'https://storage.example/ko/ab/abc.mp3?token=x',
    String language = 'ko',
    bool cached = false,
    double? duration = 1.25,
  }) =>
      http.Response(
        jsonEncode({
          'audio_url': url,
          'language': language,
          'cached': cached,
          'format': 'mp3',
          'duration_seconds': duration,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );

  group('TtsLanguage', () {
    test('maps every study language to a service code', () {
      expect(TtsLanguage.of(TargetLanguage.korean).code, 'ko');
      expect(TtsLanguage.of(TargetLanguage.japanese).code, 'ja');
    });

    test('includes English, which is not a study language', () {
      expect(TtsLanguage.english.code, 'en');
      expect(TtsLanguage.values.map((l) => l.code), ['en', 'ko', 'ja']);
    });

    test('round-trips through its code', () {
      for (final language in TtsLanguage.values) {
        expect(TtsLanguage.fromCode(language.code), language);
      }
      expect(TtsLanguage.fromCode('de'), isNull);
    });

    test('carries a device locale for the fallback voice', () {
      expect(TtsLanguage.korean.deviceLocale, 'ko-KR');
      expect(TtsLanguage.japanese.deviceLocale, 'ja-JP');
      expect(TtsLanguage.english.deviceLocale, 'en-US');
    });
  });

  group('TtsApiClient request', () {
    test('posts the text and language verbatim to /v1/tts', () async {
      late http.Request seen;
      final api = client((request) async {
        seen = request;
        return ok();
      });

      await api.generateSpeech(text: '학교에 가요', language: TtsLanguage.korean);

      expect(seen.method, 'POST');
      expect(seen.url.toString(), '$base/v1/tts');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      // The service must synthesize exactly what was asked for.
      expect(body['text'], '학교에 가요');
      expect(body['language'], 'ko');
      expect(body.containsKey('voice'), isFalse);
    });

    test('sends the Supabase access token as a bearer token', () async {
      late http.Request seen;
      final api = client((request) async {
        seen = request;
        return ok();
      });

      await api.generateSpeech(text: 'hi', language: TtsLanguage.english);

      expect(seen.headers['authorization'], 'Bearer jwt-token');
      // No API key may ever be sent from the app.
      expect(seen.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-api-key')));
      expect(seen.body, isNot(contains('api_key')));
    });

    test('includes a voice only when one is chosen', () async {
      late http.Request seen;
      final api = client((request) async {
        seen = request;
        return ok();
      });

      await api.generateSpeech(
          text: 'hi', language: TtsLanguage.english, voice: 'Leo');

      expect(jsonDecode(seen.body)['voice'], 'Leo');
    });
  });

  group('TtsApiClient responses', () {
    test('returns the audio URL and cache flag', () async {
      final api = client((_) async => ok(cached: true));
      final audio =
          await api.generateSpeech(text: 'hi', language: TtsLanguage.korean);

      expect(audio.url, 'https://storage.example/ko/ab/abc.mp3?token=x');
      expect(audio.language, TtsLanguage.korean);
      expect(audio.cached, isTrue);
      expect(audio.durationSeconds, 1.25);
    });

    test('tolerates a missing duration', () async {
      final api = client((_) async => ok(duration: null));
      final audio =
          await api.generateSpeech(text: 'hi', language: TtsLanguage.korean);
      expect(audio.durationSeconds, isNull);
    });

    test('falls back to the requested language if the reply omits it',
        () async {
      final api = client((_) async => http.Response(
            jsonEncode({'audio_url': 'https://a/b.mp3', 'cached': false}),
            200,
          ));
      final audio =
          await api.generateSpeech(text: 'hi', language: TtsLanguage.japanese);
      expect(audio.language, TtsLanguage.japanese);
    });
  });

  group('TtsApiClient failures', () {
    Future<TtsFailure> reasonFor(
      Future<http.Response> Function(http.Request) handler, {
      String? token = 'jwt-token',
      String baseUrl = base,
    }) async {
      final api = client(handler, token: token, baseUrl: baseUrl);
      try {
        await api.generateSpeech(text: 'hi', language: TtsLanguage.korean);
        fail('expected TtsUnavailable');
      } on TtsUnavailable catch (error) {
        return error.reason;
      }
    }

    test('an unconfigured build never makes a request', () async {
      var called = false;
      final reason = await reasonFor((_) async {
        called = true;
        return ok();
      }, baseUrl: '');

      expect(reason, TtsFailure.notConfigured);
      expect(called, isFalse);
    });

    test('a signed-out learner is unauthorized without a round trip', () async {
      var called = false;
      final reason = await reasonFor((_) async {
        called = true;
        return ok();
      }, token: null);

      expect(reason, TtsFailure.unauthorized);
      expect(called, isFalse);
    });

    test('401 and 403 are reported as unauthorized', () async {
      expect(await reasonFor((_) async => http.Response('{}', 401)),
          TtsFailure.unauthorized);
      expect(await reasonFor((_) async => http.Response('{}', 403)),
          TtsFailure.unauthorized);
    });

    test('429 is reported as rate limited', () async {
      expect(await reasonFor((_) async => http.Response('{}', 429)),
          TtsFailure.rateLimited);
    });

    test('server errors are reported as a service error', () async {
      for (final status in [500, 502, 503, 504]) {
        expect(await reasonFor((_) async => http.Response('{}', status)),
            TtsFailure.serviceError);
      }
    });

    test('a malformed body is a service error, not a crash', () async {
      expect(await reasonFor((_) async => http.Response('not json', 200)),
          TtsFailure.serviceError);
      expect(await reasonFor((_) async => http.Response('{}', 200)),
          TtsFailure.serviceError);
      expect(
          await reasonFor(
              (_) async => http.Response(jsonEncode({'audio_url': ''}), 200)),
          TtsFailure.serviceError);
    });

    test('a network failure is reported as offline', () async {
      expect(
          await reasonFor((_) async => throw const SocketExceptionStub()),
          TtsFailure.offline);
    });
  });
}

/// Stand-in for a socket failure; `http` surfaces these as ClientException in
/// production, and the client treats any transport error as offline.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
