# Lango — dev guide for Claude Code

Korean + Japanese learning app. **Flutter** frontend, **Supabase** backend
(auth + Postgres with RLS). Product source of truth: `docs/PLAN.md` (vision,
architecture, phases) and `docs/USER_STORIES.md` (acceptance criteria, MVP
scope, priority order). Read them before architectural decisions.

## Stack decisions (already made — don't relitigate)

- Flutter + Riverpod + go_router; Supabase via `supabase_flutter`.
- Config via `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
  (`lib/core/env.dart`). Never commit keys.
- Schema lives in `supabase/migrations/` (versioned SQL), seed content in
  `supabase/seed.sql`. New schema changes = new numbered migration file, never
  edits to applied migrations.
- Audio = on-device TTS (`flutter_tts`) for now; `vocabulary.audio_url` is the
  future hook for recorded audio.

## Invariants — do not break

- `review_events` is append-only (no update/delete RLS policies). All history,
  session summaries, and progress derive from it and `exercise_attempts`.
- `SrsEngine` (`lib/services/srs/srs_engine.dart`) is pure and deterministic:
  no I/O, no clock — callers pass `reviewedAt`. Keep scheduling changes there
  and covered by `test/srs_engine_test.dart`.
- Languages are data (`languages` table, `TargetLanguage` enum is UI-side
  only). No hard-coded per-language branches in schema or services.
- Content queries are paginated; never load whole tables into the client.
- Don't claim accuracy the system can't measure (e.g. pronunciation scoring,
  stroke counts we haven't verified — leave null rather than guess).

## Design system (added by the 2026-09-17 redesign)

- Visual direction is derived from the design reference in `asset/`
  (a Dribbble concept — kept local, gitignored: it is third-party
  copyrighted work and must not be published). `REFERENCE_ANALYSIS.md` records the measured tokens;
  `UI_AUDIT.md` records the pre-redesign state. Do not copy the reference's
  illustrations or its K-pop photos — visual language only.
- **All** colours, spacing, radii, type and motion come from
  `lib/core/design/tokens.dart` + `typography.dart`, surfaced through
  `buildTheme()`. Never hardcode a `Color(0x…)`, a raw `Colors.*`, or a
  spacing/radius literal in a screen.
- **Depth is flat.** The reference has no shadows, no elevation and no card
  borders — measured. Do not add them. Surfaces separate via pastel tint
  (`LangoTint`, a subtle top-to-bottom gradient). The one large gradient
  (`langoHeroGradient`) is reserved for auth/hero surfaces.
- Cards are radius 28, buttons radius 14 — cards are deliberately rounder.
- Native text must use `LangoType.native(languageCode, …)` so Hangul renders in
  NotoSansKR and Kana/Kanji in NotoSansJP. The native word is always the
  largest element; the English gloss is small uppercase and tracked.
- Fonts are bundled and subset (`assets/fonts`, 8.1 MB: full Hangul + Jōyō
  kanji, two weights). Regenerate with fonttools if the content set grows
  beyond Jōyō.
- Light theme only for now. Tokens are structured for a future dark theme;
  do not add one by inverting.
- Every screen needs the three states: `LangoSkeleton*` (never a bare spinner),
  `LangoEmpty`, `LangoError`. `LangoError` must never surface exception text.
- Navigation is a `StatefulShellRoute` (`lib/features/shell/app_shell.dart`):
  Home · Learn · Review · Tutor · Progress. Focused one-task-at-a-time flows
  (flashcards, exercises, session, character practice, listening, speaking)
  live *outside* the shell so nothing competes with the task.
- Tutor and Speaking are designed but **not functional** — no LLM and no STT
  backend. They state this plainly. Do not fake conversations or pronunciation
  scores.

## Layout

- `lib/services/` — all Supabase access; screens never call Supabase directly.
- `lib/features/<area>/` — one folder per screen area.
- Providers are wired in `lib/services/providers.dart`.

## Workflow

- `flutter analyze` and `flutter test` must be clean before finishing a story.
- Work in the order in `docs/USER_STORIES.md` §6; P0 first. Next up (P1):
  AI tutor, speaking, personalization/recommendations, KO↔JA comparison, search.
