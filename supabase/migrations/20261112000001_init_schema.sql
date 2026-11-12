-- WordCross 기본 데이터 구조 (1주차)
-- 원칙
--  * 정답(단어 철자)은 앱에서 직접 읽을 수 없다. 퍼즐은 get_puzzle() RPC로 틀과 힌트만 받는다.
--  * 풀이 기록·오답·프로필은 본인 행만 읽기·쓰기.
--  * 단어·퍼즐 데이터는 tools/ 스크립트가 service_role 로 일괄 입력한다.

create type public.level as enum ('beginner', 'intermediate', 'advanced');   -- 초급·중급·고급
create type public.word_type as enum ('learn', 'fill');                      -- 학습 단어(TSL·BSL) / 채움 단어(NGSL)
create type public.direction as enum ('across', 'down');
create type public.attempt_status as enum ('in_progress', 'finished', 'abandoned');

-- ---------------------------------------------------------------------------
-- 프로필 (auth.users 와 1:1)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  nickname        text check (char_length(nickname) between 1 and 20),
  notify_enabled  boolean not null default true,
  notify_time     time    not null default '20:00',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- 가입하면 프로필 행을 자동으로 만든다.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, nickname)
  values (new.id, nullif(left(coalesce(new.raw_user_meta_data ->> 'nickname', ''), 20), ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 단어
-- ---------------------------------------------------------------------------
create table public.words (
  id             bigint generated always as identity primary key,
  word           text not null unique check (word ~ '^[A-Z]{3,15}$'),   -- 대문자 정규화. 정답이므로 앱에 노출 금지
  type           public.word_type not null,
  level          public.level not null,
  pos            text,
  meaning_ko     text,
  definition_en  text,
  example        text,          -- 원문 예문 (정답 포함 → 앱에 노출 금지, 오답 노트에서만 RPC로)
  example_blank  text,          -- 빈칸 처리된 예문 (힌트)
  example_ref    text,          -- 예문 출처 (예: tatoeba:12345)
  source         text not null, -- TSL / BSL / NGSL
  reviewed       boolean not null default false,
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 퍼즐
-- ---------------------------------------------------------------------------
create table public.puzzles (
  id          text primary key,                         -- 예: mid-001
  level       public.level not null,
  rows        smallint not null check (rows between 5 and 21),
  cols        smallint not null check (cols between 5 and 21),
  template    text not null,                            -- 예: uk-13-03
  blocks      jsonb not null default '[]',              -- 검은 칸 [[r,c], ...]
  word_count  smallint not null default 0,
  reviewed    boolean not null default false,
  published   boolean not null default false,           -- 앱에 보이는지
  created_at  timestamptz not null default now()
);
create index puzzles_level_idx on public.puzzles (level) where published;

create table public.puzzle_words (
  id         bigint generated always as identity primary key,
  puzzle_id  text not null references public.puzzles (id) on delete cascade,
  no         smallint not null,
  dir        public.direction not null,
  row        smallint not null,
  col        smallint not null,
  length     smallint not null,
  word_id    bigint not null references public.words (id),
  unique (puzzle_id, no, dir),
  unique (puzzle_id, word_id)          -- 같은 단어는 한 퍼즐에 한 번만
);
create index puzzle_words_word_idx on public.puzzle_words (word_id);

-- ---------------------------------------------------------------------------
-- 풀이 기록
-- ---------------------------------------------------------------------------
create table public.attempts (
  id             bigint generated always as identity primary key,
  user_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  puzzle_id      text not null references public.puzzles (id),
  status         public.attempt_status not null default 'in_progress',
  started_at     timestamptz not null default now(),
  finished_at    timestamptz,
  duration_sec   integer check (duration_sec >= 0),
  score          integer not null default 0,
  correct_count  smallint not null default 0,
  total_count    smallint not null default 0
);
create index attempts_user_idx on public.attempts (user_id, started_at desc);

-- 단어별 풀이 상태 (점수 규칙: 정답 100, 틀린 시도 -10, 글자 힌트 -20, 최소 20, 공개·미완료 0)
create table public.attempt_words (
  attempt_id      bigint not null references public.attempts (id) on delete cascade,
  puzzle_word_id  bigint not null references public.puzzle_words (id) on delete cascade,
  tries           smallint not null default 0 check (tries between 0 and 5),
  letter_hints    smallint not null default 0 check (letter_hints between 0 and 2),
  solved          boolean not null default false,
  revealed        boolean not null default false,
  score           smallint not null default 0,
  primary key (attempt_id, puzzle_word_id)
);

-- ---------------------------------------------------------------------------
-- 오답 노트 / 복습 (Leitner: box 1 → 1일, box 2 → 3일, 그다음 숙달)
-- ---------------------------------------------------------------------------
create table public.wrong_words (
  user_id         uuid not null default auth.uid() references auth.users (id) on delete cascade,
  word_id         bigint not null references public.words (id) on delete cascade,
  wrong_count     integer not null default 1 check (wrong_count >= 0),
  box             smallint not null default 1 check (box in (1, 2)),
  next_review_at  timestamptz not null default now() + interval '1 day',
  mastered        boolean not null default false,
  last_wrong_at   timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  primary key (user_id, word_id)
);
create index wrong_words_review_idx on public.wrong_words (user_id, next_review_at) where not mastered;
