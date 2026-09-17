import '../../models/insights.dart';
import '../../models/language.dart';

/// What the app should suggest next (US-101).
enum RecommendedActivity {
  /// Clear reviews the scheduler says are due now.
  review,

  /// Learn the writing system before anything else.
  writing,

  /// Targeted practice on a specific weakness.
  targetedPractice,

  /// A mixed daily session.
  session,

  /// Add new words to the deck.
  newVocabulary,

  /// Train the ear.
  listening,

  /// Say it out loud.
  speaking,

  /// Read grammar explanations.
  grammar,
}

class Recommendation {
  const Recommendation({
    required this.activity,
    required this.title,
    required this.reason,
    this.focus,
    this.estimatedMinutes,
  });

  final RecommendedActivity activity;

  /// What to do, phrased as the action.
  final String title;

  /// Why this and not something else — shown to the learner, because a
  /// recommendation with no stated reason is indistinguishable from a guess.
  final String reason;

  /// The specific thing to practise, when the recommendation is targeted.
  final WeakArea? focus;

  /// Roughly how long it takes, fitted to the time the learner has left today.
  final int? estimatedMinutes;
}

/// Everything the engine is allowed to look at. Assembled by the caller from
/// recorded data; the engine itself reads nothing.
class LearnerSnapshot {
  const LearnerSnapshot({
    required this.language,
    required this.level,
    this.goals = const [],
    this.dueReviews = 0,
    this.untrackedVocabulary = 0,
    this.charactersTracked = 0,
    this.charactersAvailable = 0,
    this.minutesStudiedToday = 0,
    this.dailyGoalMinutes = 10,
    this.weakAreas = const [],
    this.skillsPractisedThisWeek = const {},
  });

  final TargetLanguage language;
  final ProficiencyLevel level;

  /// Goals chosen during onboarding or in settings (US-006, US-150).
  final List<String> goals;

  /// Items whose next review is now or earlier.
  final int dueReviews;

  /// Catalog words the learner has never seen.
  final int untrackedVocabulary;

  final int charactersTracked;
  final int charactersAvailable;

  final int minutesStudiedToday;
  final int dailyGoalMinutes;

  /// Sorted worst-first by the caller is not required; the engine sorts.
  final List<WeakArea> weakAreas;

  /// Skill names touched in the last seven days, e.g. `{'listening'}`.
  final Set<String> skillsPractisedThisWeek;

  /// Minutes left against today's goal. Zero once the goal is met.
  int get minutesRemainingToday =>
      (dailyGoalMinutes - minutesStudiedToday).clamp(0, dailyGoalMinutes);

  bool get goalMetToday => minutesStudiedToday >= dailyGoalMinutes;

  /// A learner who has not started the script yet, at a level where the script
  /// is the prerequisite for everything else.
  bool get needsWritingSystem =>
      charactersAvailable > 0 &&
      charactersTracked == 0 &&
      (level == ProficiencyLevel.completeBeginner ||
          level == ProficiencyLevel.beginner);
}

/// Picks one next activity (US-101).
///
/// Pure and deterministic — same snapshot in, same recommendation out, no I/O
/// and no clock — so the priority order is covered by
/// `test/recommendation_engine_test.dart` rather than discovered in the UI.
class RecommendationEngine {
  const RecommendationEngine();

  /// Skills a goal implies, so "Conversation" pulls speaking forward and
  /// "Reading" does not. Data, not a per-language branch.
  static const _goalSkills = <String, List<String>>{
    'Conversation': ['speaking', 'listening'],
    'Travel': ['speaking', 'listening'],
    'Reading': ['grammar'],
    'Work': ['speaking', 'grammar'],
    'Study': ['grammar'],
    'TOPIK': ['listening', 'grammar'],
    'JLPT': ['listening', 'grammar'],
    'Media comprehension': ['listening'],
    'General fluency': ['speaking', 'listening', 'grammar'],
  };

  Recommendation recommend(LearnerSnapshot s) {
    // 1. Due reviews win. They are scheduled for now, and letting them slip is
    //    the one thing that measurably costs retention.
    if (s.dueReviews > 0) {
      return Recommendation(
        activity: RecommendedActivity.review,
        title: '${s.dueReviews} ${s.dueReviews == 1 ? 'review' : 'reviews'} due',
        reason: 'These are scheduled for right now. Clearing them first is '
            'what keeps them from being forgotten.',
        estimatedMinutes: _reviewMinutes(s.dueReviews),
      );
    }

    // 2. A beginner who cannot read the script yet gets no value from
    //    vocabulary drills built on it.
    if (s.needsWritingSystem) {
      return Recommendation(
        activity: RecommendedActivity.writing,
        title: 'Learn the writing system',
        reason: 'Reading the script first makes every other exercise easier.',
        estimatedMinutes: 10,
      );
    }

    // 3. Something the learner is measurably getting wrong.
    final weakest = _weakest(s.weakAreas);
    if (weakest != null) {
      return Recommendation(
        activity: RecommendedActivity.targetedPractice,
        title: 'Practise ${weakest.label}',
        reason: 'You have got ${weakest.incorrect} of ${weakest.attempts} '
            'recent answers wrong here.',
        focus: weakest,
        estimatedMinutes: 5,
      );
    }

    // 4. A skill the learner's own goals call for but has not touched.
    final neglected = _neglectedSkill(s);
    if (neglected != null) return neglected;

    // 5. The daily goal is still open — a mixed session is the efficient way
    //    to close it. With only a couple of minutes left, suggest flashcards
    //    instead of a session that will not fit.
    if (!s.goalMetToday) {
      if (s.minutesRemainingToday <= 3 && s.untrackedVocabulary > 0) {
        return Recommendation(
          activity: RecommendedActivity.newVocabulary,
          title: 'Learn a few new words',
          reason: 'About ${s.minutesRemainingToday} '
              '${s.minutesRemainingToday == 1 ? 'minute' : 'minutes'} left on '
              "today's goal — flashcards fit.",
          estimatedMinutes: s.minutesRemainingToday,
        );
      }
      return Recommendation(
        activity: RecommendedActivity.session,
        title: "Start today's session",
        reason: 'A mixed session covers vocabulary, grammar and listening in '
            'one go.',
        estimatedMinutes: s.minutesRemainingToday,
      );
    }

    // 6. Goal met, nothing wrong, nothing due — grow the deck.
    if (s.untrackedVocabulary > 0) {
      return Recommendation(
        activity: RecommendedActivity.newVocabulary,
        title: 'Learn new words',
        reason: "Today's goal is met and nothing is due — this is the moment "
            'to add to the deck.',
        estimatedMinutes: 5,
      );
    }

    // 7. Everything in the catalog is already tracked.
    return const Recommendation(
      activity: RecommendedActivity.grammar,
      title: 'Review a grammar pattern',
      reason: "You have started every word we have. Reading a pattern again "
          'is the best use of the time.',
      estimatedMinutes: 5,
    );
  }

  WeakArea? _weakest(List<WeakArea> areas) {
    WeakArea? worst;
    for (final area in areas) {
      if (!area.isWeak) continue;
      if (worst == null || area.accuracy < worst.accuracy) {
        worst = area;
      } else if (area.accuracy == worst.accuracy &&
          area.attempts > worst.attempts) {
        // Ties break on sample size: more evidence is safer to act on.
        worst = area;
      }
    }
    return worst;
  }

  Recommendation? _neglectedSkill(LearnerSnapshot s) {
    final wanted = <String>[];
    for (final goal in s.goals) {
      for (final skill in _goalSkills[goal] ?? const <String>[]) {
        if (!wanted.contains(skill)) wanted.add(skill);
      }
    }
    for (final skill in wanted) {
      if (s.skillsPractisedThisWeek.contains(skill)) continue;
      switch (skill) {
        case 'speaking':
          return const Recommendation(
            activity: RecommendedActivity.speaking,
            title: 'Say a sentence out loud',
            reason: 'Your goals are about speaking, and you have not practised '
                'it this week.',
            estimatedMinutes: 5,
          );
        case 'listening':
          return const Recommendation(
            activity: RecommendedActivity.listening,
            title: 'Practise listening',
            reason: 'Your goals need your ear, and you have not trained it '
                'this week.',
            estimatedMinutes: 5,
          );
        case 'grammar':
          return const Recommendation(
            activity: RecommendedActivity.grammar,
            title: 'Read a grammar pattern',
            reason: 'Your goals lean on grammar, and you have not looked at it '
                'this week.',
            estimatedMinutes: 5,
          );
      }
    }
    return null;
  }

  /// Roughly ten seconds an item, floored at one minute so the estimate never
  /// reads as zero.
  int _reviewMinutes(int due) => (due / 6).ceil().clamp(1, 60);
}
