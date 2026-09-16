import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../services/srs/srs_engine.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/rating_bar.dart';
import '../../widgets/study_card.dart';

/// One due item resolved to displayable content, whatever its type.
class ReviewCard {
  const ReviewCard({
    required this.itemType,
    required this.itemId,
    required this.language,
    required this.front,
    required this.back,
    this.subtitle,
    this.speakText,
  });

  final String itemType;
  final String itemId;
  final String language;
  final String front;
  final String back;
  final String? subtitle;
  final String? speakText;
}

final reviewQueueProvider = FutureProvider.autoDispose
    .family<List<ReviewCard>, String?>((ref, language) async {
  final reviews = ref.watch(reviewServiceProvider);
  final content = ref.watch(contentServiceProvider);
  final due = await reviews.dueItems(language: language, limit: 50);

  final vocabIds = due
      .where((i) => i.itemType == 'vocabulary')
      .map((i) => i.itemId)
      .toList();
  final vocab = {
    for (final v in await content.vocabularyByIds(vocabIds)) v.id: v
  };

  final languages = due.map((i) => i.language).toSet();
  final grammar = <String, dynamic>{};
  final chars = <String, dynamic>{};
  for (final lang in languages) {
    for (final g in await content.grammarPoints(lang)) {
      grammar[g.id] = g;
    }
    for (final c in await content.characters(lang)) {
      chars[c.id] = c;
    }
  }

  final cards = <ReviewCard>[];
  for (final item in due) {
    switch (item.itemType) {
      case 'vocabulary':
        final v = vocab[item.itemId];
        if (v == null) continue;
        cards.add(ReviewCard(
          itemType: item.itemType,
          itemId: item.itemId,
          language: item.language,
          front: v.word,
          back: v.translation,
          subtitle: v.romanization,
          speakText: v.word,
        ));
      case 'grammar':
        final g = grammar[item.itemId];
        if (g == null) continue;
        cards.add(ReviewCard(
          itemType: item.itemType,
          itemId: item.itemId,
          language: item.language,
          front: g.name,
          back: g.meaning,
          subtitle: g.examples.isNotEmpty ? g.examples.first.native : null,
        ));
      case 'character':
        final c = chars[item.itemId];
        if (c == null) continue;
        cards.add(ReviewCard(
          itemType: item.itemType,
          itemId: item.itemId,
          language: item.language,
          front: c.character,
          back: c.romanization,
          subtitle: c.exampleWord,
          speakText: c.character,
        ));
    }
  }
  return cards;
});

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.language});

  final TargetLanguage? language;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _index = 0;
  bool _revealed = false;
  int _correct = 0;
  int _incorrect = 0;
  bool _saving = false;

  Future<void> _rate(ReviewCard card, ReviewRating rating) async {
    setState(() => _saving = true);
    try {
      await ref.read(reviewServiceProvider).recordReview(
            itemType: card.itemType,
            itemId: card.itemId,
            language: card.language,
            rating: rating,
            reviewType: 'review',
          );
      setState(() {
        rating == ReviewRating.again ? _incorrect++ : _correct++;
        _index++;
        _revealed = false;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save the review. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(reviewQueueProvider(widget.language?.code));
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
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
                      "We couldn't load your reviews. Check your connection.",
                  onRetry: () => ref
                      .invalidate(reviewQueueProvider(widget.language?.code)),
                ),
              ),
              data: (cards) => _content(cards),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(List<ReviewCard> cards) {
    if (cards.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoEmpty(
          icon: Icons.check_rounded,
          title: 'No reviews due',
          message: "You're all caught up. New reviews appear as your "
              'scheduled words come round again.',
        ),
      );
    }

    if (_index >= cards.length) {
      return Padding(
        padding: const EdgeInsets.all(LangoSpace.gutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Reviews done 🎉',
                style: LangoType.h1, textAlign: TextAlign.center),
            const Gap.md(),
            Text(
              'Recalled $_correct  ·  Missed $_incorrect',
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

    final card = cards[_index];
    final lang = TargetLanguage.fromCode(card.language);

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
                  front: card.front,
                  language: lang,
                  revealed: _revealed,
                  onReveal: () => setState(() => _revealed = true),
                  back: card.back,
                  subtitle: card.subtitle,
                  speakText: card.speakText,
                  tint: LangoColors.tintFor(card.itemId),
                ),
              ),
            ),
          ),
          if (_revealed)
            ReviewRatingBar(
              enabled: !_saving,
              onRate: (rating) => _rate(card, rating),
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
