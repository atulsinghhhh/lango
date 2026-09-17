import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/exercises/dictation_checker.dart';
import '../../services/providers.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/comparison_text.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/study_card.dart';

/// Dictation (US-071).
///
/// Listen, type what you heard, see exactly which part differed. Grading lives
/// in [DictationChecker], so what counts as correct is decided in one tested
/// place rather than here.
class DictationScreen extends ConsumerStatefulWidget {
  const DictationScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  ConsumerState<DictationScreen> createState() => _DictationScreenState();
}

class _DictationScreenState extends ConsumerState<DictationScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  List<VocabItem>? _pool;
  List<_Prompt>? _prompts;
  int _index = 0;
  DictationResult? _result;
  bool _hintShown = false;
  int _correct = 0;
  int _incorrect = 0;

  static const _questionCount = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final pool = await ref
        .read(contentServiceProvider)
        .vocabulary(widget.language.code, limit: 50);
    if (!mounted) return;
    if (pool.isEmpty) {
      setState(() => _pool = pool);
      return;
    }

    // Prefer example sentences: dictating a whole sentence exercises the ear
    // far more than a single word, and the word alone is still there as a
    // fallback for entries that have no example.
    final rng = Random();
    final prompts = ([...pool]..shuffle(rng))
        .take(_questionCount)
        .map((item) => _Prompt(
              item: item,
              text: item.exampleNative ?? item.word,
              hint: item.exampleNative != null
                  ? item.exampleTranslation
                  : item.romanization,
            ))
        .toList();

    setState(() {
      _pool = pool;
      _prompts = prompts;
    });
    _play();
  }

  void _play() {
    final prompt = _prompts?[_index];
    if (prompt == null) return;
    ref.read(ttsServiceProvider).speak(prompt.text, widget.language);
  }

  Future<void> _check() async {
    if (_result != null) return;
    final prompt = _prompts![_index];
    final result = DictationChecker.check(_controller.text, prompt.text);

    setState(() {
      _result = result;
      result.correct ? _correct++ : _incorrect++;
    });

    try {
      await ref.read(reviewServiceProvider).recordExercise(
            itemType: 'vocabulary',
            itemId: prompt.item.id,
            language: widget.language.code,
            exerciseType: 'dictation',
            correct: result.correct,
            answer: _controller.text,
          );
    } catch (_) {
      // Recording is best effort; losing one attempt must not interrupt the
      // exercise the learner is in the middle of.
    }
  }

  void _next() {
    setState(() {
      _index++;
      _result = null;
      _hintShown = false;
      _controller.clear();
    });
    if (_index < (_prompts?.length ?? 0)) {
      _play();
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictation'),
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
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_pool == null) {
      return const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoSkeletonList(count: 2),
      );
    }

    final prompts = _prompts;
    if (prompts == null || prompts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoEmpty(
          icon: Icons.keyboard_outlined,
          title: 'No sentences to dictate yet',
          message: 'Dictation needs vocabulary in this language. Study a few '
              'words first.',
        ),
      );
    }

    if (_index >= prompts.length) {
      return Padding(
        padding: const EdgeInsets.all(LangoSpace.gutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Dictation complete 🎉',
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

    final prompt = prompts[_index];
    final result = _result;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        LangoSpace.gutter,
        LangoSpace.md,
        LangoSpace.gutter,
        LangoSpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudyProgress(index: _index, total: prompts.length),
          const Gap.xxl(),

          Center(
            child: AudioButton(
              text: prompt.text,
              language: widget.language,
              size: AudioButtonSize.hero,
            ),
          ),
          const Gap.md(),
          Text('Type what you hear',
              style: LangoType.h3, textAlign: TextAlign.center),
          const Gap.xl(),

          TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            enabled: result == null,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _check(),
            style: LangoType.native(widget.language.code, size: 22),
            decoration: const InputDecoration(
              hintText: '…',
            ),
          ),
          const Gap.md(),

          if (result == null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                label: Text(_hintShown ? 'Hint shown' : 'Show a hint'),
                onPressed: prompt.hint == null || _hintShown
                    ? null
                    : () => setState(() => _hintShown = true),
              ),
            ),
            if (_hintShown && prompt.hint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: LangoSpace.md),
                child: Text(prompt.hint!, style: LangoType.bodyMuted),
              ),
            FilledButton(
              onPressed: _check,
              child: const Text('Check'),
            ),
          ] else ...[
            _Feedback(
              result: result,
              prompt: prompt,
              language: widget.language,
            ),
            const Gap.lg(),
            FilledButton(
              onPressed: _next,
              child: Text(
                  _index == prompts.length - 1 ? 'Finish' : 'Continue'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Prompt {
  const _Prompt({required this.item, required this.text, this.hint});

  final VocabItem item;

  /// What is spoken and what the learner must type.
  final String text;

  /// Revealed on request — the translation for a sentence, the reading for a
  /// single word.
  final String? hint;
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.result,
    required this.prompt,
    required this.language,
  });

  final DictationResult result;
  final _Prompt prompt;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    final (headline, icon, color) = result.correct
        ? ('Correct', Icons.check_circle_rounded, LangoColors.success)
        : result.isNearMiss
            ? ('Close', Icons.adjust_rounded, LangoColors.warning)
            : ('Not quite', Icons.cancel_rounded, LangoColors.error);

    return LangoCard(
      padding: const EdgeInsets.all(LangoSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: LangoSpace.xs),
              Text(headline, style: LangoType.label.copyWith(color: color)),
            ],
          ),
          const Gap.md(),
          ComparisonText(
            comparison: result.comparison,
            languageCode: language.code,
            size: 20,
          ),
          if (!result.correct) ...[
            const Gap.md(),
            ComparisonSummary(
              comparison: result.comparison,
              languageCode: language.code,
            ),
          ],
          if (prompt.hint != null) ...[
            const Gap.sm(),
            Text(prompt.hint!, style: LangoType.bodyMuted),
          ],
        ],
      ),
    );
  }
}
