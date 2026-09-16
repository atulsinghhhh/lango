import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/native_text.dart';

const _pageSize = 30;

final vocabPageProvider = FutureProvider.autoDispose
    .family<List<VocabItem>, (String, int)>((ref, key) async {
  final (language, page) = key;
  return ref
      .watch(contentServiceProvider)
      .vocabulary(language, offset: page * _pageSize, limit: _pageSize);
});

/// Vocabulary browser (REDESIGN.md §14).
///
/// Each word is a tinted card in the reference's style: the native word is the
/// largest element, the reading sits beneath it, and the English gloss is
/// small uppercase and tracked. Audio is a prominent circular control, not a
/// trailing icon.
class VocabListScreen extends ConsumerStatefulWidget {
  const VocabListScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  ConsumerState<VocabListScreen> createState() => _VocabListScreenState();
}

class _VocabListScreenState extends ConsumerState<VocabListScreen> {
  final List<VocabItem> _items = [];
  int _page = 0;
  bool _hasMore = true;

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(vocabPageProvider((widget.language.code, _page)));
    page.whenData((items) {
      if (items.isNotEmpty && !_items.any((i) => i.id == items.first.id)) {
        _items.addAll(items);
      }
      _hasMore = items.length == _pageSize;
    });

    final loadingFirstPage = _items.isEmpty && page.isLoading;
    final failedFirstPage = _items.isEmpty && page.hasError;

    return Scaffold(
      appBar: AppBar(
        title: Text('Vocabulary'),
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
      floatingActionButton: _items.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: LangoColors.primary,
              foregroundColor: LangoColors.primaryForeground,
              elevation: 0,
              highlightElevation: 0,
              shape: const RoundedRectangleBorder(
                  borderRadius: LangoRadius.mdAll),
              icon: const Icon(Icons.style_rounded),
              label: const Text('Flashcards'),
              onPressed: () =>
                  context.push('/learn/flashcards?lang=${widget.language.code}'),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
            child: _buildBody(loadingFirstPage, failedFirstPage, page.isLoading),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool loadingFirst, bool failedFirst, bool pageLoading) {
    if (failedFirst) {
      return Padding(
        padding: const EdgeInsets.all(LangoSpace.gutter),
        child: LangoError(
          message: "We couldn't load this word list. Check your connection.",
          onRetry: () => ref
              .invalidate(vocabPageProvider((widget.language.code, _page))),
        ),
      );
    }

    if (loadingFirst) {
      return const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoSkeletonList(count: 4),
      );
    }

    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoEmpty(
          icon: Icons.style_outlined,
          title: 'No words here yet',
          message:
              'Vocabulary for this language has not been added. Try another '
              'skill in the meantime.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        LangoSpace.gutter,
        LangoSpace.md,
        LangoSpace.gutter,
        104, // clear the FAB
      ),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const Gap.md(),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          // Sentinel row: load the next page when it scrolls into view.
          if (!pageLoading) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => setState(() => _page++));
          }
          return const LangoSkeleton.card();
        }
        final item = _items[i];
        return _VocabCard(
          item: item,
          language: widget.language,
          tint: LangoColors.tintFor(item.id),
          onTap: () => showModalBottomSheet(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (_) =>
                VocabDetailSheet(item: item, language: widget.language),
          ),
        );
      },
    );
  }
}

class _VocabCard extends StatelessWidget {
  const _VocabCard({
    required this.item,
    required this.language,
    required this.tint,
    required this.onTap,
  });

  final VocabItem item;
  final TargetLanguage language;
  final LangoTint tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LangoCard.tinted(
      tint: tint,
      onTap: onTap,
      padding: const EdgeInsets.all(LangoSpace.lg),
      semanticLabel: '${item.word}, ${item.translation}',
      child: Row(
        children: [
          Expanded(
            child: NativeWord(
              word: item.word,
              languageCode: language.code,
              romanization: item.romanization,
              gloss: item.translation,
            ),
          ),
          const SizedBox(width: LangoSpace.sm),
          AudioButton(
            text: item.word,
            language: language,
            size: AudioButtonSize.small,
          ),
        ],
      ),
    );
  }
}

/// Word detail (REDESIGN.md §13, §14) — one word, everything about it, no
/// competing controls.
class VocabDetailSheet extends ConsumerWidget {
  const VocabDetailSheet(
      {super.key, required this.item, required this.language});

  final VocabItem item;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LangoSpace.gutter,
            0,
            LangoSpace.gutter,
            LangoSpace.gutter,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: NativeWord(
                      word: item.word,
                      languageCode: language.code,
                      romanization: item.romanization,
                      gloss: item.translation,
                      size: 44,
                    ),
                  ),
                  const SizedBox(width: LangoSpace.sm),
                  AudioButton(text: item.word, language: language),
                ],
              ),
              if (item.partOfSpeech != null) ...[
                const Gap.md(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: LangoSpace.sm, vertical: 6),
                  decoration: const BoxDecoration(
                    color: LangoColors.surfaceMuted,
                    borderRadius: LangoRadius.pillAll,
                  ),
                  child: Text(item.partOfSpeech!.toUpperCase(),
                      style: LangoType.caption),
                ),
              ],
              if (item.exampleNative != null) ...[
                const Gap.xl(),
                Text('EXAMPLE', style: LangoType.caption),
                const Gap.xs(),
                LangoCard(
                  padding: const EdgeInsets.all(LangoSpace.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: NativeSentence(
                          sentence: item.exampleNative!,
                          languageCode: language.code,
                          translation: item.exampleTranslation,
                        ),
                      ),
                      const SizedBox(width: LangoSpace.xs),
                      AudioButton(
                        text: item.exampleNative!,
                        language: language,
                        size: AudioButtonSize.small,
                      ),
                    ],
                  ),
                ),
              ],
              const Gap.lg(),
            ],
          ),
        ),
      ),
    );
  }
}
