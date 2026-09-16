import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lango/models/content.dart';
import 'package:lango/services/exercises/exercise_generator.dart';

VocabItem vocab(String id, String word, String translation,
        {String? example}) =>
    VocabItem(
      id: id,
      language: 'ko',
      word: word,
      translation: translation,
      exampleNative: example,
    );

void main() {
  final pool = [
    vocab('1', '먹다', 'to eat', example: '밥을 먹다.'),
    vocab('2', '가다', 'to go'),
    vocab('3', '학교', 'school'),
    vocab('4', '물', 'water'),
    vocab('5', '친구', 'friend'),
    vocab('6', '책', 'book'),
  ];

  group('ExerciseGenerator', () {
    test('produces the requested number of exercises', () {
      final gen = ExerciseGenerator(random: Random(42));
      expect(gen.buildSet(pool, count: 5).length, 5);
    });

    test('is reproducible with the same seed', () {
      final a = ExerciseGenerator(random: Random(1)).buildSet(pool, count: 6);
      final b = ExerciseGenerator(random: Random(1)).buildSet(pool, count: 6);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].item.id, b[i].item.id);
        expect(a[i].type, b[i].type);
        expect(a[i].choices, b[i].choices);
      }
    });

    test('covers all MVP exercise types', () {
      final gen = ExerciseGenerator(random: Random(7));
      final types = gen.buildSet(pool, count: 6).map((e) => e.type).toSet();
      expect(types.length, greaterThanOrEqualTo(3));
    });

    test('multiple choice always contains the correct answer', () {
      final gen = ExerciseGenerator(random: Random(3));
      for (final ex in gen.buildSet(pool, count: 8)) {
        if (ex.choices.isNotEmpty) {
          expect(ex.choices, contains(ex.answer));
          expect(ex.choices.toSet().length, ex.choices.length,
              reason: 'choices must be unique');
        }
      }
    });

    test('sentence completion blanks the word out of the example', () {
      final gen = ExerciseGenerator(random: Random(5));
      final all = List.generate(
              20, (i) => gen.buildSet(pool, count: 6))
          .expand((e) => e);
      final completion =
          all.where((e) => e.type == ExerciseType.sentenceCompletion);
      for (final ex in completion) {
        expect(ex.prompt, contains('___'));
        expect(ex.prompt, isNot(contains(ex.answer)));
      }
    });

    test('rejects pools that are too small for distractors', () {
      final gen = ExerciseGenerator(random: Random(0));
      expect(() => gen.buildSet(pool.take(3).toList()), throwsArgumentError);
    });
  });

  group('checkTypedAnswer', () {
    test('accepts exact match', () {
      expect(ExerciseGenerator.checkTypedAnswer('to eat', 'to eat'), isTrue);
    });

    test('ignores case, punctuation, extra whitespace', () {
      expect(
          ExerciseGenerator.checkTypedAnswer('  To  Eat! ', 'to eat'), isTrue);
    });

    test('accepts any variant of a multi-variant answer', () {
      expect(ExerciseGenerator.checkTypedAnswer('eat', 'to eat / eat'), isTrue);
      expect(ExerciseGenerator.checkTypedAnswer('meal', 'rice, meal'), isTrue);
    });

    test('accepts verb without leading "to"', () {
      expect(ExerciseGenerator.checkTypedAnswer('go', 'to go'), isTrue);
    });

    test('rejects wrong and empty answers', () {
      expect(ExerciseGenerator.checkTypedAnswer('to drink', 'to eat'), isFalse);
      expect(ExerciseGenerator.checkTypedAnswer('', 'to eat'), isFalse);
      expect(ExerciseGenerator.checkTypedAnswer('   ', 'to eat'), isFalse);
    });
  });
}
