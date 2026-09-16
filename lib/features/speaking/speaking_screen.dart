import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/language.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/native_text.dart';

/// Speaking practice (REDESIGN.md §19).
///
/// The prompt-and-listen half is real: the learner sees a target sentence and
/// can hear it spoken. Recording is **not** wired up — there is no speech
/// backend, and REDESIGN.md §19 is explicit that fake pronunciation scores are
/// not acceptable. The mic is therefore shown disabled with the reason stated,
/// rather than recording audio we cannot evaluate.
class SpeakingScreen extends ConsumerWidget {
  const SpeakingScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompt = _promptFor(language);

    return LangoPage(
      title: 'Speaking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap.lg(),
          Text('Say:', style: LangoType.caption),
          const Gap.md(),
          NativeSentence(
            sentence: prompt.line,
            languageCode: language.code,
            translation: prompt.translation,
            size: 30,
          ),
          const Gap.xl(),
          Align(
            alignment: Alignment.centerLeft,
            child: AudioButton(
              text: prompt.line,
              language: language,
              size: AudioButtonSize.medium,
            ),
          ),
          const Gap.xxl(),

          Center(
            child: Column(
              children: [
                // Idle state only. Recording / processing / result states are
                // designed but not reachable without a speech backend.
                Container(
                  width: 112,
                  height: 112,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: LangoColors.surfaceMuted,
                  ),
                  child: const Icon(Icons.mic_none_rounded,
                      size: 44, color: LangoColors.foregroundMuted),
                ),
                const Gap.md(),
                Text('Hold to speak',
                    style: LangoType.label
                        .copyWith(color: LangoColors.foregroundMuted)),
              ],
            ),
          ),
          const Gap.xl(),

          LangoCard(
            padding: const EdgeInsets.all(LangoSpace.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.construction_rounded,
                    color: LangoColors.warning, size: 22),
                const SizedBox(width: LangoSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recording is not available yet',
                          style: LangoType.label),
                      const SizedBox(height: 2),
                      Text(
                        'Speech recognition is not connected. We would rather '
                        'show nothing than invent a pronunciation score.',
                        style: LangoType.bodyMuted.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap.xl(),
        ],
      ),
    );
  }

  ({String line, String translation}) _promptFor(TargetLanguage lang) =>
      switch (lang) {
        TargetLanguage.korean => (
            line: '오늘 커피를 마셨어요.',
            translation: 'I drank coffee today.'
          ),
        TargetLanguage.japanese => (
            line: '今日はコーヒーを飲みました。',
            translation: 'I drank coffee today.'
          ),
      };
}
