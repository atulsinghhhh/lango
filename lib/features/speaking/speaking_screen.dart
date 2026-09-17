import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../services/speech/speech_comparison.dart';
import '../../services/speech_service.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/comparison_text.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/native_text.dart';
import '../../widgets/study_card.dart';

enum _Stage { loading, ready, listening, result, unavailable }

/// Speaking practice (US-080, US-081).
///
/// What this screen does: shows a target sentence, records it with the
/// device's own speech recogniser, and compares the transcript with the
/// target — missing words, extra words, replaced words, and the recogniser's
/// confidence in its own transcript.
///
/// What it deliberately does not do: score pronunciation. A transcript
/// mismatch can mean the learner said the wrong thing or that the recogniser
/// misheard a correct sentence, and nothing available here can tell those
/// apart. The screen says so rather than inventing a percentage (US-081,
/// CLAUDE.md).
class SpeakingScreen extends ConsumerStatefulWidget {
  const SpeakingScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  ConsumerState<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends ConsumerState<SpeakingScreen> {
  /// Captured in initState: `dispose` must not read from `ref`, and leaving
  /// mid-recording still has to release the microphone.
  late final SpeechService _speech;

  _Stage _stage = _Stage.loading;
  SpeechUnavailableReason? _unavailable;

  List<_Target>? _targets;
  int _index = 0;
  String? _localeId;

  String _transcript = '';
  double? _confidence;
  SpeechComparison? _comparison;
  int _attempted = 0;

  static const _targetCount = 8;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechServiceProvider);
    _load();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final pool = await ref
          .read(contentServiceProvider)
          .vocabulary(widget.language.code, limit: 50);
      final withExamples = pool
          .where((v) => (v.exampleNative ?? '').isNotEmpty)
          .toList();
      // Speaking a full sentence is the exercise; a lone word barely is. Fall
      // back to words only when the catalog has no example sentences yet.
      final source = withExamples.isNotEmpty ? withExamples : pool;
      final targets = ([...source]..shuffle(Random()))
          .take(_targetCount)
          .map(
            (v) => _Target(
              item: v,
              text: v.exampleNative ?? v.word,
              translation: v.exampleTranslation ?? v.translation,
            ),
          )
          .toList();

      if (!mounted) return;
      if (targets.isEmpty) {
        setState(() {
          _targets = targets;
          _stage = _Stage.ready;
        });
        return;
      }

      final localeId = await _speech.prepare(widget.language);
      if (!mounted) return;
      setState(() {
        _targets = targets;
        _localeId = localeId;
        _stage = _Stage.ready;
      });
    } on SpeechUnavailable catch (e) {
      if (!mounted) return;
      setState(() {
        _unavailable = e.reason;
        _stage = _Stage.unavailable;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unavailable = SpeechUnavailableReason.notAvailable;
        _stage = _Stage.unavailable;
      });
    }
  }

  Future<void> _startListening() async {
    final localeId = _localeId;
    if (localeId == null) return;
    setState(() {
      _stage = _Stage.listening;
      _transcript = '';
      _confidence = null;
      _comparison = null;
    });

    try {
      await _speech.start(
        localeId: localeId,
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _transcript = result.text;
            _confidence = result.confidence;
          });
          if (result.isFinal) _finish();
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unavailable = SpeechUnavailableReason.notAvailable;
        _stage = _Stage.unavailable;
      });
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    // The recogniser still delivers a final result after stop(); `_finish`
    // runs from that callback so a late transcript is not thrown away.
  }

  Future<void> _finish() async {
    if (!mounted || _stage == _Stage.result) return;
    final target = _targets![_index];
    final comparison = SpeechComparison.compare(target.text, _transcript);

    setState(() {
      _comparison = comparison;
      _stage = _Stage.result;
      _attempted++;
    });

    try {
      await ref
          .read(speakingServiceProvider)
          .record(
            language: widget.language.code,
            targetText: target.text,
            recognizedText: _transcript,
            comparison: comparison,
            recognitionConfidence: _confidence,
            itemType: 'vocabulary',
            itemId: target.item.id,
          );
    } catch (_) {
      // Best effort — an unsaved attempt must not break the practice flow.
    }
  }

  void _next() {
    setState(() {
      _index++;
      _transcript = '';
      _confidence = null;
      _comparison = null;
      _stage = _Stage.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speaking'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: LangoSpace.md),
            child: Center(
              child: Text(
                widget.language.flag,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: LangoBreak.maxContentWidth,
            ),
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_stage == _Stage.loading) {
      return const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoSkeletonList(count: 2),
      );
    }

    if (_stage == _Stage.unavailable) {
      return Padding(
        padding: const EdgeInsets.all(LangoSpace.gutter),
        child: _Unavailable(reason: _unavailable!, onRetry: _load),
      );
    }

    final targets = _targets;
    if (targets == null || targets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoEmpty(
          icon: Icons.mic_none_rounded,
          title: 'Nothing to say yet',
          message:
              'Speaking practice needs vocabulary in this language. '
              'Study a few words first.',
        ),
      );
    }

    if (_index >= targets.length) {
      return Padding(
        padding: const EdgeInsets.all(LangoSpace.gutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Speaking practice complete 🎉',
              style: LangoType.h1,
              textAlign: TextAlign.center,
            ),
            const Gap.md(),
            Text(
              '$_attempted ${_attempted == 1 ? 'sentence' : 'sentences'} '
              'recorded. Every attempt is saved, so you can see how the '
              'transcripts change over time.',
              style: LangoType.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const Gap.xl(),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }

    final target = targets[_index];

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
          StudyProgress(index: _index, total: targets.length),
          const Gap.xl(),

          Text('SAY THIS', style: LangoType.caption),
          const Gap.sm(),
          NativeSentence(
            sentence: target.text,
            languageCode: widget.language.code,
            translation: target.translation,
            size: 28,
          ),
          const Gap.md(),
          Align(
            alignment: Alignment.centerLeft,
            child: AudioButton(
              text: target.text,
              language: widget.language,
              size: AudioButtonSize.medium,
            ),
          ),
          const Gap.xxl(),

          Center(
            child: _MicButton(
              listening: _stage == _Stage.listening,
              enabled: _stage != _Stage.result,
              onPressed: _stage == _Stage.listening
                  ? _stopListening
                  : _startListening,
            ),
          ),
          const Gap.md(),
          Center(
            child: Text(
              switch (_stage) {
                _Stage.listening => 'Listening — tap to stop',
                _Stage.result => 'Attempt saved',
                _ => 'Tap to speak',
              },
              style: LangoType.label.copyWith(
                color: LangoColors.foregroundMuted,
              ),
            ),
          ),

          if (_stage == _Stage.listening && _transcript.isNotEmpty) ...[
            const Gap.lg(),
            Center(
              child: Text(
                _transcript,
                textAlign: TextAlign.center,
                style: LangoType.native(
                  widget.language.code,
                  size: 20,
                  weight: FontWeight.w400,
                ),
              ),
            ),
          ],

          if (_stage == _Stage.result && _comparison != null) ...[
            const Gap.xl(),
            _Feedback(
              comparison: _comparison!,
              transcript: _transcript,
              confidence: _confidence,
              language: widget.language,
            ),
            const Gap.lg(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _startListening,
                    child: const Text('Try again'),
                  ),
                ),
                const SizedBox(width: LangoSpace.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(
                      _index == targets.length - 1 ? 'Finish' : 'Next sentence',
                    ),
                  ),
                ),
              ],
            ),
          ],

          const Gap.xl(),
          const _RecognitionNote(),
        ],
      ),
    );
  }
}

class _Target {
  const _Target({
    required this.item,
    required this.text,
    required this.translation,
  });

  final VocabItem item;
  final String text;
  final String translation;
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.enabled,
    required this.onPressed,
  });

  final bool listening;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listening ? 'Stop recording' : 'Start recording',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: AnimatedContainer(
            duration: LangoMotion.normal,
            curve: LangoMotion.easing,
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: listening
                  ? LangoColors.primary
                  : enabled
                  ? LangoPalette.tintPink
                  : LangoColors.surfaceMuted,
            ),
            child: Icon(
              listening ? Icons.stop_rounded : Icons.mic_rounded,
              size: 44,
              color: listening
                  ? LangoColors.primaryForeground
                  : enabled
                  ? LangoColors.primaryDeep
                  : LangoColors.foregroundMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.comparison,
    required this.transcript,
    required this.confidence,
    required this.language,
  });

  final SpeechComparison comparison;
  final String transcript;
  final double? confidence;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    return LangoCard(
      padding: const EdgeInsets.all(LangoSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHAT WAS TRANSCRIBED', style: LangoType.caption),
          const Gap.sm(),
          if (transcript.trim().isEmpty)
            Text(
              'Nothing was picked up. That usually means the microphone '
              'heard silence, not that the sentence was wrong.',
              style: LangoType.bodyMuted,
            )
          else
            Text(
              transcript,
              style: LangoType.native(
                language.code,
                size: 20,
                weight: FontWeight.w400,
              ),
            ),
          const Gap.lg(),
          Text('AGAINST THE TARGET', style: LangoType.caption),
          const Gap.sm(),
          ComparisonText(
            comparison: comparison,
            languageCode: language.code,
            size: 20,
          ),
          const Gap.md(),
          ComparisonSummary(
            comparison: comparison,
            languageCode: language.code,
          ),
          const Gap.md(),
          // Confidence is the recogniser's, and only shown when the platform
          // actually reported one — an unknown confidence is not zero.
          if (confidence != null)
            Text(
              'The recogniser was ${(confidence! * 100).round()}% confident in '
              'its own transcript.',
              style: LangoType.bodyMuted.copyWith(fontSize: 14),
            )
          else
            Text(
              'This device did not report how confident the recogniser was.',
              style: LangoType.bodyMuted.copyWith(fontSize: 14),
            ),
        ],
      ),
    );
  }
}

/// The standing caveat. Permanent rather than dismissible, because the
/// distinction it draws is the difference between an honest feature and a
/// misleading one (US-081).
class _RecognitionNote extends StatelessWidget {
  const _RecognitionNote();

  @override
  Widget build(BuildContext context) {
    return LangoCard(
      padding: const EdgeInsets.all(LangoSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: LangoColors.primaryDeep,
            size: 20,
          ),
          const SizedBox(width: LangoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This is speech recognition, not pronunciation scoring',
                  style: LangoType.label,
                ),
                const SizedBox(height: 2),
                Text(
                  'We compare what your device transcribed against the target '
                  'sentence. A mismatch can mean you said something different '
                  '— or that the recogniser misheard you. We cannot tell those '
                  'apart, so we do not give you a pronunciation score.',
                  style: LangoType.bodyMuted.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.reason, required this.onRetry});

  final SpeechUnavailableReason reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (reason) {
      SpeechUnavailableReason.languageNotSupported => (
        'No speech model for this language',
        'Your device has speech recognition, but no model for this '
            'language. On Android you can add one in the Google app under '
            'Voice; on iOS, in Settings under General → Keyboard → '
            'Dictation Languages.',
      ),
      SpeechUnavailableReason.notAvailable => (
        'Speech recognition is not available',
        'We could not start the microphone. Check that Lango has '
            'microphone and speech permission, then try again.',
      ),
    };

    return LangoError(title: title, message: message, onRetry: onRetry);
  }
}
