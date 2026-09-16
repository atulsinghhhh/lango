-- Lango — initial schema.
-- Apply with the Supabase CLI (`supabase db push`) or paste into the
-- SQL editor of your Supabase project.

-- Languages are data, not schema assumptions: adding a language later is an
-- INSERT, not a migration.
create table public.languages (
  code text primary key,
  name text not null
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  onboarding_complete boolean not null default false,
  daily_goal_minutes int not null default 10 check (daily_goal_minutes > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_languages (
  user_id uuid not null references public.profiles (id) on delete cascade,
  language text not null references public.languages (code),
  level text not null check (level in
    ('complete_beginner', 'beginner', 'elementary', 'intermediate', 'advanced')),
  goals text[] not null default '{}',
  created_at timestamptz not null default now(),
  primary key (user_id, language)
);

-- ── Learning content ────────────────────────────────────────────────────────

create table public.vocabulary (
  id uuid primary key default gen_random_uuid(),
  language text not null references public.languages (code),
  word text not null,
  romanization text,
  translation text not null,
  pronunciation text,
  part_of_speech text,
  difficulty int not null default 1 check (difficulty between 1 and 5),
  example_native text,
  example_translation text,
  audio_url text,
  tags text[] not null default '{}',
  created_at timestamptz not null default now(),
  unique (language, word, translation)
);
create index vocabulary_language_difficulty_idx
  on public.vocabulary (language, difficulty);

create table public.grammar_points (
  id uuid primary key default gen_random_uuid(),
  language text not null references public.languages (code),
  name text not null,
  meaning text not null,
  explanation text not null,
  difficulty int not null default 1 check (difficulty between 1 and 5),
  created_at timestamptz not null default now(),
  unique (language, name)
);

create table public.grammar_examples (
  id uuid primary key default gen_random_uuid(),
  grammar_point_id uuid not null
    references public.grammar_points (id) on delete cascade,
  native text not null,
  translation text not null,
  sort_order int not null default 0
);
create index grammar_examples_point_idx
  on public.grammar_examples (grammar_point_id);

create table public.characters (
  id uuid primary key default gen_random_uuid(),
  language text not null references public.languages (code),
  script text not null,
  character text not null,
  romanization text not null,
  pronunciation_hint text,
  example_word text,
  example_translation text,
  stroke_count int,
  sort_order int not null default 0,
  unique (language, script, character)
);
create index characters_language_order_idx
  on public.characters (language, script, sort_order);

-- ── Per-user learning state ─────────────────────────────────────────────────

-- Current SRS scheduling state per item. History lives in review_events.
create table public.user_items (
  user_id uuid not null references public.profiles (id) on delete cascade,
  item_type text not null check (item_type in ('vocabulary', 'grammar', 'character')),
  item_id uuid not null,
  language text not null references public.languages (code),
  status text not null default 'new'
    check (status in ('new', 'learning', 'review', 'mastered')),
  ease double precision not null default 2.5,
  interval_minutes int not null default 0,
  repetitions int not null default 0,
  correct_count int not null default 0,
  incorrect_count int not null default 0,
  last_reviewed timestamptz,
  next_review timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, item_type, item_id)
);
create index user_items_due_idx
  on public.user_items (user_id, next_review);
create index user_items_language_idx
  on public.user_items (user_id, language, item_type);

-- Append-only review history (US-031). No update/delete policies exist,
-- so events are immutable to clients.
create table public.review_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  item_type text not null,
  item_id uuid not null,
  language text not null references public.languages (code),
  result boolean not null,
  rating text not null check (rating in ('again', 'hard', 'good', 'easy')),
  review_type text not null,
  created_at timestamptz not null default now()
);
create index review_events_user_time_idx
  on public.review_events (user_id, created_at desc);

create table public.exercise_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  item_type text not null,
  item_id uuid not null,
  language text not null references public.languages (code),
  exercise_type text not null,
  correct boolean not null,
  answer text,
  created_at timestamptz not null default now()
);
create index exercise_attempts_user_idx
  on public.exercise_attempts (user_id, language, exercise_type, created_at desc);

create table public.learning_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  language text not null references public.languages (code),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  items_studied int not null default 0,
  correct_count int not null default 0,
  incorrect_count int not null default 0,
  duration_seconds int not null default 0,
  skills text[] not null default '{}'
);
create index learning_sessions_user_idx
  on public.learning_sessions (user_id, started_at desc);

-- ── Auto-create a profile row for each new auth user ────────────────────────

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── Row-level security ──────────────────────────────────────────────────────

alter table public.languages enable row level security;
alter table public.profiles enable row level security;
alter table public.user_languages enable row level security;
alter table public.vocabulary enable row level security;
alter table public.grammar_points enable row level security;
alter table public.grammar_examples enable row level security;
alter table public.characters enable row level security;
alter table public.user_items enable row level security;
alter table public.review_events enable row level security;
alter table public.exercise_attempts enable row level security;
alter table public.learning_sessions enable row level security;

-- Shared content: readable by any signed-in user.
create policy "content readable" on public.languages
  for select to authenticated using (true);
create policy "content readable" on public.vocabulary
  for select to authenticated using (true);
create policy "content readable" on public.grammar_points
  for select to authenticated using (true);
create policy "content readable" on public.grammar_examples
  for select to authenticated using (true);
create policy "content readable" on public.characters
  for select to authenticated using (true);

-- User-owned rows: full access to your own data only.
create policy "own profile" on public.profiles
  for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy "own user_languages" on public.user_languages
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own user_items" on public.user_items
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own sessions" on public.learning_sessions
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own attempts insert" on public.exercise_attempts
  for insert to authenticated with check (user_id = auth.uid());
create policy "own attempts read" on public.exercise_attempts
  for select to authenticated using (user_id = auth.uid());

-- Review events: insert + read only. Immutability is enforced by the
-- absence of update/delete policies.
create policy "own events insert" on public.review_events
  for insert to authenticated with check (user_id = auth.uid());
create policy "own events read" on public.review_events
  for select to authenticated using (user_id = auth.uid());
