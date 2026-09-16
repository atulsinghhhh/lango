import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/language.dart';
import '../services/providers.dart';

/// Audio affordance (REDESIGN.md §14, §18).
///
/// The reference gives pronunciation a prominent, circular, tinted control
/// rather than a small trailing icon. Three sizes cover every use.
enum AudioButtonSize { small, medium, hero }

class AudioButton extends ConsumerStatefulWidget {
  const AudioButton({
    super.key,
    required this.text,
    required this.language,
    this.size = AudioButtonSize.medium,
  });

  final String text;
  final TargetLanguage language;
  final AudioButtonSize size;

  @override
  ConsumerState<AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends ConsumerState<AudioButton> {
  bool _speaking = false;

  double get _diameter => switch (widget.size) {
        AudioButtonSize.small => 40,
        AudioButtonSize.medium => 52,
        AudioButtonSize.hero => 88,
      };

  double get _icon => switch (widget.size) {
        AudioButtonSize.small => 20,
        AudioButtonSize.medium => 24,
        AudioButtonSize.hero => 40,
      };

  Future<void> _play() async {
    if (_speaking) return;
    setState(() => _speaking = true);
    try {
      await ref.read(ttsServiceProvider).speak(widget.text, widget.language);
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      label: 'Play pronunciation',
      child: Tooltip(
        message: 'Play pronunciation',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: _play,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: reduceMotion ? Duration.zero : LangoMotion.fast,
              width: _diameter,
              height: _diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _speaking
                    ? LangoColors.primary
                    : LangoPalette.tintPink,
              ),
              child: Icon(
                Icons.volume_up_rounded,
                size: _icon,
                color: _speaking
                    ? LangoColors.primaryForeground
                    : LangoColors.primaryDeep,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
