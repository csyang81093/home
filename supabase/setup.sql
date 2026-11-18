-- Rimba Games: world high-score board
-- Run this once in your Supabase project: Dashboard → SQL Editor → New query → paste → Run.
-- Safe to re-run.

-- 1. Scores table ---------------------------------------------------------------
create table if not exists public.scores (
  id          bigint generated always as identity primary key,
  game        text        not null,
  name        text        not null check (char_length(name) between 1 and 16 and name !~ '[<>]'),
  country     text        not null check (country ~ '^[A-Z]{2}$'),
  score       numeric(7,1) not null check (score >= 0),
  created_at  timestamptz not null default now()
);
-- Game list + score limits are (re)applied every run, so re-running this file
-- upgrades an existing board when a new game is added.
alter table public.scores drop constraint if exists scores_game_check;
alter table public.scores add constraint scores_game_check check (game in ('fling', 'skate', 'plunge', 'hornbill'));
alter table public.scores drop constraint if exists plausible_score;
alter table public.scores add constraint plausible_score check (   -- reject obviously impossible scores
  (game = 'plunge'   and score <= 90) or      -- 3 dives x 3 judges x 10
  (game = 'fling'    and score <= 20000) or
  (game = 'skate'    and score <= 20000) or
  (game = 'hornbill' and score <= 5000 and score = round(score))
);
create index if not exists scores_game_score_idx on public.scores (game, score desc);

-- 2. Row Level Security: the public (anon key) may READ and ADD scores, never edit or delete
alter table public.scores enable row level security;
drop policy if exists "public can read scores" on public.scores;
create policy "public can read scores" on public.scores for select to anon, authenticated using (true);
drop policy if exists "public can add scores" on public.scores;
create policy "public can add scores" on public.scores for insert to anon, authenticated with check (true);
grant select, insert on public.scores to anon, authenticated;
revoke update, delete, truncate on public.scores from anon, authenticated;

-- 3. Name filter + flood control ---------------------------------------------------
-- Banned words live in a table nobody outside the dashboard can read. Add your own:
--   insert into public.banned_words(word) values ('someword');
create table if not exists public.banned_words (word text primary key check (word = lower(word)));
alter table public.banned_words enable row level security;   -- no policies = invisible to the public
revoke all on public.banned_words from anon, authenticated;
insert into public.banned_words(word) values
  ('fuck'), ('shit'), ('cunt'), ('bitch'), ('asshole'), ('bastard'), ('whore'), ('slut'),
  ('nazi'), ('hitler'), ('pukimak'), ('kimak'), ('lancau'), ('pantat')
on conflict do nothing;

create or replace function public.check_score_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.name := btrim(regexp_replace(new.name, '\s+', ' ', 'g'));
  new.created_at := now();   -- clients can't backdate
  if exists (
    select 1 from public.banned_words b
    where position(b.word in lower(regexp_replace(new.name, '[^[:alnum:]]', '', 'g'))) > 0
  ) then
    raise exception 'name not allowed';
  end if;
  -- at most 5 submissions per player name per minute
  if (select count(*) from public.scores s
      where lower(s.name) = lower(new.name) and s.created_at > now() - interval '1 minute') >= 5 then
    raise exception 'too many submissions';
  end if;
  return new;
end $$;

drop trigger if exists scores_check on public.scores;
create trigger scores_check before insert on public.scores
  for each row execute function public.check_score_insert();

-- 4. Top-N board: each player's best score only (same name + country = same player)
create or replace function public.top_scores(g text, n int default 20)
returns table (name text, country text, score numeric, created_at timestamptz)
language sql stable set search_path = public as $$
  select b.name, b.country, b.score, b.created_at
  from (
    select distinct on (lower(s.name), s.country) s.name, s.country, s.score, s.created_at
    from public.scores s
    where s.game = g
    order by lower(s.name), s.country, s.score desc, s.created_at asc
  ) b
  order by b.score desc, b.created_at asc
  limit least(greatest(n, 1), 100);
$$;
grant execute on function public.top_scores(text, int) to anon, authenticated;

-- Moderation tips (run in the SQL editor):
--   delete from public.scores where name ilike '%badname%';
--   delete from public.scores where game = 'fling' and score > 5000;   -- wipe suspicious scores
