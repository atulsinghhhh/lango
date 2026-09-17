import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/language.dart';
import '../../models/tutor.dart';
import '../../services/providers.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import 'tutor_screen.dart';

/// One tutor conversation (US-090, US-091, US-092).
///
/// Every turn is stored, so closing the screen mid-conversation loses nothing.
/// Corrections appear attached to the turn they correct, in the
/// your-sentence → correction → why → example shape US-092 specifies.
class TutorChatScreen extends ConsumerStatefulWidget {
  const TutorChatScreen({super.key, required this.conversation});

  final TutorConversation conversation;

  @override
  ConsumerState<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends ConsumerState<TutorChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  List<TutorMessage>? _messages;
  TutorContext? _context;
  bool _sending = false;
  TutorUnavailableReason? _failure;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tutor = ref.read(tutorServiceProvider);
    final profile = await ref.read(profileProvider.future);
    final goals = profile?.languages
            .where((l) => l.language == widget.conversation.language)
            .map((l) => l.goals)
            .firstOrNull ??
        const <String>[];

    try {
      final context = await tutor.buildContext(
        language: widget.conversation.language,
        level: widget.conversation.level,
        goals: goals,
        scenario: widget.conversation.scenario,
      );
      final messages = await tutor.messages(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _context = context;
        _messages = messages;
      });

      // An empty conversation: let the tutor speak first so the learner is not
      // staring at a blank screen in a script they barely read.
      if (messages.isEmpty) await _openingTurn();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  Future<void> _openingTurn() async {
    final context = _context;
    if (context == null) return;
    setState(() => _sending = true);
    try {
      final reply = await ref.read(tutorServiceProvider).openingTurn(
            conversation: widget.conversation,
            context: context,
          );
      if (!mounted) return;
      setState(() {
        _messages = [...?_messages, reply];
        _failure = null;
      });
      _scrollToEnd();
    } on TutorUnavailable catch (e) {
      if (mounted) setState(() => _failure = e.reason);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final context = _context;
    if (text.isEmpty || context == null || _sending) return;

    _controller.clear();
    setState(() {
      _sending = true;
      _failure = null;
    });

    try {
      await ref.read(tutorServiceProvider).send(
            conversation: widget.conversation,
            text: text,
            context: context,
          );
      if (!mounted) return;
      // Re-read rather than appending locally: the learner's own turn was
      // stored server-side too, and carries its real id and timestamp.
      final messages =
          await ref.read(tutorServiceProvider).messages(widget.conversation.id);
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToEnd();
    } on TutorUnavailable catch (e) {
      if (!mounted) return;
      // The learner's turn was stored before the call, so reload to keep it.
      final messages =
          await ref.read(tutorServiceProvider).messages(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _failure = e.reason;
      });
    } catch (_) {
      if (mounted) setState(() => _failure = TutorUnavailableReason.backendError);
    } finally {
      if (mounted) setState(() => _sending = false);
      _focus.requestFocus();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: LangoMotion.normal,
        curve: LangoMotion.easing,
      );
    });
  }

  Future<void> _end() async {
    await ref.read(tutorServiceProvider).endConversation(widget.conversation.id);
    ref.invalidate(
        tutorConversationsProvider(widget.conversation.language.code));
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversation.title ?? 'Conversation'),
        actions: [
          if (widget.conversation.isOpen)
            TextButton(
              onPressed: _end,
              child: const Text('End'),
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
                Expanded(
                  child: _loadFailed
                      ? Padding(
                          padding: const EdgeInsets.all(LangoSpace.gutter),
                          child: LangoError(
                            message: "We couldn't open this conversation.",
                            onRetry: () {
                              setState(() => _loadFailed = false);
                              _load();
                            },
                          ),
                        )
                      : messages == null
                          ? const Padding(
                              padding: EdgeInsets.all(LangoSpace.gutter),
                              child: LangoSkeletonList(count: 3),
                            )
                          : ListView(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(
                                LangoSpace.gutter,
                                LangoSpace.md,
                                LangoSpace.gutter,
                                LangoSpace.md,
                              ),
                              children: [
                                for (final m in messages) ...[
                                  _MessageBubble(
                                    message: m,
                                    language: widget.conversation.language,
                                  ),
                                  const Gap.md(),
                                ],
                                if (_sending) const _TypingIndicator(),
                                if (_failure != null)
                                  _FailureNote(reason: _failure!),
                              ],
                            ),
                ),
                if (widget.conversation.isOpen && !_loadFailed)
                  _Composer(
                    controller: _controller,
                    focusNode: _focus,
                    language: widget.conversation.language,
                    enabled: !_sending && _context != null,
                    onSend: _send,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.language});

  final TutorMessage message;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    final fromLearner = message.role == TutorRole.user;

    return Column(
      crossAxisAlignment:
          fromLearner ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment:
              fromLearner ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(LangoSpace.md),
              decoration: BoxDecoration(
                borderRadius: LangoRadius.lgAll,
                color: fromLearner ? null : LangoColors.surfaceMuted,
                gradient:
                    fromLearner ? LangoColors.tints.first.gradient : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: LangoType.native(
                      language.code,
                      size: 19,
                      weight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                  if (message.translation != null) ...[
                    const SizedBox(height: LangoSpace.xxs),
                    Text(message.translation!,
                        style: LangoType.bodyMuted.copyWith(fontSize: 14)),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!fromLearner) ...[
          const SizedBox(height: LangoSpace.xxs),
          AudioButton(
            text: message.content,
            language: language,
            size: AudioButtonSize.small,
          ),
        ],
        if (message.correction != null) ...[
          const Gap.sm(),
          _CorrectionCard(
            correction: message.correction!,
            language: language,
          ),
        ],
      ],
    );
  }
}

/// A correction in the shape US-092 asks for: your sentence, the correction,
/// why, and an example.
class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.correction, required this.language});

  final TutorCorrection correction;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    return LangoCard.tinted(
      tint: LangoColors.tints[2],
      padding: const EdgeInsets.all(LangoSpace.lg),
      semanticLabel: 'Correction. You wrote ${correction.original}. '
          'Better: ${correction.corrected}. ${correction.explanation}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded,
                  size: 18, color: LangoColors.primaryDeep),
              const SizedBox(width: LangoSpace.xxs),
              Text('CORRECTION', style: LangoType.caption),
            ],
          ),
          const Gap.sm(),
          Text('YOU WROTE', style: LangoType.caption),
          Text(
            correction.original,
            style: LangoType.native(
              language.code,
              size: 17,
              weight: FontWeight.w400,
              color: LangoColors.foregroundMuted,
            ),
          ),
          const Gap.xs(),
          Text('BETTER', style: LangoType.caption),
          Text(
            correction.corrected,
            style: LangoType.native(language.code, size: 19),
          ),
          const Gap.sm(),
          Text(correction.explanation, style: LangoType.bodyMuted),
          if (correction.example != null) ...[
            const Gap.sm(),
            Text('ANOTHER EXAMPLE', style: LangoType.caption),
            Text(
              correction.example!,
              style: LangoType.native(
                language.code,
                size: 17,
                weight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: LangoSpace.md),
        child: Semantics(
          label: 'The tutor is replying',
          child: const LangoSkeleton(height: 44, width: 140,
              radius: LangoRadius.lg),
        ),
      ),
    );
  }
}

class _FailureNote extends StatelessWidget {
  const _FailureNote({required this.reason});

  final TutorUnavailableReason reason;

  @override
  Widget build(BuildContext context) {
    final message = switch (reason) {
      TutorUnavailableReason.notConfigured =>
        'No tutor is connected to this app yet, so there is no reply. Your '
            'message has been saved.',
      TutorUnavailableReason.offline =>
        "We couldn't reach the tutor. Your message is saved — try again when "
            'you are back online.',
      TutorUnavailableReason.backendError =>
        "The tutor didn't answer that one. Your message is saved; try sending "
            'it again.',
    };

    return LangoCard(
      padding: const EdgeInsets.all(LangoSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: LangoColors.warning),
          const SizedBox(width: LangoSpace.xs),
          Expanded(
            child: Text(message,
                style: LangoType.bodyMuted.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.language,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TargetLanguage language;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LangoSpace.gutter,
        LangoSpace.xs,
        LangoSpace.gutter,
        LangoSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: LangoType.native(language.code, size: 18,
                  weight: FontWeight.w400),
              decoration: InputDecoration(
                // The English name, not the endonym: a learner who cannot yet
                // read 한국어 still needs to understand the hint.
                hintText: 'Write in ${language.label}',
              ),
            ),
          ),
          const SizedBox(width: LangoSpace.xs),
          IconButton.filled(
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send_rounded),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}
