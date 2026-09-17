import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/language.dart';
import '../../models/profile.dart';
import '../../models/tutor.dart';
import '../../services/providers.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/language_switcher.dart';

/// Whether a tutor backend is deployed. Asked once per app run: the answer
/// only changes on deploy, and a probe on every visit would be wasted.
final tutorAvailableProvider = FutureProvider<bool>((ref) async {
  return ref.watch(tutorServiceProvider).isAvailable();
});

final tutorConversationsProvider = FutureProvider.autoDispose
    .family<List<TutorConversation>, String>((ref, language) async {
  return ref.watch(tutorServiceProvider).conversations(language: language);
});

/// AI Tutor (US-090).
///
/// Picks a scenario or resumes a stored conversation. When no tutor backend is
/// deployed, the screen says exactly that instead of offering a conversation
/// it cannot hold.
class TutorScreen extends ConsumerWidget {
  const TutorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final lang = ref.watch(effectiveLanguageProvider) ?? TargetLanguage.korean;
    final languages = profile?.languages ?? const [];
    final available = ref.watch(tutorAvailableProvider);
    final conversations = ref.watch(tutorConversationsProvider(lang.code));

    return LangoPage(
      title: 'Tutor',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (languages.length > 1) ...[
            LanguageSwitcher(languages: languages),
            const Gap.xl(),
          ],
          Text('Practise a real conversation', style: LangoType.h2),
          const Gap.xs(),
          Text(
            'Pick a situation and talk your way through it in '
            '${lang.endonym}. Mistakes get explained, not just marked.',
            style: LangoType.bodyMuted,
          ),
          const Gap.xl(),

          available.when(
            loading: () =>
                const LangoSkeleton(height: 84, radius: LangoRadius.xl),
            error: (_, _) => const _NotConnected(),
            data: (ok) => ok ? const SizedBox.shrink() : const _NotConnected(),
          ),

          if (available.value == true) ...[
            conversations.when(
              loading: () =>
                  const LangoSkeleton(height: 60, radius: LangoRadius.xl),
              error: (_, _) => const SizedBox.shrink(),
              data: (list) {
                final open = list.where((c) => c.isOpen).toList();
                if (open.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('CONTINUE', style: LangoType.caption),
                    const Gap.md(),
                    for (final c in open.take(3)) ...[
                      _ConversationRow(conversation: c),
                      const Gap.sm(),
                    ],
                    const Gap.xl(),
                  ],
                );
              },
            ),
          ],

          Text('Scenarios', style: LangoType.h3),
          const Gap.md(),
          for (var i = 0; i < _scenarios.length; i++) ...[
            _ScenarioCard(
              scenario: _scenarios[i],
              index: i,
              language: lang,
              enabled: available.value == true,
              profile: profile,
            ),
            if (i != _scenarios.length - 1) const Gap.md(),
          ],

          if (available.value == true) ...[
            const Gap.xl(),
            conversations.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (list) {
                final past = list.where((c) => !c.isOpen).toList();
                if (past.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('PAST CONVERSATIONS', style: LangoType.caption),
                    const Gap.md(),
                    for (final c in past.take(10)) ...[
                      _ConversationRow(conversation: c),
                      const Gap.sm(),
                    ],
                  ],
                );
              },
            ),
          ],
          const Gap.xl(),
        ],
      ),
    );
  }

  /// Scenario prompts are written in English and handed to the tutor as a
  /// role instruction, so nothing about them is language-specific.
  static const _scenarios = <_Scenario>[
    _Scenario(
      '☕',
      'Café',
      'Ordering a drink and being asked whether it is to take away.',
    ),
    _Scenario(
      '🚉',
      'Directions',
      'Asking a stranger how to get to the station, and how long it takes.',
    ),
    _Scenario(
      '🍜',
      'Restaurant',
      'Being seated, asked how many people, and ordering a meal.',
    ),
    _Scenario(
      '🙋',
      'Introductions',
      'Meeting someone for the first time: names, where you are from, what '
          'you do.',
    ),
    _Scenario(
      '🛍️',
      'Shopping',
      'Asking the price of something, whether another size exists, and paying.',
    ),
  ];
}

class _Scenario {
  const _Scenario(this.emoji, this.title, this.instruction);
  final String emoji;
  final String title;

  /// Handed to the tutor verbatim as the situation to play.
  final String instruction;
}

class _NotConnected extends StatelessWidget {
  const _NotConnected();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LangoSpace.xl),
      child: LangoCard(
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
                  Text('No tutor is connected', style: LangoType.label),
                  const SizedBox(height: 2),
                  Text(
                    'Conversations need a language model, which runs on the '
                    'server rather than in the app. Once the tutor function is '
                    'deployed, the scenarios below become live. Until then we '
                    'would rather show you nothing than a scripted '
                    'conversation.',
                    style: LangoType.bodyMuted.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation});

  final TutorConversation conversation;

  @override
  Widget build(BuildContext context) {
    final date = conversation.startedAt.toLocal();
    return LangoCard(
      padding: const EdgeInsets.all(LangoSpace.md),
      onTap: () => context.push('/tutor/chat', extra: conversation),
      semanticLabel: conversation.title ?? 'Conversation',
      child: Row(
        children: [
          Icon(
            conversation.isOpen
                ? Icons.play_circle_outline_rounded
                : Icons.history_rounded,
            color: LangoColors.primaryDeep,
            size: 20,
          ),
          const SizedBox(width: LangoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conversation.title ?? 'Free conversation',
                    style: LangoType.label),
                Text(
                  '${date.day}/${date.month} · ${conversation.level.label}',
                  style: LangoType.caption,
                ),
              ],
            ),
          ),
          Text(conversation.language.flag,
              style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class _ScenarioCard extends ConsumerStatefulWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.index,
    required this.language,
    required this.enabled,
    required this.profile,
  });

  final _Scenario scenario;
  final int index;
  final TargetLanguage language;
  final bool enabled;
  final Profile? profile;

  @override
  ConsumerState<_ScenarioCard> createState() => _ScenarioCardState();
}

class _ScenarioCardState extends ConsumerState<_ScenarioCard> {
  bool _starting = false;

  Future<void> _start() async {
    final profile = widget.profile;
    if (profile == null || _starting) return;

    setState(() => _starting = true);
    try {
      final level = profile.languages
              .where((l) => l.language == widget.language)
              .map((l) => l.level)
              .firstOrNull ??
          ProficiencyLevel.beginner;

      final conversation =
          await ref.read(tutorServiceProvider).startConversation(
                language: widget.language,
                level: level,
                scenario: widget.scenario.instruction,
                title: widget.scenario.title,
              );
      ref.invalidate(tutorConversationsProvider(widget.language.code));
      if (!mounted) return;
      context.push('/tutor/chat', extra: conversation);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("We couldn't start that conversation.")),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = LangoColors.tints[widget.index % LangoColors.tints.length];

    return Opacity(
      // A disabled scenario is visibly inactive: the learner should not tap
      // expecting a conversation that cannot happen.
      opacity: widget.enabled ? 1 : 0.6,
      child: LangoCard.tinted(
        tint: tint,
        padding: const EdgeInsets.all(LangoSpace.lg),
        onTap: widget.enabled ? _start : null,
        semanticLabel: widget.enabled
            ? '${widget.scenario.title}. ${widget.scenario.instruction}'
            : '${widget.scenario.title}. Not available — no tutor connected.',
        child: Row(
          children: [
            Text(widget.scenario.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: LangoSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.scenario.title, style: LangoType.h3),
                  const SizedBox(height: 2),
                  Text(
                    widget.scenario.instruction,
                    style: LangoType.body.copyWith(
                      fontSize: 14,
                      color: LangoColors.foregroundSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_starting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (widget.enabled)
              const Icon(Icons.arrow_forward_rounded,
                  color: LangoColors.primaryDeep, size: 22),
          ],
        ),
      ),
    );
  }
}
