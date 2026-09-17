import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../services/search_service.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/native_text.dart';

/// Search results for one language and query. Keyed by `lang|query` so the
/// family argument compares by value and does not re-key on every rebuild.
final searchResultsProvider =
    FutureProvider.autoDispose.family<SearchResults, String>((ref, key) async {
  final separator = key.indexOf('|');
  final language = key.substring(0, separator);
  final query = key.substring(separator + 1);
  if (query.trim().length < SearchService.minQueryLength) {
    return const SearchResults();
  }
  return ref.watch(searchServiceProvider).all(language, query);
});

/// Search (US-023, US-140).
///
/// One field across vocabulary, grammar and characters, scoped to the active
/// language. Typing native script, romanization or English all work, so the
/// learner never has to decide which of the three they are typing.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';

  /// Long enough that a fast typist sends one request instead of six, short
  /// enough that the results feel like they follow the keystrokes.
  static const _debounceDelay = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    // The learner opened a search screen; the keyboard should already be up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final key = '${widget.language.code}|$_query';
    final results = ref.watch(searchResultsProvider(key));
    final tooShort = _query.length < SearchService.minQueryLength;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LangoSpace.gutter,
                    LangoSpace.sm,
                    LangoSpace.gutter,
                    LangoSpace.md,
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    decoration: InputDecoration(
                      hintText: 'Word, reading or meaning',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Clear',
                              onPressed: () {
                                _controller.clear();
                                _onChanged('');
                              },
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: tooShort
                      ? const _SearchPrompt()
                      : results.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(LangoSpace.gutter),
                            child: LangoSkeletonList(count: 3),
                          ),
                          error: (_, _) => Padding(
                            padding: const EdgeInsets.all(LangoSpace.gutter),
                            child: LangoError(
                              message: "We couldn't run that search. "
                                  'Check your connection.',
                              onRetry: () =>
                                  ref.invalidate(searchResultsProvider(key)),
                            ),
                          ),
                          data: (r) => _Results(
                            results: r,
                            language: widget.language,
                            query: _query,
                          ),
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

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(LangoSpace.gutter),
      child: LangoEmpty(
        icon: Icons.search_rounded,
        title: 'Search your language',
        message: 'Type at least two characters. Native script, romanization '
            'and English all work.',
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.results,
    required this.language,
    required this.query,
  });

  final SearchResults results;
  final TargetLanguage language;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(LangoSpace.gutter),
        child: LangoEmpty(
          icon: Icons.search_off_rounded,
          title: 'Nothing found for "$query"',
          message: 'Try a shorter query, or the word in another script.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        LangoSpace.gutter,
        0,
        LangoSpace.gutter,
        LangoSpace.xxl,
      ),
      children: [
        if (results.vocabulary.isNotEmpty) ...[
          Text('WORDS', style: LangoType.caption),
          const Gap.md(),
          for (final item in results.vocabulary) ...[
            _VocabResult(item: item, language: language),
            const Gap.sm(),
          ],
          const Gap.xl(),
        ],
        if (results.grammar.isNotEmpty) ...[
          Text('GRAMMAR', style: LangoType.caption),
          const Gap.md(),
          for (final point in results.grammar) ...[
            _GrammarResult(point: point, language: language),
            const Gap.sm(),
          ],
          const Gap.xl(),
        ],
        if (results.characters.isNotEmpty) ...[
          Text('CHARACTERS', style: LangoType.caption),
          const Gap.md(),
          Wrap(
            spacing: LangoSpace.sm,
            runSpacing: LangoSpace.sm,
            children: [
              for (final c in results.characters)
                _CharacterResult(character: c, language: language),
            ],
          ),
        ],
      ],
    );
  }
}

/// A word result carries everything US-023 asks for: meaning, reading, an
/// example, and audio.
class _VocabResult extends StatelessWidget {
  const _VocabResult({required this.item, required this.language});

  final VocabItem item;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    return LangoCard.tinted(
      tint: LangoColors.tintFor(item.id),
      padding: const EdgeInsets.all(LangoSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NativeWord(
                  word: item.word,
                  languageCode: item.language,
                  romanization: item.romanization,
                  gloss: item.translation,
                  size: 26,
                ),
                if (item.exampleNative != null) ...[
                  const Gap.sm(),
                  NativeSentence(
                    sentence: item.exampleNative!,
                    languageCode: item.language,
                    translation: item.exampleTranslation,
                    size: 16,
                  ),
                ],
              ],
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

class _GrammarResult extends StatelessWidget {
  const _GrammarResult({required this.point, required this.language});

  final GrammarPoint point;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    return LangoCard(
      padding: const EdgeInsets.all(LangoSpace.lg),
      onTap: () => context.push('/learn/grammar/detail', extra: point),
      semanticLabel: '${point.name}. ${point.meaning}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(point.name,
                    style: LangoType.native(point.language, size: 20)),
                const SizedBox(height: 2),
                Text(point.meaning, style: LangoType.bodyMuted),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded,
              color: LangoColors.primaryDeep, size: 20),
        ],
      ),
    );
  }
}

class _CharacterResult extends StatelessWidget {
  const _CharacterResult({required this.character, required this.language});

  final CharacterItem character;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${character.character}, ${character.romanization}',
      child: Material(
        color: Colors.transparent,
        borderRadius: LangoRadius.lgAll,
        child: InkWell(
          borderRadius: LangoRadius.lgAll,
          onTap: () =>
              context.push('/learn/writing/practice', extra: character),
          child: Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: LangoSpace.md),
            decoration: BoxDecoration(
              borderRadius: LangoRadius.lgAll,
              gradient: LangoColors.tintFor(character.character).gradient,
            ),
            child: Column(
              children: [
                Text(
                  character.character,
                  style: LangoType.native(character.language, size: 30),
                ),
                const SizedBox(height: 2),
                Text(character.romanization,
                    style: LangoType.caption, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
