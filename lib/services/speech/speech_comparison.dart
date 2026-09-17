/// Comparison between a target sentence and what was actually produced
/// (US-081 for speaking, US-071 for dictation).
///
/// **This measures text, not pronunciation.** For speaking, the input is a
/// speech recogniser's transcript, so a mismatch can mean the learner said the
/// wrong thing *or* that the recogniser misheard a correct utterance. Nothing
/// in this file estimates pronunciation accuracy, and callers must not present
/// its output as if it did (CLAUDE.md invariant; US-081).
///
/// Pure and deterministic: no I/O, no clock, no platform calls, so the
/// behaviour is fully covered by `test/speech_comparison_test.dart`.
library;

/// How one token of the target fared.
enum TokenStatus {
  /// Present in the transcript.
  matched,

  /// Absent from the transcript.
  missing,

  /// Something else appeared in its place.
  incorrect,
}

/// A target token paired with its outcome, for rendering the target sentence
/// with each part marked.
class ComparedToken {
  const ComparedToken({
    required this.expected,
    required this.status,
    this.heard,
  });

  final String expected;
  final TokenStatus status;

  /// What appeared instead, when [status] is [TokenStatus.incorrect].
  final String? heard;
}

class SpeechComparison {
  const SpeechComparison({
    required this.tokens,
    required this.missing,
    required this.incorrect,
    required this.extra,
    required this.matchRatio,
  });

  /// Every target token in order, each with its outcome.
  final List<ComparedToken> tokens;

  /// Target tokens with nothing in their place.
  final List<String> missing;

  /// Target tokens replaced by something else, as (expected, heard).
  final List<({String expected, String heard})> incorrect;

  /// Tokens in the transcript that the target does not contain.
  final List<String> extra;

  /// Share of target tokens matched, 0–1. Empty target gives 0.
  final double matchRatio;

  bool get isExact =>
      missing.isEmpty && incorrect.isEmpty && extra.isEmpty;

  int get matchedCount =>
      tokens.where((t) => t.status == TokenStatus.matched).length;

  /// Compare [recognized] against [target].
  ///
  /// Segmentation follows the text rather than a language table: text written
  /// with spaces is compared word by word, text written without them is
  /// compared character by character. That keeps Korean word-level and
  /// Japanese character-level without branching on a language code.
  static SpeechComparison compare(String target, String recognized) {
    final expected = tokenize(target);
    final heard = tokenize(recognized);

    if (expected.isEmpty) {
      return SpeechComparison(
        tokens: const [],
        missing: const [],
        incorrect: const [],
        extra: heard,
        matchRatio: 0,
      );
    }

    final ops = _diff(expected, heard);

    final tokens = <ComparedToken>[];
    final missing = <String>[];
    final incorrect = <({String expected, String heard})>[];
    final extra = <String>[];
    var matched = 0;

    // Walk the edit script, pairing each run of deletions with the insertions
    // that sit beside it: those pairs are substitutions ("incorrect words"),
    // and whatever is left over is genuinely missing or genuinely extra.
    var i = 0;
    while (i < ops.length) {
      final op = ops[i];
      if (op.kind == _OpKind.keep) {
        tokens.add(
            ComparedToken(expected: op.value, status: TokenStatus.matched));
        matched++;
        i++;
        continue;
      }

      final deleted = <String>[];
      final inserted = <String>[];
      while (i < ops.length && ops[i].kind != _OpKind.keep) {
        if (ops[i].kind == _OpKind.delete) {
          deleted.add(ops[i].value);
        } else {
          inserted.add(ops[i].value);
        }
        i++;
      }

      final pairs = deleted.length < inserted.length
          ? deleted.length
          : inserted.length;
      for (var p = 0; p < pairs; p++) {
        tokens.add(ComparedToken(
          expected: deleted[p],
          status: TokenStatus.incorrect,
          heard: inserted[p],
        ));
        incorrect.add((expected: deleted[p], heard: inserted[p]));
      }
      for (var d = pairs; d < deleted.length; d++) {
        tokens
            .add(ComparedToken(expected: deleted[d], status: TokenStatus.missing));
        missing.add(deleted[d]);
      }
      extra.addAll(inserted.skip(pairs));
    }

    return SpeechComparison(
      tokens: tokens,
      missing: missing,
      incorrect: incorrect,
      extra: extra,
      matchRatio: matched / expected.length,
    );
  }

  /// Split [text] into comparable tokens, dropping punctuation and case.
  static List<String> tokenize(String text) {
    final normalized = normalize(text);
    if (normalized.isEmpty) return const [];
    if (normalized.contains(' ')) {
      return normalized.split(' ').where((t) => t.isNotEmpty).toList();
    }
    return normalized.split('');
  }

  /// Strip the things that should never decide right from wrong: punctuation,
  /// case, and repeated or surrounding whitespace (US-071 — "minor formatting
  /// differences do not unnecessarily cause failure").
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(_punctuation, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// True when two strings differ only in punctuation, case or spacing.
  static bool equivalent(String a, String b) {
    final na = normalize(a);
    final nb = normalize(b);
    if (na == nb) return true;
    // Spacing is not meaningful in Japanese and is inconsistently taught in
    // Korean, so a difference of spaces alone is not a mistake.
    return na.replaceAll(' ', '') == nb.replaceAll(' ', '');
  }

  // Latin, CJK and Korean punctuation, plus the interpuncts and quote forms
  // that speech recognisers insert on their own.
  //
  // Deliberately absent: the chōonpu ー (U+30FC). It looks like a dash but is
  // a letter — stripping it would turn コーヒー into コヒ and mark a correct
  // answer wrong. The dashes listed here are the punctuation ones.
  static final _punctuation = RegExp(
      r'''[.,!?;:'"()\[\]{}…·・、。！？；：，．「」『』（）〔〕《》〈〉―‐–—~〜]''');
}

enum _OpKind { keep, delete, insert }

class _Op {
  const _Op(this.kind, this.value);
  final _OpKind kind;
  final String value;
}

/// Longest-common-subsequence diff. Quadratic, which is fine: a spoken
/// sentence is a handful of tokens, and the alternative would be approximate.
List<_Op> _diff(List<String> a, List<String> b) {
  final n = a.length;
  final m = b.length;
  final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j]
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }

  final ops = <_Op>[];
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      ops.add(_Op(_OpKind.keep, a[i]));
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      ops.add(_Op(_OpKind.delete, a[i]));
      i++;
    } else {
      ops.add(_Op(_OpKind.insert, b[j]));
      j++;
    }
  }
  while (i < n) {
    ops.add(_Op(_OpKind.delete, a[i++]));
  }
  while (j < m) {
    ops.add(_Op(_OpKind.insert, b[j++]));
  }
  return ops;
}
