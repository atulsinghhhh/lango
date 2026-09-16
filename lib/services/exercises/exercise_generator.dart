import 'dart:math';

import '../../models/content.dart';

/// MVP exercise types (US-022).
enum ExerciseType {
  multipleChoice('multiple_choice'),
  translation('translation'),
  typeAnswer('type_answer'),
  sentenceCompletion('sentence_completion');

  const ExerciseType(this.code);
  final String code;
}

class Exercise {
  const Exercise({
    required this.item,
    required this.type,
    required this.prompt,
    required this.answer,
    this.choices = const [],
    this.hint,
  });

  final VocabItem item;
  final ExerciseType type;
  final String prompt;
  final String answer;
  final List<String> choices; // empty for typeAnswer
  final String? hint;
}

/// Pure exercise generator. Seeded [Random] keeps output reproducible in
/// tests; UI code never contains generation logic.
class ExerciseGenerator {
  ExerciseGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<Exercise> buildSet(List<VocabItem> pool, {int count = 10}) {
    if (pool.length < 4) {
      throw ArgumentError('Need at least 4 vocabulary items for exercises.');
    }
    final items = [...pool]..shuffle(_random);
    final selected = items.take(count).toList();
    final exercises = <Exercise>[];
    for (var i = 0; i < selected.length; i++) {
      final type = ExerciseType.values[i % ExerciseType.values.length];
      exercises.add(_build(selected[i], type, pool));
    }
    return exercises;
  }

  Exercise _build(VocabItem item, ExerciseType type, List<VocabItem> pool) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return Exercise(
          item: item,
          type: type,
          prompt: item.word,
          answer: item.translation,
          choices: _choices(item, pool, (v) => v.translation),
        );
      case ExerciseType.translation:
        return Exercise(
          item: item,
          type: type,
          prompt: item.translation,
          answer: item.word,
          choices: _choices(item, pool, (v) => v.word),
        );
      case ExerciseType.typeAnswer:
        return Exercise(
          item: item,
          type: type,
          prompt: item.word,
          answer: item.translation,
          hint: item.romanization,
        );
      case ExerciseType.sentenceCompletion:
        final example = item.exampleNative;
        if (example == null || !example.contains(item.word)) {
          // No usable sentence — degrade gracefully to multiple choice.
          return _build(item, ExerciseType.multipleChoice, pool);
        }
        return Exercise(
          item: item,
          type: type,
          prompt: example.replaceFirst(item.word, '___'),
          answer: item.word,
          choices: _choices(item, pool, (v) => v.word),
          hint: item.exampleTranslation,
        );
    }
  }

  List<String> _choices(
      VocabItem correct, List<VocabItem> pool, String Function(VocabItem) f) {
    final distractors = pool
        .where((v) => v.id != correct.id && f(v) != f(correct))
        .map(f)
        .toSet()
        .toList()
      ..shuffle(_random);
    final options = [f(correct), ...distractors.take(3)]..shuffle(_random);
    return options;
  }

  /// Lenient comparison for typed answers: case/whitespace/punctuation
  /// insensitive, and any single variant ("to eat / eat") counts.
  static bool checkTypedAnswer(String input, String expected) {
    final normalizedInput = _normalize(input);
    if (normalizedInput.isEmpty) return false;
    final variants = expected
        .split(RegExp(r'[/,;]'))
        .map(_normalize)
        .where((v) => v.isNotEmpty);
    for (final v in variants) {
      if (normalizedInput == v) return true;
      // Accept dropping a leading "to " on verbs ("eat" for "to eat").
      if (v.startsWith('to ') && normalizedInput == v.substring(3)) {
        return true;
      }
    }
    return false;
  }

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp("[.!?,。、･…\"']"), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
