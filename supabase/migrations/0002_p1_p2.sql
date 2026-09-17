-- Lango — P1 + P2 schema.
-- Adds: search indexes (US-023/140), kanji-capable character rows (US-061),
-- tutor conversations (US-090/091/092), speaking attempts (US-080/081), and
-- cross-language concept comparison (US-120/121).
--
-- Apply after 0001_initial_schema.sql. Never edit an applied migration.

-- ── Search (US-023, US-140) ─────────────────────────────────────────────────
-- Trigram indexes so `ilike '%q%'` stays index-backed as the catalog grows.
-- One index per searchable column, because the client ORs across columns and
-- a concatenated expression index would not be usable for those predicates.
create extension if not exists pg_trgm;

create index vocabulary_word_trgm_idx
  on public.vocabulary using gin (word gin_trgm_ops);
create index vocabulary_romanization_trgm_idx
  on public.vocabulary using gin (romanization gin_trgm_ops);
create index vocabulary_translation_trgm_idx
  on public.vocabulary using gin (translation gin_trgm_ops);

create index grammar_points_name_trgm_idx
  on public.grammar_points using gin (name gin_trgm_ops);
create index grammar_points_meaning_trgm_idx
  on public.grammar_points using gin (meaning gin_trgm_ops);

create index characters_character_trgm_idx
  on public.characters using gin (character gin_trgm_ops);
create index characters_romanization_trgm_idx
  on public.characters using gin (romanization gin_trgm_ops);

-- ── Kanji (US-061) ──────────────────────────────────────────────────────────
-- Kanji are characters, not a new entity: they are rows in `characters` with
-- script = 'kanji'. These three columns are language-neutral — Hangul and Kana
-- simply leave them empty — so nothing here hard-codes Japanese.
alter table public.characters
  -- English meanings. Hangul/Kana rows keep the empty default.
  add column meanings text[] not null default '{}',
  -- Reading groups keyed by reading type, e.g. {"on": ["ニチ"], "kun": ["ひ"]}.
  -- A map rather than two columns so another language can add its own groups.
  add column readings jsonb not null default '{}'::jsonb,
  -- Curriculum level this character belongs to ("JLPT N5", "TOPIK I", …).
  add column level_label text;

create index characters_level_idx
  on public.characters (language, script, level_label);

-- Example vocabulary for a character (US-061 "Vocabulary"). A join table
-- rather than a text column so examples stay real vocabulary rows with audio,
-- SRS state and examples of their own.
create table public.character_vocabulary (
  character_id uuid not null
    references public.characters (id) on delete cascade,
  vocabulary_id uuid not null
    references public.vocabulary (id) on delete cascade,
  sort_order int not null default 0,
  primary key (character_id, vocabulary_id)
);
create index character_vocabulary_character_idx
  on public.character_vocabulary (character_id, sort_order);

-- ── AI tutor (US-090, US-091, US-092) ───────────────────────────────────────
create table public.tutor_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  language text not null references public.languages (code),
  -- Level the conversation was started at, so history stays interpretable
  -- after the learner's level changes (US-091).
  level text not null check (level in
    ('complete_beginner', 'beginner', 'elementary', 'intermediate', 'advanced')),
  scenario text,
  title text,
  started_at timestamptz not null default now(),
  ended_at timestamptz
);
create index tutor_conversations_user_idx
  on public.tutor_conversations (user_id, started_at desc);

create table public.tutor_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.tutor_conversations (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null check (role in ('user', 'tutor')),
  content text not null,
  translation text,
  -- Correction of the learner's previous turn (US-092), shaped
  -- {original, corrected, explanation, example}. Null when nothing meaningful
  -- was wrong — an empty correction is never invented.
  correction jsonb,
  created_at timestamptz not null default now()
);
create index tutor_messages_conversation_idx
  on public.tutor_messages (conversation_id, created_at);

-- ── Speaking (US-080, US-081) ───────────────────────────────────────────────
-- One row per recorded attempt. Note what this table deliberately does NOT
-- store: a pronunciation score. `recognition_confidence` is the speech
-- recogniser's confidence in its own transcript, which is not a measure of how
-- well the learner pronounced anything (US-081).
create table public.speaking_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  language text not null references public.languages (code),
  item_type text,
  item_id uuid,
  target_text text not null,
  recognized_text text,
  recognition_confidence double precision
    check (recognition_confidence is null
           or recognition_confidence between 0 and 1),
  -- Share of target words the transcript matched, 0–1.
  match_ratio double precision
    check (match_ratio is null or match_ratio between 0 and 1),
  missing_words text[] not null default '{}',
  extra_words text[] not null default '{}',
  created_at timestamptz not null default now()
);
create index speaking_attempts_user_idx
  on public.speaking_attempts (user_id, language, created_at desc);

-- ── Korean ↔ Japanese comparison (US-120, US-121) ───────────────────────────
-- A concept is language-neutral; each language contributes one entry. Adding a
-- third language is an INSERT, not a migration.
create table public.concepts (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('expression', 'grammar', 'vocabulary')),
  english text not null,
  -- The difference that actually matters, and the similarity that is real.
  key_difference text,
  similarity text,
  -- US-121: "must not imply that two grammar structures are equivalent when
  -- they only appear similar". Every concept states how close the match is.
  equivalence text not null default 'partial'
    check (equivalence in ('close', 'partial', 'false_friend')),
  sort_order int not null default 0,
  unique (kind, english)
);
create index concepts_kind_idx on public.concepts (kind, sort_order);

create table public.concept_entries (
  id uuid primary key default gen_random_uuid(),
  concept_id uuid not null references public.concepts (id) on delete cascade,
  language text not null references public.languages (code),
  structure text not null,
  example_native text not null,
  example_translation text not null,
  literal_gloss text,
  note text,
  unique (concept_id, language)
);
create index concept_entries_concept_idx
  on public.concept_entries (concept_id, language);

-- ── Row-level security ──────────────────────────────────────────────────────

alter table public.character_vocabulary enable row level security;
alter table public.concepts enable row level security;
alter table public.concept_entries enable row level security;
alter table public.tutor_conversations enable row level security;
alter table public.tutor_messages enable row level security;
alter table public.speaking_attempts enable row level security;

-- Shared content: readable by any signed-in user.
create policy "content readable" on public.character_vocabulary
  for select to authenticated using (true);
create policy "content readable" on public.concepts
  for select to authenticated using (true);
create policy "content readable" on public.concept_entries
  for select to authenticated using (true);

-- Conversations are owned rows: the learner may rename or end one.
create policy "own conversations" on public.tutor_conversations
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Messages and speaking attempts are history. Like review_events they get
-- insert + select only, so the record of what was actually said cannot be
-- rewritten from the client.
create policy "own tutor messages insert" on public.tutor_messages
  for insert to authenticated with check (user_id = auth.uid());
create policy "own tutor messages read" on public.tutor_messages
  for select to authenticated using (user_id = auth.uid());

create policy "own speaking insert" on public.speaking_attempts
  for insert to authenticated with check (user_id = auth.uid());
create policy "own speaking read" on public.speaking_attempts
  for select to authenticated using (user_id = auth.uid());
