import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../services/srs/srs_engine.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/rating_bar.dart';
import '../../widgets/study_card.dart';

/// Study queue: due vocabulary first, then new (untracked) words (US-021/030).
final flashcardQueueProvider = FutureProvider.autoDispose
    .family<List<VocabItem>, String>((ref, language) async {
  final reviews = ref.watch(reviewServiceProvider);
  final content = ref.watch(contentServiceProvider);

  final due = await reviews.dueItems(language: language, limit: 20);
  final dueVocabIds = due
      .where((i) => i.itemType == 'vocabulary')
      .map((i) => i.itemId)
      .toList();
  final dueItems = await content.vocabularyByIds(dueVocabIds);
  // Preserve the review-priority order returned by dueItems().
  final byId = {for (final v in dueItems) v.id: v};
  final ordered = [
    for (final id in dueVocabIds)
      if (byId[id] != null) byId[id]!
  ];

  if (ordered.length >= 10) return ordered;

  final tracked = await reviews.statesFor(language, itemType: 'vocabulary');
  final trackedIds = tracked.map((t) => t.itemId).toSet();
  final fresh = <VocabItem>[];
  for (var page = 0; fresh.length < 10 - ordered.length && page < 10; page++) {
    final batch =
        await content.vocabulary(language, offset: page * 50, limit: 50);
    if (batch.isEmpty) break;
    fresh.addAll(batch.where((v) => !trackedIds.contains(v.id)));
  }
  return [...ordered, ...fresh.take(10 - ordered.length)];
});

class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  int _index = 0;
  bool _revealed = false;
  int _correct = 0;
  int _incorrect = 0;
  bool _saving = false;

  Future<void> _rate(VocabItem item, ReviewRating rating) async {
    setState(() => _saving = true);
    try {
      await ref.read(reviewServiceProvider).recordReview(
            itemType: 'vocabulary',
            itemId: item.id,
            language: widget.language.code,
            rating: rating,
            reviewType: 'flashcard',
          );
      setState(() {
        rating == ReviewRating.again ? _incorrect++ : _correct++;
        _index++;
        _revealed = false;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save your answer. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(flashcardQueueProvider(widget.language.code));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
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
            child: queue.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(LangoSpace.gutter),
                child: LangoSkeletonList(count: 2),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(LangoSpace.gutter),
                child: LangoError(
                  message:
                      "We couldn't load your cards. Check your connection.",
                  onRetry: () => ref
                      .invalidate(flashcardQueueProvider(widget.language.code)),
                ),
              ),
              data: _content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(List<VocabItem> cards) {
    if (cards.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoEmpty(
          icon: Icons.style_outlined,
          title: 'Nothing to study right now',
          message: 'Every word in this deck is scheduled for later. '
              'Come back when reviews are due.',
        ),
      );
    }

    if (_index >= cards.length) {
      return _SummaryView(correct: _correct, incorrect: _incorrect);
    }

    final item = cards[_index];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LangoSpace.gutter,
        LangoSpace.md,
        LangoSpace.gutter,
        LangoSpace.lg,
      ),
      child: Column(
        children: [
          StudyProgress(index: _index, total: cards.length),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: StudyCard(
                  front: item.word,
                  language: widget.language,
                  revealed: _revealed,
                  onReveal: () => setState(() => _revealed = true),
                  romanization: item.romanization,
                  back: item.translation,
                  exampleNative: item.exampleNative,
                  exampleTranslation: item.exampleTranslation,
                  speakText: item.word,
                  tint: LangoColors.tintFor(item.id),
                ),
              ),
            ),
          ),
          if (_revealed)
            ReviewRatingBar(
              enabled: !_saving,
              onRate: (rating) => _rate(item, rating),
            )
          else
            FilledButton(
              onPressed: () => setState(() => _revealed = true),
              child: const Text('Show answer'),
            ),
        ],
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.correct, required this.incorrect});

  final int correct;
  final int incorrect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(LangoSpace.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Session complete 🎉',
              style: LangoType.h1, textAlign: TextAlign.center),
          const Gap.md(),
          Text('Recalled $correct  ·  Missed $incorrect',
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
}
