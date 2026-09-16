import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/lango_states.dart';

final grammarProvider = FutureProvider.autoDispose
    .family<List<GrammarPoint>, String>((ref, language) async {
  return ref.watch(contentServiceProvider).grammarPoints(language);
});

/// Grammar index (REDESIGN.md §15).
///
/// Hierarchy comes from typography — the pattern itself is native-styled and
/// large, its meaning sits beneath in muted body — rather than from wrapping
/// every row in a card.
class GrammarListScreen extends ConsumerWidget {
  const GrammarListScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grammar = ref.watch(grammarProvider(language.code));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grammar'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: LangoSpace.md),
            child: Center(
              child: Text(language.flag, style: const TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
            child: grammar.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(LangoSpace.gutter),
                child: LangoSkeletonList(count: 4),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(LangoSpace.gutter),
                child: LangoError(
                  message:
                      "We couldn't load grammar for this language. "
                      'Check your connection.',
                  onRetry: () => ref.invalidate(grammarProvider(language.code)),
                ),
              ),
              data: (points) {
                if (points.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(LangoSpace.gutter),
                    child: LangoEmpty(
                      icon: Icons.menu_book_outlined,
                      title: 'No grammar points yet',
                      message: 'Grammar for this language has not been added.',
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
                  itemCount: points.length,
                  separatorBuilder: (_, _) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: LangoSpace.md),
                    child: Divider(height: 1),
                  ),
                  itemBuilder: (context, i) {
                    final p = points[i];
                    return InkWell(
                      onTap: () =>
                          context.push('/learn/grammar/detail', extra: p),
                      borderRadius: LangoRadius.mdAll,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: LangoSpace.xs),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: LangoType.native(language.code,
                                        size: 22),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(p.meaning, style: LangoType.bodyMuted),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 20, color: LangoColors.primaryDeep),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
