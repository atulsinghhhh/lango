/// Cross-language concept comparison (US-120, US-121).
///
/// A concept is language-neutral and each language contributes one entry, so
/// the model never assumes the pair is Korean and Japanese.
library;

/// How close the match between two languages' versions of a concept really is.
///
/// US-121: the system must not imply two structures are equivalent when they
/// only appear similar, so every concept states this explicitly instead of
/// letting a side-by-side layout imply equivalence.
enum Equivalence {
  /// The two structures really do the same job.
  close('close', 'Works the same way'),

  /// They overlap but diverge in ways that produce wrong sentences.
  partial('partial', 'Similar, with real differences'),

  /// They look related and are not.
  falseFriend('false_friend', 'Looks the same — is not');

  const Equivalence(this.code, this.label);

  final String code;
  final String label;

  static Equivalence fromCode(String code) => values.firstWhere(
        (e) => e.code == code,
        orElse: () => Equivalence.partial,
      );
}

enum ConceptKind {
  expression('expression', 'Expressions'),
  grammar('grammar', 'Grammar'),
  vocabulary('vocabulary', 'Word pairs');

  const ConceptKind(this.code, this.label);

  final String code;
  final String label;

  static ConceptKind fromCode(String code) => values.firstWhere(
        (k) => k.code == code,
        orElse: () => ConceptKind.expression,
      );
}

/// One language's version of a concept.
class ConceptEntry {
  const ConceptEntry({
    required this.language,
    required this.structure,
    required this.exampleNative,
    required this.exampleTranslation,
    this.literalGloss,
    this.note,
  });

  final String language;

  /// The pattern itself, e.g. `[place] + 에 + 가다`.
  final String structure;
  final String exampleNative;
  final String exampleTranslation;

  /// Word-by-word gloss, which is where the structural difference shows.
  final String? literalGloss;
  final String? note;

  factory ConceptEntry.fromJson(Map<String, dynamic> json) => ConceptEntry(
        language: json['language'] as String,
        structure: json['structure'] as String,
        exampleNative: json['example_native'] as String,
        exampleTranslation: json['example_translation'] as String,
        literalGloss: json['literal_gloss'] as String?,
        note: json['note'] as String?,
      );
}

class Concept {
  const Concept({
    required this.id,
    required this.kind,
    required this.english,
    required this.equivalence,
    this.keyDifference,
    this.similarity,
    this.entries = const [],
  });

  final String id;
  final ConceptKind kind;

  /// The English meaning both languages are being compared against.
  final String english;
  final Equivalence equivalence;

  /// The difference that actually changes what a learner should write.
  final String? keyDifference;

  /// The similarity that is genuinely there — stated only where it is real.
  final String? similarity;

  final List<ConceptEntry> entries;

  ConceptEntry? entryFor(String language) {
    for (final e in entries) {
      if (e.language == language) return e;
    }
    return null;
  }

  factory Concept.fromJson(Map<String, dynamic> json) => Concept(
        id: json['id'] as String,
        kind: ConceptKind.fromCode(json['kind'] as String),
        english: json['english'] as String,
        equivalence: Equivalence.fromCode(json['equivalence'] as String),
        keyDifference: json['key_difference'] as String?,
        similarity: json['similarity'] as String?,
        entries: (json['concept_entries'] as List?)
                ?.map((e) => ConceptEntry.fromJson(
                    (e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}
