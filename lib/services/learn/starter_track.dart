/// The guided path for someone who has never seen the language.
///
/// A complete beginner opening the Learn hub sees eight equally-weighted
/// cards and no indication that vocabulary drills are useless before you can
/// read the script. This orders the same features into one sequence and says
/// what each step is for, so "where do I start?" has an answer on screen.
///
/// Pure and deterministic, like the other engines: no I/O, no clock, no
/// platform calls. The caller measures the learner and passes a
/// [StarterSnapshot] in; the same snapshot always produces the same track, so
/// the ordering and unlock rules are covered by
/// `test/starter_track_test.dart` rather than discovered in the UI.
library;

import '../../models/content.dart';
import '../../models/language.dart';

/// What a step asks the learner to do. The kind drives the icon and the route;
/// the copy lives on the step.
enum StarterStepKind {
  /// Learn one writing system — Hangul, Hiragana, Katakana.
  script,

  /// First words as flashcards.
  vocabulary,

  /// Hear a word and pick it out.
  listening,

  /// Hear a word and type it.
  dictation,

  /// First sentence patterns.
  grammar,

  /// Say a sentence out loud.
  speaking,

  /// Hold a short conversation.
  tutor,
}

/// Where the learner is in the sequence.
enum StarterStepState {
  /// Finished, by a measured threshold rather than a self-report.
  done,

  /// The one thing to do next. Exactly one step is current in an incomplete
  /// track, and none in a complete one.
  current,

  /// Comes later. Locked here means "not yet recommended", not "forbidden" —
  /// every feature stays reachable from the Learn hub, because taking
  /// functionality away from someone who wants it is worse than showing them
  /// something they are not ready for.
  locked,
}

/// One writing system as the learner currently stands with it.
class ScriptProgress {
  const ScriptProgress({
    required this.script,
    required this.learned,
    required this.total,
    this.isLevelled = false,
  });

  /// The `characters.script` value, e.g. `hangul`, `hiragana`, `kanji`.
  final String script;

  /// Characters of this script the learner has a tracked item for.
  final int learned;

  /// Characters of this script in the catalog.
  final int total;

  /// Whether the set is split into curriculum bands (`level_label`), as the
  /// kanji set is into JLPT levels.
  ///
  /// This is how the track tells a foundational alphabet from an open-ended
  /// one without naming a language: a syllabary is learned to completion and
  /// carries no bands, whereas a levelled set is studied for years and is not
  /// a prerequisite for saying hello. Data, not a per-language branch —
  /// a third language's script sorts itself.
  final bool isLevelled;

  bool get isFoundational => !isLevelled && total > 0;

  double get fraction => total == 0 ? 0 : (learned / total).clamp(0.0, 1.0);
}

/// Everything the track is allowed to look at, measured by the caller.
class StarterSnapshot {
  const StarterSnapshot({
    required this.language,
    required this.level,
    this.scripts = const [],
    this.vocabularyTracked = 0,
    this.grammarTracked = 0,
    this.hasListened = false,
    this.hasTakenDictation = false,
    this.hasSpoken = false,
    this.hasMessagedTutor = false,
  });

  final TargetLanguage language;
  final ProficiencyLevel level;

  /// Every script the language has content for, in catalog order.
  final List<ScriptProgress> scripts;

  /// Catalog words and patterns the learner has started.
  final int vocabularyTracked;
  final int grammarTracked;

  /// Whether each skill has ever been practised. "Ever", not "this week": the
  /// track asks whether the learner has met a mode at all, and a step already
  /// completed should not reappear after a quiet fortnight.
  final bool hasListened;
  final bool hasTakenDictation;
  final bool hasSpoken;
  final bool hasMessagedTutor;

  /// Scripts that form the foundation, in the order they should be learned.
  List<ScriptProgress> get foundationScripts =>
      scripts.where((s) => s.isFoundational).toList();

  /// Whether this learner is the audience for a guided path at all.
  ///
  /// Someone who already reads the script is not helped by being sent back to
  /// the alphabet, and [StarterTrack] would mark most of the path done
  /// anyway — but an intermediate learner should never be offered it, even
  /// on a fresh install where nothing is tracked yet.
  bool get wantsGuidance =>
      level == ProficiencyLevel.completeBeginner ||
      level == ProficiencyLevel.beginner;
}

/// One step of the path.
class StarterStep {
  const StarterStep({
    required this.kind,
    required this.title,
    required this.purpose,
    required this.state,
    required this.route,
    this.script,
    this.progress,
    this.nextHint,
  });

  final StarterStepKind kind;

  /// What to do, phrased as the action.
  final String title;

  /// Why this step exists and why it sits here. Shown to the learner: a path
  /// that only says "do this next" is indistinguishable from a guess.
  final String purpose;

  final StarterStepState state;

  /// Where the step goes, without the language query parameter — the screen
  /// appends it, as every other Learn route does.
  final String route;

  /// The `characters.script` this step teaches, when [kind] is
  /// [StarterStepKind.script].
  final String? script;

  /// How far through this step the learner is, where that is measurable.
  /// Null when the step is a yes/no ("have you ever recorded yourself?").
  final double? progress;

  /// What finishes this step, shown on the current step so the bar has a
  /// stated meaning rather than being decoration.
  final String? nextHint;

  bool get isDone => state == StarterStepState.done;
  bool get isCurrent => state == StarterStepState.current;
  bool get isLocked => state == StarterStepState.locked;
}

/// The whole path.
class StarterTrackPlan {
  const StarterTrackPlan({required this.steps});

  final List<StarterStep> steps;

  bool get isEmpty => steps.isEmpty;

  /// Every step measured as done.
  bool get isComplete =>
      steps.isNotEmpty && steps.every((s) => s.isDone);

  /// The one step to do next, or null once the path is finished.
  StarterStep? get current {
    for (final step in steps) {
      if (step.isCurrent) return step;
    }
    return null;
  }

  int get doneCount => steps.where((s) => s.isDone).length;

  /// Share of the path completed, for the summary card on the Learn hub.
  double get fraction => steps.isEmpty ? 0 : doneCount / steps.length;
}

/// Builds the guided path (the "Start here" track).
class StarterTrack {
  const StarterTrack();

  /// How much of a writing system counts as knowing it well enough to move on.
  ///
  /// Not 1.0: waiting for every last character means a learner who has the
  /// other forty stalls on を, and the remaining few are better learned by
  /// meeting them in words. Not a half either — reading a word needs most of
  /// the letters in it.
  static const scriptReadyFraction = 0.8;

  /// Words before the first-words step is done. Enough to build a sentence
  /// with, small enough to reach in a couple of sittings.
  static const firstWordsTarget = 10;

  /// Patterns before the grammar step is done. One pattern, properly met, is
  /// the honest bar for "you have started grammar".
  static const firstGrammarTarget = 1;

  /// The ordered path for [snapshot].
  ///
  /// Returns an empty plan when the language has no foundational script in the
  /// catalog — there is nothing to guide someone through yet, and an empty
  /// path is more honest than an invented one.
  StarterTrackPlan plan(StarterSnapshot snapshot) {
    final foundation = snapshot.foundationScripts;
    if (foundation.isEmpty) return const StarterTrackPlan(steps: []);

    final drafts = <_Draft>[
      for (final script in foundation)
        _Draft(
          kind: StarterStepKind.script,
          title: 'Learn ${scriptLabel(script.script)}',
          purpose: _scriptPurpose(script.script),
          route: '/learn/writing',
          script: script.script,
          progress: script.fraction,
          done: script.fraction >= scriptReadyFraction,
          nextHint: _scriptHint(script),
        ),
      _Draft(
        kind: StarterStepKind.vocabulary,
        title: 'Learn your first words',
        purpose: 'Now that the letters make sounds, words make sense. '
            'Flashcards schedule themselves so you see each word again just '
            'before you would forget it.',
        route: '/learn/vocabulary',
        progress:
            (snapshot.vocabularyTracked / firstWordsTarget).clamp(0.0, 1.0),
        done: snapshot.vocabularyTracked >= firstWordsTarget,
        nextHint: _countHint(
          snapshot.vocabularyTracked,
          firstWordsTarget,
          'word',
        ),
      ),
      _Draft(
        kind: StarterStepKind.listening,
        title: 'Hear the words spoken',
        purpose: 'Reading a word and recognising it out loud are different '
            'skills. This one plays a word and asks which it was.',
        route: '/learn/listening',
        done: snapshot.hasListened,
        nextHint: 'Finish one listening round.',
      ),
      _Draft(
        kind: StarterStepKind.dictation,
        title: 'Type what you hear',
        purpose: 'Harder than picking from four options, because nothing is '
            'on screen to recognise — it is the first real test of the script.',
        route: '/learn/dictation',
        done: snapshot.hasTakenDictation,
        nextHint: 'Complete one dictation.',
      ),
      _Draft(
        kind: StarterStepKind.grammar,
        title: 'Put words in order',
        purpose: 'Words alone are not sentences. Each pattern is explained '
            'with real examples you can already read.',
        route: '/learn/grammar',
        progress:
            (snapshot.grammarTracked / firstGrammarTarget).clamp(0.0, 1.0),
        done: snapshot.grammarTracked >= firstGrammarTarget,
        nextHint: 'Start one grammar pattern.',
      ),
      _Draft(
        kind: StarterStepKind.speaking,
        title: 'Say a sentence out loud',
        purpose: 'Your device transcribes what it heard and shows you which '
            'words came through. It reads back your words — it does not score '
            'your pronunciation.',
        route: '/speaking',
        done: snapshot.hasSpoken,
        nextHint: 'Record one sentence.',
      ),
      _Draft(
        kind: StarterStepKind.tutor,
        title: 'Have a short conversation',
        purpose: 'Everything above, used for the thing you learned it for. '
            'The tutor replies in the language and corrects you when a '
            'correction is actually warranted.',
        route: '/tutor',
        done: snapshot.hasMessagedTutor,
        nextHint: 'Send one message.',
      ),
    ];

    // Strictly sequential: the first unfinished step is the current one and
    // everything after it is locked. A step already finished out of order
    // stays done — the learner did the work, and un-ticking it to enforce the
    // sequence would be a lie about what they have practised.
    var currentAssigned = false;
    final steps = <StarterStep>[];
    for (final draft in drafts) {
      final StarterStepState state;
      if (draft.done) {
        state = StarterStepState.done;
      } else if (!currentAssigned) {
        state = StarterStepState.current;
        currentAssigned = true;
      } else {
        state = StarterStepState.locked;
      }
      steps.add(draft.toStep(state));
    }

    return StarterTrackPlan(steps: steps);
  }

  /// Why this script, and why here.
  ///
  /// Keyed on the stored script code, because the honest thing to say about
  /// an alphabet of ten vowels is not the thing to say about a syllabary of
  /// forty-six. Anything unknown gets the generic line rather than silence.
  static const _scriptPurposes = <String, String>{
    'hangul_consonant':
        'Fourteen consonants, and the whole reason Korean is quick to start: '
            'Hangul was designed to be learned, not inherited, and the shapes '
            'echo how your mouth makes the sound.',
    'hangul_vowel':
        'Ten vowels. Put them next to the consonants you just learned and '
            'Korean syllables come apart into pieces you can read.',
    'hiragana':
        'Forty-six characters covering every sound in the language. This is '
            'the one that makes Japanese stop being shapes.',
    'katakana':
        'The second syllabary — the same sounds in different shapes, used for '
            'words borrowed from other languages. Plenty of them are English.',
  };

  static String _scriptPurpose(String script) =>
      _scriptPurposes[script] ??
      '${scriptLabel(script)} is a set of sounds, not a set of pictures: '
          'learn the characters and you can read anything written in them.';

  static String? _scriptHint(ScriptProgress script) {
    final target = (script.total * scriptReadyFraction).ceil();
    final remaining = target - script.learned;
    if (remaining <= 0) return null;
    return 'Start $remaining more '
        '${remaining == 1 ? 'character' : 'characters'} '
        '(${script.learned} of $target).';
  }

  static String? _countHint(int have, int target, String noun) {
    final remaining = target - have;
    if (remaining <= 0) return null;
    return 'Start $remaining more ${remaining == 1 ? noun : '${noun}s'} '
        '($have of $target).';
  }
}

/// A step before its state is known. Kept private so the sequencing rule has
/// exactly one place to live.
class _Draft {
  _Draft({
    required this.kind,
    required this.title,
    required this.purpose,
    required this.route,
    required this.done,
    this.script,
    this.progress,
    this.nextHint,
  });

  final StarterStepKind kind;
  final String title;
  final String purpose;
  final String route;
  final bool done;
  final String? script;
  final double? progress;
  final String? nextHint;

  StarterStep toStep(StarterStepState state) => StarterStep(
        kind: kind,
        title: title,
        purpose: purpose,
        state: state,
        route: route,
        script: script,
        progress: progress,
        nextHint: state == StarterStepState.current ? nextHint : null,
      );
}
