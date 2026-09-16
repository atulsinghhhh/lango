import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/content.dart';
import '../../core/theme.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/native_text.dart';

/// Guided writing practice (US-051/060): the character is shown as a ghost
/// template with stroke-count guidance, and the learner traces over it.
/// No handwriting recognition in MVP — completion is self-assessed.
class CharacterPracticeScreen extends ConsumerStatefulWidget {
  const CharacterPracticeScreen({super.key, required this.character});

  final CharacterItem character;

  @override
  ConsumerState<CharacterPracticeScreen> createState() =>
      _CharacterPracticeScreenState();
}

class _CharacterPracticeScreenState
    extends ConsumerState<CharacterPracticeScreen> {
  final List<List<Offset>> _strokes = [];
  bool _saving = false;

  Future<void> _complete() async {
    setState(() => _saving = true);
    try {
      await ref.read(reviewServiceProvider).recordExercise(
            itemType: 'character',
            itemId: widget.character.id,
            language: widget.character.language,
            exerciseType: 'writing',
            correct: true,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Practice recorded ✏️')));
        Navigator.of(context).maybePop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save practice. Please retry.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    final language = TargetLanguage.fromCode(c.language);

    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LangoSpace.gutter,
                    LangoSpace.md,
                    LangoSpace.gutter,
                    0,
                  ),
                  child: Column(
                    children: [
                      // The character is the point of the screen, so it leads.
                      Text(
                        c.character,
                        style: LangoType.native(language.code, size: 56),
                      ),
                      const Gap.xs(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(c.romanization.toUpperCase(),
                              style: LangoType.caption),
                          const SizedBox(width: LangoSpace.sm),
                          AudioButton(
                            text: c.character,
                            language: language,
                            size: AudioButtonSize.small,
                          ),
                        ],
                      ),
                      if (c.strokeCount != null) ...[
                        const Gap.xs(),
                        Text(
                          '${c.strokeCount} strokes — top to bottom, '
                          'left to right',
                          style: LangoType.bodyMuted.copyWith(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (c.pronunciationHint != null) ...[
                        const Gap.xxs(),
                        Text(c.pronunciationHint!,
                            style: LangoType.bodyMuted.copyWith(fontSize: 14),
                            textAlign: TextAlign.center),
                      ],
                      if (c.exampleWord != null) ...[
                        const Gap.sm(),
                        NativeSentence(
                          sentence: c.exampleWord!,
                          languageCode: language.code,
                          translation: c.exampleTranslation,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.all(LangoSpace.xl),
                        decoration: BoxDecoration(
                          color: LangoColors.surfaceMuted,
                          borderRadius: LangoRadius.xlAll,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Semantics(
                          label: 'Tracing area for ${c.character}',
                          child: GestureDetector(
                            onPanStart: (d) =>
                                setState(() => _strokes.add([d.localPosition])),
                            onPanUpdate: (d) =>
                                setState(() => _strokes.last.add(d.localPosition)),
                            child: CustomPaint(
                              painter: _TracePainter(
                                template: c.character,
                                strokes: _strokes,
                                inkColor: LangoColors.primary,
                                templateColor: LangoColors.border,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LangoSpace.gutter,
                    0,
                    LangoSpace.gutter,
                    LangoSpace.lg,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Clear'),
                          onPressed: () => setState(() => _strokes.clear()),
                        ),
                      ),
                      const SizedBox(width: LangoSpace.sm),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Done'),
                          onPressed:
                              _strokes.isEmpty || _saving ? null : _complete,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.template,
    required this.strokes,
    required this.inkColor,
    required this.templateColor,
  });

  final String template;
  final List<List<Offset>> strokes;
  final Color inkColor;
  final Color templateColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Ghost template character to trace over.
    final tp = TextPainter(
      text: TextSpan(
        text: template,
        style: TextStyle(
          fontSize: size.shortestSide * 0.7,
          color: templateColor,
          fontWeight: FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));

    final paint = Paint()
      ..color = inkColor
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_TracePainter oldDelegate) => true;
}
