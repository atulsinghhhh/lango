# Lango — Korean + Japanese Learning App

A mobile-first Flutter app for learning Korean and Japanese together, backed by
Supabase (auth + Postgres with row-level security).

Korean and Japanese are first-class throughout: every language appears in its
own script (한국어 / 日本語), native words are always the largest element on
screen, and each script renders in a bundled font so it looks identical on
every device.

## Screenshots

| Home | Learn |
| --- | --- |
| <img src="screenshots/home.png" width="260" alt="Home screen showing the next action to take" /> | <img src="screenshots/learn.png" width="260" alt="Learn hub listing vocabulary, grammar, Hangul, listening and speaking" /> |

| Vocabulary | Profile |
| --- | --- |
| <img src="screenshots/vocabulary.png" width="260" alt="Vocabulary list with Korean words, romanisation and meanings" /> | <img src="screenshots/profile.png" width="260" alt="Profile screen with language, level and daily goal" /> |

## What's implemented

- **Auth** — email/password signup, sign in, sign out (Supabase Auth)
- **Onboarding** — pick Korean/Japanese (or both), per-language level, goals, daily goal
- **Home** — tells you the one thing to do next: due reviews, or today's session
- **Vocabulary** — paginated browser, detail sheets, flashcards, pronunciation
- **Exercises** — multiple choice, reverse translation, type-the-answer, sentence completion
- **Spaced repetition** — deterministic SM-2 variant (`lib/services/srs/srs_engine.dart`),
  append-only `review_events` log, due queue across vocabulary/grammar/characters
- **Grammar** — lessons with real example sentences, plus practice quizzes
- **Writing** — Hangul, Hiragana, Katakana with a trace-over practice canvas
- **Listening** — listen → choose-the-meaning exercises
- **Progress** — study time, items reviewed, accuracy, streak and a skill map,
  all derived from recorded activity
- **Daily session** — guided review → learn → practise → listen loop, persisted

### Designed but not functional

**AI Tutor** and **Speaking** ship as designed, navigable screens that state
plainly that they are not live. There is no language-model backend and no
speech recognition wired up, and the app deliberately does not fake a
conversation or invent a pronunciation score. Connecting them is the next
milestone.

## Setup

### 1. Supabase

1. Create a project at [supabase.com](https://supabase.com).
2. In the SQL editor, run:
   - `supabase/migrations/0001_initial_schema.sql`
   - `supabase/seed.sql`
   (or use the CLI: `supabase link && supabase db push`, then run the seed)
3. For fastest local dev, disable **email confirmations** under
   Authentication → Providers → Email. The app handles both modes.
4. Copy the project URL and the anon/publishable key from Project Settings → API.

### 2. Run the app

```sh
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-PUBLISHABLE-KEY
```

`lib/core/env.dart` carries a default project URL and publishable key so the
app runs with a bare `flutter run`. A publishable/anon key is meant to be
shipped in a client — access is enforced by row-level security, not by hiding
it — but override both values with `--dart-define` to point at your own
project. **Never** put a `service_role` key in this file.

### 3. Tests

```sh
flutter analyze
flutter test
```

Covers the SRS scheduler (determinism, intervals, mastery, failure resets) and
the exercise generator (reproducibility, answer checking).

## Architecture

```
lib/
├── core/
│   ├── design/    design tokens — colour, type, spacing, radius, motion
│   └── theme.dart ThemeData built from those tokens
├── models/        language, content, profile, user_item (SRS state)
├── services/      auth, profile, content, review, session, progress, TTS
│   ├── srs/       pure scheduling engine — no I/O, fully tested
│   └── exercises/ pure exercise generator — fully tested
├── widgets/       shared UI — cards, states, native text, audio, ratings
└── features/      one folder per screen area
    └── shell/     persistent navigation (Home · Learn · Review · Tutor · Progress)
```

### Design system

Every colour, space, radius and text style comes from
`lib/core/design/tokens.dart` and `typography.dart` — no screen hardcodes a
hex value or a magic number. Notable rules:

- **Flat depth.** No shadows, no elevation, no card borders. Surfaces separate
  by pastel tint (a subtle top-to-bottom gradient), not by edges.
- **Cards are rounder than buttons** — 28 vs 14 radius.
- **Native-first hierarchy.** The Korean or Japanese word is the largest thing
  on its surface; the English gloss sits beneath it, small, uppercase, tracked.
- **Bundled CJK fonts.** Nunito for Latin, Noto Sans KR for Hangul, Noto Sans
  JP for Kana/Kanji — subset and instantiated to static weights
  (`assets/fonts`, ~8 MB). Without these, Korean and Japanese fall back to
  different platform fonts on Android and iOS.
- **Light theme only.** The tokens are structured so a dark theme can be added
  later without touching a single widget.

`UI_AUDIT.md` and `REFERENCE_ANALYSIS.md` document the pre-redesign state and
the measured design tokens.

### Key invariants

- `review_events` is append-only; RLS has no update or delete policy, so
  history can't be silently rewritten. Progress is derived from it.
- Scheduling is pure and isolated (`SrsEngine`) so the algorithm can evolve
  (FSRS etc.) without touching UI or persistence.
- Languages are rows in a `languages` table — a third language is data, not a
  migration.
- Screens never call Supabase directly; all access goes through `lib/services/`.
- Nothing claims accuracy the system can't measure. Where a metric isn't
  available it renders as "—", not as zero.
- Audio is on-device TTS for now; `vocabulary.audio_url` exists so recorded
  native audio can replace it without code changes.

## Roadmap

AI tutor (needs a model backend), speaking practice (needs speech recognition),
personalization/recommendations, KO↔JA comparison, search, and Kanji beyond the
bundled Jōyō set.

## Licence

Bundled fonts are SIL Open Font License 1.1 — see
[`assets/fonts/LICENSE.md`](assets/fonts/LICENSE.md) for attribution and the
full licence text.
