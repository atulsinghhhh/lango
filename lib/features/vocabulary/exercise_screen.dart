import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/exercises/exercise_generator.dart';
import '../../services/providers.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/native_text.dart';
import '../../widgets/study_card.dart';

final exercisePoolProvider = FutureProvider.autoDispose
    .family<List<VocabItem>, String>((ref, language) async {
  return ref.watch(contentServiceProvider).vocabulary(language, limit: 50);
});

class ExerciseScreen extends ConsumerStatefulWidget {
  const ExerciseScreen(
      {super.key, required this.language, this.pool, this.onFinished});

  final TargetLanguage language;

  /// Optional pre-selected items (used by the daily session).
  final List<VocabItem>? pool;
  final void Function(int correct, int incorrect)? onFinished;

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  List<Exercise>? _exercises;
  int _index = 0;
  int _correct = 0;
  int _incorrect = 0;
  String? _selected;
  bool? _wasCorrect;
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _initExercises(List<VocabItem> pool) {
    _exercises ??= ExerciseGenerator().buildSet(pool, count: 10);
  }

  Future<void> _answer(Exercise ex, String answer) async {
    if (_wasCorrect != null) return;
    final correct = ex.type == ExerciseType.typeAnswer
        ? ExerciseGenerator.checkTypedAnswer(answer, ex.answer)
        : answer == ex.answer;
    setState(() {
      _selected = answer;
      _wasCorrect = correct;
      correct ? _correct++ : _incorrect++;
    });
    try {
      await ref.read(reviewServiceProvider).recordExercise(
            itemType: 'vocabulary',
            itemId: ex.item.id,
            language: widget.language.code,
            exerciseType: ex.type.code,
            correct: correct,
            answer: answer,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save this result — check your connection.')));
      }
    }
  }

  void _next() {
    setState(() {
      _index++;
      _selected = null;
      _wasCorrect = null;
      _typed.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pool != null) {
      if (widget.pool!.length >= 4) _initExercises(widget.pool!);
      return _body(context);
    }
    final poolAsync = ref.watch(exercisePoolProvider(widget.language.code));
    return poolAsync.when(
      loading: () => _shell(const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoSkeletonList(count: 2),
      )),
      error: (e, _) => _shell(Padding(
        padding: const EdgeInsets.all(LangoSpace.gutter),
        child: LangoError(
          message: "We couldn't load practice items. Check your connection.",
          onRetry: () =>
              ref.invalidate(exercisePoolProvider(widget.language.code)),
        ),
      )),
      data: (pool) {
        if (pool.length < 4) {
          return _shell(const Padding(
            padding: EdgeInsets.all(LangoSpace.gutter),
            child: LangoEmpty(
              icon: Icons.quiz_outlined,
              title: 'Not enough words yet',
              message: 'Exercises need at least four words in this language. '
                  'Study some vocabulary first.',
            ),
          ));
        }
        _initExercises(pool);
        return _body(context);
      },
    );
  }

  Widget _shell(Widget child) => Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
              child: child,
            ),
          ),
        ),
      );

  Widget _body(BuildContext context) {
    final exercises = _exercises;
    if (exercises == null) {
      return _shell(const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoSkeletonList(count: 2),
      ));
    }

    if (_index >= exercises.length) {
      widget.onFinished?.call(_correct, _incorrect);
      return _shell(Padding(
        padding: const EdgeInsets.all(LangoSpace.gutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Practice complete 🎉',
                style: LangoType.h1, textAlign: TextAlign.center),
            const Gap.md(),
            Text('Correct $_correct  ·  Incorrect $_incorrect',
                style: LangoType.bodyMuted, textAlign: TextAlign.center),
            const Gap.xl(),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ));
    }

    final ex = exercises[_index];

    return _shell(SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        LangoSpace.gutter,
        LangoSpace.md,
        LangoSpace.gutter,
        LangoSpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudyProgress(index: _index, total: exercises.length),
          const Gap.xl(),
          Text(_instruction(ex.type).toUpperCase(), style: LangoType.caption),
          const Gap.sm(),
          // The prompt is the task — native content gets the native face.
          Text(
            ex.prompt,
            style: ex.type == ExerciseType.translation
                ? LangoType.h2
                : LangoType.native(widget.language.code, size: 34),
          ),
          if (ex.hint != null && ex.type != ExerciseType.typeAnswer) ...[
            const Gap.xs(),
            Text(ex.hint!, style: LangoType.bodyMuted),
          ],
          const Gap.xl(),
          if (ex.type == ExerciseType.typeAnswer)
            _typedInput(ex)
          else
            ..._choiceButtons(ex),
          if (_wasCorrect != null) ...[
            const Gap.md(),
            _feedback(ex),
            const Gap.md(),
            FilledButton(onPressed: _next, child: const Text('Next')),
          ],
        ],
      ),
    ));
  }

  String _instruction(ExerciseType type) => switch (type) {
        ExerciseType.multipleChoice => 'What does this mean?',
        ExerciseType.translation => 'Pick the ${widget.language.label} word',
        ExerciseType.typeAnswer => 'Type the meaning in English',
        ExerciseType.sentenceCompletion => 'Complete the sentence',
      };

  Widget _typedInput(Exercise ex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _typed,
          enabled: _wasCorrect == null,
          decoration: const InputDecoration(hintText: 'Your answer'),
          onSubmitted: (v) => _answer(ex, v),
        ),
        const Gap.sm(),
        if (_wasCorrect == null)
          FilledButton(
            onPressed: () => _answer(ex, _typed.text),
            child: const Text('Check'),
          ),
      ],
    );
  }

  List<Widget> _choiceButtons(Exercise ex) {
    return [
      for (final choice in ex.choices)
        Padding(
          padding: const EdgeInsets.only(bottom: LangoSpace.sm),
          child: _ChoiceTile(
            label: choice,
            state: _choiceState(ex, choice),
            onTap: _wasCorrect == null ? () => _answer(ex, choice) : null,
          ),
        ),
    ];
  }

  _AnswerState _choiceState(Exercise ex, String choice) {
    if (_wasCorrect == null) return _AnswerState.idle;
    if (choice == ex.answer) return _AnswerState.correct;
    if (choice == _selected) return _AnswerState.wrong;
    return _AnswerState.dimmed;
  }

  Widget _feedback(Exercise ex) {
    final correct = _wasCorrect == true;
    return Container(
      padding: const EdgeInsets.all(LangoSpace.lg),
      decoration: BoxDecoration(
        borderRadius: LangoRadius.xlAll,
        color: correct ? LangoPalette.tintCyan : LangoPalette.tintPink,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct ? 'Correct 🎉' : 'Not quite',
            style: LangoType.label.copyWith(
              color: correct ? LangoColors.success : LangoColors.error,
            ),
          ),
          if (!correct) ...[
            const SizedBox(height: 4),
            Text('Answer: ${ex.answer}', style: LangoType.body),
          ],
          if (ex.item.exampleNative != null) ...[
            const Gap.sm(),
            NativeSentence(
              sentence: ex.item.exampleNative!,
              languageCode: widget.language.code,
              translation: ex.item.exampleTranslation,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }
}

enum _AnswerState { idle, correct, wrong, dimmed }

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _AnswerState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      _AnswerState.idle => (LangoColors.surfaceMuted, LangoColors.foreground),
      _AnswerState.correct => (LangoPalette.tintCyan, LangoColors.success),
      _AnswerState.wrong => (LangoPalette.tintPink, LangoColors.error),
      _AnswerState.dimmed => (
          LangoColors.surfaceMuted,
          LangoColors.foregroundMuted
        ),
    };

    return Material(
      color: Colors.transparent,
      borderRadius: LangoRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: LangoRadius.mdAll,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: LangoSpace.lg,
            vertical: LangoSpace.md,
          ),
          decoration:
              BoxDecoration(color: bg, borderRadius: LangoRadius.mdAll),
          child: Text(label, style: LangoType.label.copyWith(color: fg)),
        ),
      ),
    );
  }
}
