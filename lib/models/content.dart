/// Learning-content models. All content rows are language-tagged data,
/// never hard-coded per language.
library;

class VocabItem {
  const VocabItem({
    required this.id,
    required this.language,
    required this.word,
    required this.translation,
    this.romanization,
    this.pronunciation,
    this.partOfSpeech,
    this.difficulty = 1,
    this.exampleNative,
    this.exampleTranslation,
    this.audioUrl,
    this.tags = const [],
  });

  final String id;
  final String language;
  final String word;
  final String translation;
  final String? romanization;
  final String? pronunciation;
  final String? partOfSpeech;
  final int difficulty;
  final String? exampleNative;
  final String? exampleTranslation;
  final String? audioUrl;
  final List<String> tags;

  factory VocabItem.fromJson(Map<String, dynamic> json) => VocabItem(
        id: json['id'] as String,
        language: json['language'] as String,
        word: json['word'] as String,
        translation: json['translation'] as String,
        romanization: json['romanization'] as String?,
        pronunciation: json['pronunciation'] as String?,
        partOfSpeech: json['part_of_speech'] as String?,
        difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
        exampleNative: json['example_native'] as String?,
        exampleTranslation: json['example_translation'] as String?,
        audioUrl: json['audio_url'] as String?,
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      );
}

class GrammarExample {
  const GrammarExample({required this.native, required this.translation});

  final String native;
  final String translation;

  factory GrammarExample.fromJson(Map<String, dynamic> json) =>
      GrammarExample(
        native: json['native'] as String,
        translation: json['translation'] as String,
      );
}

class GrammarPoint {
  const GrammarPoint({
    required this.id,
    required this.language,
    required this.name,
    required this.meaning,
    required this.explanation,
    this.difficulty = 1,
    this.examples = const [],
  });

  final String id;
  final String language;
  final String name;
  final String meaning;
  final String explanation;
  final int difficulty;
  final List<GrammarExample> examples;

  factory GrammarPoint.fromJson(Map<String, dynamic> json) => GrammarPoint(
        id: json['id'] as String,
        language: json['language'] as String,
        name: json['name'] as String,
        meaning: json['meaning'] as String,
        explanation: json['explanation'] as String,
        difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
        examples: (json['grammar_examples'] as List?)
                ?.map((e) =>
                    GrammarExample.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class CharacterItem {
  const CharacterItem({
    required this.id,
    required this.language,
    required this.script,
    required this.character,
    required this.romanization,
    this.pronunciationHint,
    this.exampleWord,
    this.exampleTranslation,
    this.strokeCount,
    this.sortOrder = 0,
    this.meanings = const [],
    this.readings = const {},
    this.levelLabel,
  });

  final String id;
  final String language;
  final String script; // hangul_consonant, hangul_vowel, hiragana, katakana
  final String character;
  final String romanization;
  final String? pronunciationHint;
  final String? exampleWord;
  final String? exampleTranslation;

  /// Null unless we have a verified count — never estimated (CLAUDE.md).
  final int? strokeCount;
  final int sortOrder;

  /// English meanings. Empty for alphabetic scripts, where [romanization]
  /// already carries the sound and there is no meaning to give.
  final List<String> meanings;

  /// Reading groups keyed by reading type — `{'on': [...], 'kun': [...]}` for
  /// kanji. Empty for scripts that have a single reading.
  final Map<String, List<String>> readings;

  /// Curriculum level, e.g. "JLPT N5". Null when the script is not levelled.
  final String? levelLabel;

  bool get isLogographic => meanings.isNotEmpty || readings.isNotEmpty;

  factory CharacterItem.fromJson(Map<String, dynamic> json) => CharacterItem(
        id: json['id'] as String,
        language: json['language'] as String,
        script: json['script'] as String,
        character: json['character'] as String,
        romanization: json['romanization'] as String,
        pronunciationHint: json['pronunciation_hint'] as String?,
        exampleWord: json['example_word'] as String?,
        exampleTranslation: json['example_translation'] as String?,
        strokeCount: (json['stroke_count'] as num?)?.toInt(),
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        meanings: (json['meanings'] as List?)?.cast<String>() ?? const [],
        readings: _readings(json['readings']),
        levelLabel: json['level_label'] as String?,
      );

  static Map<String, List<String>> _readings(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is List)
          entry.key as String: (entry.value as List).cast<String>(),
    };
  }
}

/// Script codes, as stored in `characters.script`, to words a learner
/// recognises.
///
/// Shared rather than declared per screen, because the same script is named in
/// the writing browser, the beginner path and the practice screen, and three
/// copies drift. Unknown codes fall through to the code itself tidied up, so a
/// script added to the catalog tomorrow still renders without a code change.
const _scriptNames = <String, ({String heading, String standalone})>{
  'hangul_consonant': (heading: 'Consonants', standalone: 'Hangul consonants'),
  'hangul_vowel': (heading: 'Vowels', standalone: 'Hangul vowels'),
  'hiragana': (heading: 'Hiragana', standalone: 'Hiragana'),
  'katakana': (heading: 'Katakana', standalone: 'Katakana'),
  'kanji': (heading: 'Kanji', standalone: 'Kanji'),
};

/// Short form, for use where the language and writing system are already
/// obvious from the surrounding screen — "Consonants" under a Korean heading.
String scriptHeading(String script) =>
    _scriptNames[script]?.heading ?? _tidyScriptCode(script);

/// Full form, for use on its own — "Hangul consonants" in a list that also
/// contains Japanese.
String scriptLabel(String script) =>
    _scriptNames[script]?.standalone ?? _tidyScriptCode(script);

/// `hangul_consonant` → `Hangul consonant`. Only reached for a script the map
/// does not know, which is better than showing a raw snake_case code.
String _tidyScriptCode(String script) {
  if (script.isEmpty) return script;
  final spaced = script.replaceAll('_', ' ');
  return spaced[0].toUpperCase() + spaced.substring(1);
}
