import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/comparison.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';

/// Concepts available for the languages the learner studies. Keyed by the
/// comma-joined language codes so the family argument compares by value.
final comparisonsProvider = FutureProvider.autoDispose
    .family<List<Concept>, String>((ref, languageCodesKey) async {
  final codes =
      languageCodesKey.isEmpty ? <String>[] : languageCodesKey.split(',');
  if (codes.length < 2) return const [];
  return ref.watch(comparisonServiceProvider).concepts(languages: codes);
});

/// Side-by-side comparison (US-120, US-121).
///
/// Only shown to a learner studying more than one language — comparing a
/// language with itself is not a feature. The list never implies that two
/// structures are equivalent: each card carries how close the match actually
/// is, and false friends are labelled as such.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  ConceptKind? _kind;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final languages =
        profile?.languages.map((l) => l.language).toList() ?? const [];
    final key = languages.map((l) => l.code).join(',');

    if (languages.length < 2) {
      return LangoPage(
        title: 'Compare',
        child: Column(
          children: [
            const Gap.xxl(),
            LangoEmpty(
              icon: Icons.compare_arrows_rounded,
              title: 'Comparison needs two languages',
              message: 'This screen lines up the same idea in each language '
                  'you are studying. Add a second language and it fills in.',
              actionLabel: 'Change languages',
              onAction: () => context.push('/settings'),
            ),
          ],
        ),
      );
    }

    final concepts = ref.watch(comparisonsProvider(key));

    return Scaffold(
      appBar: AppBar(title: const Text('Compare')),
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
                    0,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _kind == null,
                          onSelected: (_) => setState(() => _kind = null),
                        ),
                        for (final kind in ConceptKind.values) ...[
                          const SizedBox(width: LangoSpace.xs),
                          ChoiceChip(
                            label: Text(kind.label),
                            selected: _kind == kind,
                            onSelected: (_) => setState(() => _kind = kind),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: concepts.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(LangoSpace.gutter),
                      child: LangoSkeletonList(count: 3),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.all(LangoSpace.gutter),
                      child: LangoError(
                        message: "We couldn't load the comparisons. "
                            'Check your connection.',
                        onRetry: () =>
                            ref.invalidate(comparisonsProvider(key)),
                      ),
                    ),
                    data: (all) {
                      final items = _kind == null
                          ? all
                          : all.where((c) => c.kind == _kind).toList();
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(LangoSpace.gutter),
                          child: LangoEmpty(
                            icon: Icons.compare_arrows_rounded,
                            title: 'Nothing to compare here yet',
                            message: 'Try another category.',
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          LangoSpace.gutter,
                          LangoSpace.md,
                          LangoSpace.gutter,
                          LangoSpace.xxl,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Gap.md(),
                        itemBuilder: (context, i) => _ConceptCard(
                          concept: items[i],
                          languages: languages,
                        ),
                      );
                    },
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

class _ConceptCard extends StatelessWidget {
  const _ConceptCard({required this.concept, required this.languages});

  final Concept concept;
  final List<TargetLanguage> languages;

  @override
  Widget build(BuildContext context) {
    return LangoCard(
      padding: const EdgeInsets.all(LangoSpace.lg),
      onTap: () => context.push('/compare/detail', extra: concept),
      semanticLabel: '${concept.english}. ${concept.equivalence.label}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(concept.english, style: LangoType.h3)),
              EquivalenceBadge(equivalence: concept.equivalence),
            ],
          ),
          const Gap.md(),
          for (final language in languages) ...[
            if (concept.entryFor(language.code) case final entry?)
              Padding(
                padding: const EdgeInsets.only(bottom: LangoSpace.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(language.flag, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: LangoSpace.xs),
                    Expanded(
                      child: Text(
                        entry.exampleNative,
                        style: LangoType.native(
                          language.code,
                          size: 18,
                          weight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// How close the match is, stated rather than implied (US-121).
class EquivalenceBadge extends StatelessWidget {
  const EquivalenceBadge({super.key, required this.equivalence});

  final Equivalence equivalence;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (equivalence) {
      Equivalence.close => (LangoColors.success, Icons.check_rounded),
      Equivalence.partial => (LangoColors.warning, Icons.compare_rounded),
      Equivalence.falseFriend => (LangoColors.error, Icons.warning_amber_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: LangoSpace.xs, vertical: 4),
      decoration: const BoxDecoration(
        color: LangoPalette.white,
        borderRadius: LangoRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            equivalence.label,
            style: LangoType.caption.copyWith(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
