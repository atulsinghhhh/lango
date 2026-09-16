import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

/// Application shell (REDESIGN.md §10, §31).
///
/// The reference uses a flat bottom tab bar — icon above a very small
/// uppercase tracked label, no pill indicator, no elevation, sitting directly
/// on the white surface. That philosophy is kept; the tabs are Lango's own
/// product areas rather than the reference's.
///
/// On wide viewports the same destinations become a [NavigationRail] so the
/// layout adapts without inventing an unrelated desktop UI (§10, §29).
///
/// Focused study flows (flashcards, review, a daily session, character
/// practice) deliberately live *outside* this shell: they are one-task-at-a-
/// time screens and must not compete with navigation (§13).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const destinations = <_Dest>[
    _Dest('Home', Icons.home_rounded, Icons.home_outlined),
    _Dest('Learn', Icons.school_rounded, Icons.school_outlined),
    _Dest('Review', Icons.replay_rounded, Icons.replay_outlined),
    _Dest('Tutor', Icons.forum_rounded, Icons.forum_outlined),
    _Dest('Progress', Icons.insights_rounded, Icons.insights_outlined),
  ];

  void _go(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = LangoBreak.isExpanded(width);
    final current = navigationShell.currentIndex;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: current,
              onDestinationSelected: _go,
              backgroundColor: LangoColors.background,
              indicatorColor: Colors.transparent,
              labelType: NavigationRailLabelType.all,
              selectedLabelTextStyle:
                  LangoType.navLabel.copyWith(color: LangoColors.primary),
              unselectedLabelTextStyle:
                  LangoType.navLabel.copyWith(color: LangoColors.foregroundMuted),
              selectedIconTheme:
                  const IconThemeData(color: LangoColors.primary, size: 24),
              unselectedIconTheme: const IconThemeData(
                  color: LangoColors.foregroundMuted, size: 24),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.outlined),
                    selectedIcon: Icon(d.filled),
                    label: Text(d.label.toUpperCase()),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        onDestinationSelected: _go,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.outlined),
              selectedIcon: Icon(d.filled),
              label: d.label.toUpperCase(),
              tooltip: d.label,
            ),
        ],
      ),
    );
  }
}

class _Dest {
  const _Dest(this.label, this.filled, this.outlined);
  final String label;
  final IconData filled;
  final IconData outlined;
}
