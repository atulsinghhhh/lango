import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/native_text.dart';

/// Grammar detail (REDESIGN.md §15).
///
/// Strong typographic hierarchy: the pattern is the hero, the meaning is a
/// tracked caption, the explanation is plain readable body, and examples are
/// native-first pairs — no stack of near-identical cards.
class GrammarDetailScreen extends ConsumerWidget {
  const GrammarDetailScreen({super.key, required this.point});

  final GrammarPoint point;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = TargetLanguage.fromCode(point.language);

    return Scaffold(
      appBar: AppBar(title: const Text('Grammar')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                LangoSpace.gutter,
                LangoSpace.md,
                LangoSpace.gutter,
                LangoSpace.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point.name,
                    style: LangoType.native(language.code, size: 40),
                  ),
                  const Gap.xs(),
                  Text(point.meaning.toUpperCase(), style: LangoType.caption),
                  const Gap.xl(),
                  Text(point.explanation, style: LangoType.body),
                  if (point.examples.isNotEmpty) ...[
                    const Gap.xxl(),
                    Text('EXAMPLES', style: LangoType.caption),
                    const Gap.md(),
                    for (var i = 0; i < point.examples.length; i++) ...[
                      _ExampleRow(
                        example: point.examples[i],
                        language: language,
                      ),
                      if (i != point.examples.length - 1)
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: LangoSpace.md),
                          child: Divider(height: 1),
                        ),
                    ],
                  ],
                  const Gap.xxl(),
                  FilledButton.icon(
                    icon: const Icon(Icons.quiz_rounded),
                    label: const Text('Practise this grammar'),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => GrammarQuizScreen(point: point))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExampleRow extends StatelessWidget {
  const _ExampleRow({required this.example, required this.language});

  final GrammarExample example;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: NativeSentence(
            sentence: example.native,
            languageCode: language.code,
            translation: example.translation,
          ),
        ),
        const SizedBox(width: LangoSpace.sm),
        AudioButton(
          text: example.native,
          language: language,
          size: AudioButtonSize.small,
        ),
      ],
    );
  }
}

/// Simple grammar practice (US-041): multiple choice on meaning and
/// fill-in-the-blank over the point's examples. Results feed the SRS.
class GrammarQuizScreen extends ConsumerStatefulWidget {
  const GrammarQuizScreen({super.key, required this.point});

  final GrammarPoint point;

  @override
  ConsumerState<GrammarQuizScreen> createState() => _GrammarQuizScreenState();
}

class _Question {
  const _Question(
      {required this.prompt,
      required this.answer,
      required this.choices,
      required this.exerciseType,
      this.hint});

  final String prompt;
  final String answer;
  final List<String> choices;
  final String exerciseType;
  final String? hint;
}

class _GrammarQuizScreenState extends ConsumerState<GrammarQuizScreen> {
  List<_Question>? _questions;
  int _index = 0;
  String? _selected;
  bool? _wasCorrect;
  int _correct = 0;
  int _incorrect = 0;

  @override
  void initState() {
    super.initState();
    _buildQuestions();
  }

  Future<void> _buildQuestions() async {
    final all = await ref
        .read(contentServiceProvider)
        .grammarPoints(widget.point.language);
    final rng = Random();
    final others = all.where((g) => g.id != widget.point.id).toList()
      ..shuffle(rng);
    final questions = <_Question>[];

    // 1) Meaning multiple choice.
    final meaningChoices = [
      widget.point.meaning,
      ...others.take(3).map((g) => g.meaning)
    ]..shuffle(rng);
    questions.add(_Question(
      prompt: 'What does "${widget.point.name}" express?',
      answer: widget.point.meaning,
      choices: meaningChoices,
      exerciseType: 'multiple_choice',
    ));

    // 2) Fill in the blank from examples: blank out the grammar pattern's
    //    surface form where it appears.
    for (final ex in widget.point.examples.take(3)) {
      final surface = _surfaceForm(widget.point.name, ex.native);
      if (surface == null) continue;
      final distractors = others
          .map((g) => _surfaceForm(g.name, g.examples.isNotEmpty
              ? g.examples.first.native
              : ''))
          .whereType<String>()
          .where((s) => s != surface)
          .take(3)
          .toList();
      if (distractors.length < 2) continue;
      questions.add(_Question(
        prompt: ex.native.replaceFirst(surface, '___'),
        answer: surface,
        choices: [surface, ...distractors]..shuffle(rng),
        exerciseType: 'fill_in_blank',
        hint: ex.translation,
      ));
    }
    if (mounted) setState(() => _questions = questions);
  }

  /// Best-effort match of a grammar pattern inside an example sentence.
  String? _surfaceForm(String patternName, String sentence) {
    final variants = patternName
        .replaceAll(RegExp(r'[〜\-～]'), '')
        .split(RegExp(r'[/()]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final v in variants) {
      if (sentence.contains(v)) return v;
    }
    return null;
  }

  Future<void> _answer(_Question q, String choice) async {
    if (_wasCorrect != null) return;
    final correct = choice == q.answer;
    setState(() {
      _selected = choice;
      _wasCorrect = correct;
      correct ? _correct++ : _incorrect++;
    });
    try {
      await ref.read(reviewServiceProvider).recordExercise(
            itemType: 'grammar',
            itemId: widget.point.id,
            language: widget.point.language,
            exerciseType: q.exerciseType,
            correct: correct,
            answer: choice,
          );
    } catch (_) {
      // Non-fatal: surface quietly, the quiz can continue.
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions;
    return Scaffold(
      appBar: AppBar(title: Text(widget.point.name)),
      body: questions == null
          ? const Center(child: CircularProgressIndicator())
          : _index >= questions.length
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Grammar practice done!',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 12),
                      Text('Correct: $_correct   ·   Incorrect: $_incorrect'),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Done')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(
                            value: (_index + 1) / questions.length),
                        const SizedBox(height: 24),
                        Text(questions[_index].prompt,
                            style: Theme.of(context).textTheme.headlineSmall),
                        if (questions[_index].hint != null) ...[
                          const SizedBox(height: 4),
                          Text(questions[_index].hint!,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                        const SizedBox(height: 24),
                        for (final choice in questions[_index].choices)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: OutlinedButton(
                              onPressed: _wasCorrect == null
                                  ? () => _answer(questions[_index], choice)
                                  : null,
                              style: OutlinedButton.styleFrom(
                                // Semantic status tints, not raw Material
                                // colours — keeps the pastel system intact.
                                backgroundColor: _wasCorrect == null
                                    ? null
                                    : choice == questions[_index].answer
                                        ? LangoPalette.tintCyan
                                        : choice == _selected
                                            ? LangoPalette.tintPink
                                            : null,
                                foregroundColor: _wasCorrect == null
                                    ? null
                                    : choice == questions[_index].answer
                                        ? LangoColors.success
                                        : choice == _selected
                                            ? LangoColors.error
                                            : LangoColors.foregroundMuted,
                              ),
                              child: Text(choice, style: LangoType.label),
                            ),
                          ),
                        if (_wasCorrect != null)
                          FilledButton(
                            onPressed: () => setState(() {
                              _index++;
                              _selected = null;
                              _wasCorrect = null;
                            }),
                            child: const Text('Next'),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
