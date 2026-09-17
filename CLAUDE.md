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
- Speech synthesis = NVIDIA MagpieTTS Multilingual 357M in `services/tts/`
  (FastAPI + NeMo, GPU). One model covers en/ko/ja. `flutter_tts` remains only
  as the offline fallback voice. `vocabulary.audio_url` is still the hook for
  recorded native audio.
- Speech recognition = on-device (`speech_to_text`), no server and no key.
- The LLM call lives in the `tutor` Supabase Edge Function
  (`supabase/functions/tutor/index.ts`), currently Groq
  (`openai/gpt-oss-120b`) with a strict `json_schema` response format, so the
  reply shape is enforced rather than parsed from prose.
- **No model API key or service-role key ever reaches the Flutter client.**
  Both backends authenticate the learner with their existing Supabase access
  token. The only new client-side config is the public `TTS_API_BASE_URL`.

## Invariants — do not break

- `review_events` is append-only (no update/delete RLS policies). All history,
  session summaries, and progress derive from it and `exercise_attempts`.
- `SrsEngine` (`lib/services/srs/srs_engine.dart`) is pure and deterministic:
  no I/O, no clock — callers pass `reviewedAt`. Keep scheduling changes there
  and covered by `test/srs_engine_test.dart`.
- Languages are data (`languages` table, `TargetLanguage` enum is UI-side
  only). No hard-coded per-language branches in schema or services. Kanji are
  rows in `characters` with `script = 'kanji'` and the generic `meanings`,
  `readings` and `level_label` columns — not a Japanese-only table. Comparison
  concepts (`concepts` + `concept_entries`) take one entry per language, so a
  third language is an INSERT.
- Content queries are paginated; never load whole tables into the client.
- Don't claim accuracy the system can't measure. Specifically:
  - **Speaking is speech recognition, not pronunciation assessment.** The
    comparison in `lib/services/speech/speech_comparison.dart` grades a
    transcript against a target. `speaking_attempts.recognition_confidence` is
    the recogniser's confidence in its own transcript. Never render either as
    a pronunciation score, and never store one.
  - Stroke counts and stroke order: leave null rather than guess.
  - A weak area needs `WeakArea.minimumAttempts` graded attempts before it is
    reported — two wrong answers is noise, not a pattern.
  - `TutorCorrection` is only stored when it is usable; the tutor is instructed
    not to invent a correction for a correct turn.
- The pure engines stay pure and tested: `SrsEngine`, `ExerciseGenerator`,
  `SpeechComparison`/`DictationChecker`, `RecommendationEngine`. No I/O, no
  clock, no platform calls — callers pass what they need in.
- `tutor_messages` and `speaking_attempts` are insert+select only, like
  `review_events`. What was said is not rewritable from the client.
- TTS caching is keyed on everything that can change the audio (model version,
  language, voice, generation flags, format, NFC-normalised text). Bump
  `TTS_MODEL_VERSION` whenever the model or a generation default changes, or
  learners keep hearing audio made with the old settings.
- Changing a learning preference never deletes learning history (US-150). Use
  the granular `ProfileService` methods; `completeOnboarding` is for onboarding
  only.

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
- Tutor and Speaking are functional. Tutor degrades honestly when the Edge
  Function is not deployed (`TutorUnavailableReason.notConfigured`), and
  Speaking states in-screen that it does recognition rather than pronunciation
  scoring. Keep both honest states — do not replace them with optimistic copy.
- `ComparisonText`/`ComparisonSummary` (`lib/widgets/comparison_text.dart`) are
  shared by dictation and speaking. Do not fork them per screen.

## Layout

- `lib/services/` — all Supabase access; screens never call Supabase directly.
- `lib/features/<area>/` — one folder per screen area.
- Providers are wired in `lib/services/providers.dart`.
- `services/tts/` — the GPU inference service. Its own Python project, its own
  tests (`pytest`), deployed separately. Flutter talks to it only through
  `lib/services/tts/tts_api_client.dart`; nothing else in the app knows a model
  exists.

## Workflow

- `flutter analyze` and `flutter test` must be clean before finishing a story.
  If you touched `services/tts/`, `pytest` there must be clean too.
- Work in the order in `docs/USER_STORIES.md` §6. P0, P1 and P2 are all
  implemented. Remaining known gaps, none of which are user stories: recorded
  native audio in place of TTS, kanji beyond the seeded JLPT N5 set,
  handwriting recognition on the writing canvas, and UI localisation.
- Schema changes go in a new numbered migration. `0002_p1_p2.sql` is the
  P1/P2 migration; seed content is appended to `supabase/seed.sql`.
