import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/study_card.dart';

/// Listen → choose the meaning (US-070). Audio comes from on-device TTS
/// until recorded native audio is added to the content library.
class ListeningScreen extends ConsumerStatefulWidget {
  const ListeningScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  ConsumerState<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends ConsumerState<ListeningScreen> {
  List<VocabItem>? _pool;
  List<VocabItem>? _questions;
  List<List<String>>? _choices;
  int _index = 0;
  String? _selected;
  bool? _wasCorrect;
  int _correct = 0;
  int _incorrect = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pool = await ref
        .read(contentServiceProvider)
        .vocabulary(widget.language.code, limit: 50);
    if (pool.length < 4) {
      if (mounted) setState(() => _pool = pool);
      return;
    }
    final rng = Random();
    final questions = ([...pool]..shuffle(rng)).take(10).toList();
    final choices = [
      for (final q in questions)
        ([
          q.translation,
          ...(pool.where((v) => v.id != q.id).toList()..shuffle(rng))
              .take(3)
              .map((v) => v.translation)
        ]..shuffle(rng))
    ];
    if (mounted) {
      setState(() {
        _pool = pool;
        _questions = questions;
        _choices = choices;
      });
      _play();
    }
  }

  void _play() {
    final q = _questions?[_index];
    if (q != null) {
      ref.read(ttsServiceProvider).speak(q.word, widget.language);
    }
  }

  Future<void> _answer(String choice) async {
    if (_wasCorrect != null) return;
    final q = _questions![_index];
    final correct = choice == q.translation;
    setState(() {
      _selected = choice;
      _wasCorrect = correct;
      correct ? _correct++ : _incorrect++;
    });
    try {
      await ref.read(reviewServiceProvider).recordExercise(
            itemType: 'vocabulary',
            itemId: q.id,
            language: widget.language.code,
            exerciseType: 'listening_choice',
            correct: correct,
            answer: choice,
          );
    } catch (_) {
      // Non-fatal; keep the exercise flowing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listening'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: LangoSpace.md),
            child: Center(
              child: Text(widget.language.flag,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
            child: _body(questions),
          ),
        ),
      ),
    );
  }

  Widget _body(List<VocabItem>? questions) {
    if (_pool == null) {
      return const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoSkeletonList(count: 2),
      );
    }

    if (questions == null) {
      return const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoEmpty(
          icon: Icons.headphones_outlined,
          title: 'Not enough words yet',
          message: 'Listening practice needs at least four words in this '
              'language. Study some vocabulary first.',
        ),
      );
    }

    if (_index >= questions.length) {
      return Padding(
        padding: const EdgeInsets.all(LangoSpace.gutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Listening complete 🎉',
                style: LangoType.h1, textAlign: TextAlign.center),
            const Gap.md(),
            Text('Correct $_correct  ·  Missed $_incorrect',
                style: LangoType.bodyMuted, textAlign: TextAlign.center),
            const Gap.xl(),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }

    final q = questions[_index];
    final choices = _choices![_index];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LangoSpace.gutter,
        LangoSpace.md,
        LangoSpace.gutter,
        LangoSpace.lg,
      ),
      child: Column(
        children: [
          StudyProgress(index: _index, total: questions.length),
          const Gap.xxl(),

          // Minimal visual distraction: one big audio control, one question.
          AudioButton(
            text: q.word,
            language: widget.language,
            size: AudioButtonSize.hero,
          ),
          const Gap.md(),
          Text('What did you hear?', style: LangoType.h3),
          const Gap.xl(),

          Expanded(
            child: ListView.separated(
              itemCount: choices.length,
              separatorBuilder: (_, _) => const Gap.sm(),
              itemBuilder: (context, i) => _ChoiceButton(
                label: choices[i],
                state: _stateFor(choices[i], q.translation),
                onTap: () => _answer(choices[i]),
              ),
            ),
          ),

          if (_wasCorrect != null)
            FilledButton(
              onPressed: () => setState(() {
                _index++;
                _selected = null;
                _wasCorrect = null;
                if (_index < questions.length) _play();
              }),
              child: const Text('Continue'),
            ),
        ],
      ),
    );
  }

  _ChoiceState _stateFor(String choice, String answer) {
    if (_wasCorrect == null) return _ChoiceState.idle;
    if (choice == answer) return _ChoiceState.correct;
    if (choice == _selected) return _ChoiceState.wrong;
    return _ChoiceState.dimmed;
  }
}

enum _ChoiceState { idle, correct, wrong, dimmed }

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _ChoiceState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      _ChoiceState.idle => (LangoColors.surfaceMuted, LangoColors.foreground),
      _ChoiceState.correct => (LangoPalette.tintCyan, LangoColors.success),
      _ChoiceState.wrong => (LangoPalette.tintPink, LangoColors.error),
      _ChoiceState.dimmed => (
          LangoColors.surfaceMuted,
          LangoColors.foregroundMuted
        ),
    };

    return Semantics(
      button: true,
      selected: state == _ChoiceState.correct || state == _ChoiceState.wrong,
      child: Material(
        color: Colors.transparent,
        borderRadius: LangoRadius.mdAll,
        child: InkWell(
          onTap: state == _ChoiceState.idle ? onTap : null,
          borderRadius: LangoRadius.mdAll,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: LangoSpace.lg,
              vertical: LangoSpace.md,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: LangoRadius.mdAll,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: LangoType.label.copyWith(color: fg)),
                ),
                if (state == _ChoiceState.correct)
                  const Icon(Icons.check_rounded,
                      color: LangoColors.success, size: 20),
                if (state == _ChoiceState.wrong)
                  const Icon(Icons.close_rounded,
                      color: LangoColors.error, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
