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
  });

  final String id;
  final String language;
  final String script; // hangul_consonant, hangul_vowel, hiragana, katakana
  final String character;
  final String romanization;
  final String? pronunciationHint;
  final String? exampleWord;
  final String? exampleTranslation;
  final int? strokeCount;
  final int sortOrder;

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
      );
}
