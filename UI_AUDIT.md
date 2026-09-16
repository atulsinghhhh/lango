# UI_AUDIT.md — Stage 1

Audit of the existing Lango frontend, performed before any redesign work.
This document is **reference-independent**: it records what exists today, so
that Stage 2 (reference extraction) and Stage 3 (design system) can be mapped
onto it. See REDESIGN.md §38 Stage 1.

Audited at: 2026-09-17. Codebase: `lib/`, 4,268 lines of Dart across 17 screens.

---

## 1. Stack reality vs. REDESIGN.md assumptions

REDESIGN.md is written against a web stack — it references Tailwind config,
`:root` CSS custom properties, `src/styles/tokens.css`, and React-style
component folders (§5, §6, §31, §32).

**This project is Flutter**, not web. Per §32 ("or use the existing project's
equivalent architecture") the spec's intent is translated as:

| REDESIGN.md (web)            | Lango equivalent (Flutter)                          |
| ---------------------------- | --------------------------------------------------- |
| `tokens.css` / `:root` vars  | `lib/core/design/tokens.dart` (const token classes)  |
| Tailwind theme extension     | `ThemeData` + `ThemeExtension` subclasses            |
| `components/` directory      | `lib/widgets/` shared widget library                 |
| CSS media queries            | `LayoutBuilder` + breakpoint constants               |
| `prefers-reduced-motion`     | `MediaQuery.disableAnimations`                       |
| Icon library (one, §33)      | Material Symbols (already the de-facto set)          |

No new dependencies are required for this mapping (§40, Technical).

---

## 2. Routes

All routing is `go_router`, declared centrally in `lib/app.dart`.

| Path                       | Screen                      | Notes                        |
| -------------------------- | --------------------------- | ---------------------------- |
| `/login`                   | `LoginScreen`               |                              |
| `/signup`                  | `SignupScreen`              |                              |
| `/onboarding`              | `OnboardingScreen`          |                              |
| `/`                        | `HomeGate` → Dashboard      | Gates on onboarding complete |
| `/learn/vocabulary`        | `VocabListScreen`           | `?lang=`                     |
| `/learn/flashcards`        | `FlashcardScreen`           | `?lang=`                     |
| `/learn/exercises`         | `ExerciseScreen`            | `?lang=`                     |
| `/learn/grammar`           | `GrammarListScreen`         | `?lang=`                     |
| `/learn/grammar/detail`    | `GrammarDetailScreen`       | + inline practice quiz       |
| `/learn/writing`           | `CharactersScreen`          | `?lang=`                     |
| `/learn/writing/practice`  | `CharacterPracticeScreen`   |                              |
| `/learn/listening`         | `ListeningScreen`           | `?lang=`                     |
| `/review`                  | `ReviewScreen`              | `?lang=` (nullable)          |
| `/session`                 | `SessionScreen`             | `?lang=`                     |
| `/progress`                | `ProgressScreen`            |                              |
| `/settings`                | `SettingsScreen`            |                              |

**Navigation gap vs. §10.** The spec's primary areas are Home, Learn, Review,
Tutor, Progress, Profile. Today there is **no persistent navigation at all** —
no bottom bar, no rail, no sidebar. Every screen is reached by `context.push`
from the dashboard and dismissed with the AppBar back arrow. There is no
`/tutor` route and no Profile area (Settings is the closest analogue).

---

## 3. State management

- Riverpod 3.4.3 throughout; `ProviderScope` at root.
- Services are all wired in `lib/services/providers.dart` — screens never touch
  Supabase directly (enforced by CLAUDE.md, and currently honoured).
- Screen-level data is fetched with `FutureProvider.autoDispose.family`
  declared **inside the screen file** (e.g. `vocabPageProvider`,
  `flashcardQueueProvider`, `reviewQueueProvider`, `dashboardDataProvider`).

This co-location is fine and should be preserved by the redesign — it means
presentation can be rewritten without touching data flow (§37).

---

## 4. API / service surface (must keep working — §37)

| Service           | Methods                                                                     |
| ----------------- | --------------------------------------------------------------------------- |
| `AuthService`     | `signUp`, `signIn`, `signOut`                                                |
| `ProfileService`  | `fetchProfile`, `completeOnboarding`, `updateDailyGoal`                      |
| `ContentService`  | `vocabulary`, `vocabularyByIds`, `vocabularyCount`, `grammarPoints`, `characters` |
| `ReviewService`   | `dueItems`, `dueCount`, `getState`, `ensureTracked`, `recordReview`, `recordExercise`, `statesFor` |
| `SessionService`  | `startSession`, `completeSession`, `activitySince`, `secondsStudiedToday`, `recentSessions` |
| `ProgressService` | `forLanguage`                                                                |
| `TtsService`      | `speak`, `stop`                                                              |
| `SrsEngine`       | pure, deterministic scheduling (no I/O, no clock)                            |

No backend exists for Speaking (no STT) or AI Tutor (no LLM call). See §7.

---

## 5. Current design system — effectively none

`lib/core/theme.dart` is 38 lines and the **entire** visual system:

- One seed colour, `Color(0xFF3D5AFE)`, expanded by `ColorScheme.fromSeed`.
  Every other colour in the app is a Material-derived role.
- Radii are hardcoded per-component inside the theme: buttons `14`, cards `16`,
  inputs `14`. No named scale.
- No spacing scale. Padding literals (`8`, `12`, `16`, `24`, `32`) are written
  inline in every screen.
- No typography scale beyond Material defaults. No CJK font configured — Korean
  and Japanese currently render with the platform fallback font.
- No motion tokens, no breakpoints, no elevation system.
- 14 hardcoded `Colors.*` references leak semantic status colour into widgets
  (`Colors.green` ×6, `Colors.red` ×5, `Colors.orange`, `Colors.blue`) — these
  are the Again/Hard/Good/Easy ratings and correct/incorrect feedback. These are
  exactly the `--success` / `--warning` / `--error` tokens of §6 and must be
  centralised.

**Verdict:** there is no design system to refactor. Stage 3 builds one from
scratch, which is lower risk than retrofitting.

---

## 6. Screen-by-screen state (§26, §27, §28)

| Screen              | Empty state         | Loading state      | Error state             |
| ------------------- | ------------------- | ------------------ | ----------------------- |
| Dashboard           | n/a                 | bare spinner       | generic card + Retry    |
| Vocabulary list     | none                | bare spinner       | none (silent)           |
| Flashcards          | unverified          | bare spinner       | none                    |
| Review              | "Reviews done 🎉"   | bare spinner       | none                    |
| Grammar list/detail | none                | bare spinner       | none                    |
| Writing / Listening | none                | bare spinner       | none                    |
| Progress            | none                | bare spinner       | none                    |

Every loading state is an unstyled `CircularProgressIndicator`. §27 requires
skeletons. Most screens have **no** empty state and **no** error state, so a
failed query renders a blank region — §26 and §28 are unmet across the board.

Responsive behaviour (§29) is untested; all layouts assume a single phone
column. There is no dark mode (§30) — `buildTheme()` returns one light theme
and `MaterialApp.router` sets no `darkTheme`.

---

## 7. MVP completeness (P0)

Per `docs/USER_STORIES.md` §4, the MVP is US-001…005, 010, 011, 020…022,
030…032, 040, 041, 050, 051, 060, 070, 110, 130, 131.

**All P0 stories have a corresponding implemented screen.** Verified on device:
auth → onboarding → dashboard → vocabulary → flashcards → rating → review queue
→ review summary all work against the live Supabase project.

Gaps are **P1**, not MVP — but REDESIGN.md assumes two of them exist:

- **AI Tutor** (§20, §21) — no route, no screen, no LLM backend. §10 lists
  Tutor as a primary navigation area.
- **Speaking** (§19) — no route, no screen, no recording, no STT. §22 and §25
  ask progress to track speaking attempts.

Also absent: personalization/recommendations, KO↔JA comparison, search
(all P1 per CLAUDE.md).

---

## 8. Defects found while driving the app

1. **Dashboard shows a stale due count** — confirmed on device. After completing
   a review session and returning, the dashboard still reads "2 reviews due";
   pull-to-refresh corrects it to 0. `dashboardDataProvider` is never
   invalidated on return because `DashboardScreen` stays mounted underneath the
   pushed `/review` route, so `autoDispose` never fires. Tapping the stale CTA
   opens an empty review queue.

2. **Rating buttons clip their labels** — on a 1080px-wide device the
   Again/Hard/Good/Easy row is too narrow, wrapping to "Agai n" and "Goo d".

3. **Unpaginated content queries** — `ContentService.grammarPoints()` and
   `.characters()` take no offset/limit and select every row for a language.
   `reviewQueueProvider` calls both **per due language** and builds full maps
   just to resolve a handful of due IDs. This violates the CLAUDE.md invariant
   "Content queries are paginated; never load whole tables into the client."
   Fix shape: add `grammarPointsByIds` / `charactersByIds`, mirroring the
   existing `vocabularyByIds`.

4. **Daily-goal progress ignores flashcard study** — "Today: 0 / 5 min" stayed
   at 0 after rating cards from the Vocabulary → Flashcards entry point, because
   only the `/session` flow writes `learning_sessions`. May be intended; flagged
   for a product decision.

(1) and (2) are presentation-layer and will be absorbed by the redesign.
(3) and (4) are logic and are out of scope for a pure visual redesign (§37).

---

## 9. Risk notes for the redesign

- `SrsEngine` purity and the append-only `review_events` invariant must not be
  touched by UI work (CLAUDE.md).
- `flutter_tts` still applies the Kotlin Gradle Plugin; future Flutter versions
  will fail to build on it. Unrelated to the redesign but will surface in CI.
- Adding a persistent nav shell (§10) changes routing from a push-stack to a
  shell route (`StatefulShellRoute`). That is the one structural change the
  redesign genuinely requires, and it touches `lib/app.dart` for every route.
