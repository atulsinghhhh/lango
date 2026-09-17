import 'package:flutter_test/flutter_test.dart';
import 'package:lango/services/exercises/dictation_checker.dart';
import 'package:lango/services/speech/speech_comparison.dart';

void main() {
  group('SpeechComparison.tokenize', () {
    test('splits spaced text into words', () {
      expect(SpeechComparison.tokenize('오늘 커피를 마셨어요.'),
          ['오늘', '커피를', '마셨어요']);
    });

    test('splits unspaced text into characters', () {
      expect(SpeechComparison.tokenize('今日はコーヒーを飲みました。'),
          '今日はコーヒーを飲みました'.split(''));
    });

    test('drops punctuation from both scripts', () {
      expect(SpeechComparison.tokenize('네, 맞아요!'), ['네', '맞아요']);
      expect(SpeechComparison.tokenize('はい。'), ['は', 'い']);
    });

    test('keeps the chōonpu, which is a letter and not a dash', () {
      expect(SpeechComparison.tokenize('コーヒー'), ['コ', 'ー', 'ヒ', 'ー']);
      expect(SpeechComparison.equivalent('コーヒー', 'コヒ'), isFalse);
    });

    test('an empty or punctuation-only string has no tokens', () {
      expect(SpeechComparison.tokenize(''), isEmpty);
      expect(SpeechComparison.tokenize('  …!? '), isEmpty);
    });
  });

  group('SpeechComparison.compare', () {
    test('an exact match reports nothing wrong', () {
      final r = SpeechComparison.compare('오늘 커피를 마셨어요', '오늘 커피를 마셨어요');
      expect(r.isExact, isTrue);
      expect(r.matchRatio, 1.0);
      expect(r.tokens.every((t) => t.status == TokenStatus.matched), isTrue);
    });

    test('punctuation and case differences are not mistakes', () {
      final r = SpeechComparison.compare('오늘 커피를 마셨어요.', '오늘 커피를 마셨어요');
      expect(r.isExact, isTrue);
    });

    test('a dropped word is reported as missing, not as incorrect', () {
      final r = SpeechComparison.compare('오늘 커피를 마셨어요', '커피를 마셨어요');
      expect(r.missing, ['오늘']);
      expect(r.incorrect, isEmpty);
      expect(r.extra, isEmpty);
      expect(r.matchRatio, closeTo(2 / 3, 0.001));
    });

    test('an added word is reported as extra', () {
      final r = SpeechComparison.compare('커피를 마셨어요', '오늘 커피를 마셨어요');
      expect(r.extra, ['오늘']);
      expect(r.missing, isEmpty);
      expect(r.matchRatio, 1.0);
    });

    test('a swapped word is a substitution, not a missing plus an extra', () {
      final r = SpeechComparison.compare('오늘 커피를 마셨어요', '오늘 우유를 마셨어요');
      expect(r.incorrect, hasLength(1));
      expect(r.incorrect.single.expected, '커피를');
      expect(r.incorrect.single.heard, '우유를');
      expect(r.missing, isEmpty);
      expect(r.extra, isEmpty);
    });

    test('every target token appears in order with its outcome', () {
      final r = SpeechComparison.compare('오늘 커피를 마셨어요', '오늘 우유를');
      expect(r.tokens.map((t) => t.expected), ['오늘', '커피를', '마셨어요']);
      expect(r.tokens.map((t) => t.status), [
        TokenStatus.matched,
        TokenStatus.incorrect,
        TokenStatus.missing,
      ]);
    });

    test('an empty transcript loses everything without crashing', () {
      final r = SpeechComparison.compare('오늘 커피를 마셨어요', '');
      expect(r.matchRatio, 0);
      expect(r.missing, hasLength(3));
      expect(r.incorrect, isEmpty);
    });

    test('an empty target is not scored as a perfect match', () {
      final r = SpeechComparison.compare('', '오늘 커피');
      expect(r.matchRatio, 0);
      expect(r.extra, ['오늘', '커피']);
    });

    test('works character-wise on Japanese', () {
      final r =
          SpeechComparison.compare('今日はコーヒーを飲みました', '今日はコーヒーを飲みます');
      expect(r.matchRatio, greaterThan(0.7));
      expect(r.isExact, isFalse);
    });
  });

  group('SpeechComparison.equivalent', () {
    test('ignores punctuation, case and spacing', () {
      expect(SpeechComparison.equivalent('학교에 가요.', '학교에 가요'), isTrue);
      expect(SpeechComparison.equivalent('학교에가요', '학교에 가요'), isTrue);
      expect(SpeechComparison.equivalent('I Ate', 'i ate'), isTrue);
    });

    test('does not ignore a different word', () {
      expect(SpeechComparison.equivalent('학교에 가요', '학교에 와요'), isFalse);
    });
  });

  group('DictationChecker', () {
    test('accepts an answer that differs only in formatting', () {
      final r = DictationChecker.check('학교에가요', '학교에 가요.');
      expect(r.correct, isTrue);
    });

    test('rejects a wrong particle and reports where', () {
      final r = DictationChecker.check('학교에서 가요', '학교에 가요');
      expect(r.correct, isFalse);
      expect(r.comparison.incorrect.single.expected, '학교에');
      expect(r.comparison.incorrect.single.heard, '학교에서');
    });

    test('a mostly-right answer is flagged as a near miss', () {
      final r = DictationChecker.check('오늘 커피를 마셨어', '오늘 커피를 마셨어요');
      expect(r.correct, isFalse);
      expect(r.isNearMiss, isTrue);
    });

    test('an unrelated answer is not a near miss', () {
      final r = DictationChecker.check('안녕하세요', '오늘 커피를 마셨어요');
      expect(r.correct, isFalse);
      expect(r.isNearMiss, isFalse);
    });

    test('an empty answer is never correct', () {
      expect(DictationChecker.check('', '학교에 가요').correct, isFalse);
      expect(DictationChecker.check('   ', '학교에 가요').correct, isFalse);
    });
  });
}
