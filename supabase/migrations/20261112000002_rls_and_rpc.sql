-- 행 수준 보안(RLS)과 앱용 RPC (1주차)

alter table public.profiles      enable row level security;
alter table public.words         enable row level security;
alter table public.puzzles       enable row level security;
alter table public.puzzle_words  enable row level security;
alter table public.attempts      enable row level security;
alter table public.attempt_words enable row level security;
alter table public.wrong_words   enable row level security;

-- ---------------------------------------------------------------------------
-- 정답이 들어 있는 테이블: 앱(anon/authenticated)은 직접 읽지 못한다.
-- 정책을 하나도 두지 않으면 RLS가 모든 행을 막는다. 권한도 같이 회수해 이중으로 막는다.
-- ---------------------------------------------------------------------------
revoke all on public.words, public.puzzle_words from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 퍼즐 목록: 로그인한 사용자는 공개된 퍼즐의 메타 정보만 읽는다.
-- ---------------------------------------------------------------------------
revoke all on public.puzzles from anon, authenticated;
grant select on public.puzzles to authenticated;
create policy "published puzzles are readable"
  on public.puzzles for select to authenticated
  using (published);

-- ---------------------------------------------------------------------------
-- 본인 행만 읽기·쓰기
-- ---------------------------------------------------------------------------
revoke all on public.profiles from anon;
create policy "own profile: select" on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy "own profile: update" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

revoke all on public.attempts, public.attempt_words, public.wrong_words from anon;

create policy "own attempts: select" on public.attempts for select to authenticated
  using (user_id = (select auth.uid()));
create policy "own attempts: insert" on public.attempts for insert to authenticated
  with check (user_id = (select auth.uid()));
-- 점수·상태 갱신은 3주차 정답 확인 RPC(security definer)에서 처리한다. 앱이 직접 바꾸지 못한다.

create policy "own attempt words: select" on public.attempt_words for select to authenticated
  using (exists (select 1 from public.attempts a
                 where a.id = attempt_id and a.user_id = (select auth.uid())));

create policy "own wrong words: select" on public.wrong_words for select to authenticated
  using (user_id = (select auth.uid()));
create policy "own wrong words: update" on public.wrong_words for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own wrong words: delete" on public.wrong_words for delete to authenticated
  using (user_id = (select auth.uid()));
-- 오답 추가는 정답 확인 RPC에서 자동으로 한다 (4주차).

-- ---------------------------------------------------------------------------
-- get_puzzle: 퍼즐 틀과 힌트만 돌려준다. 단어 철자와 원문 예문은 보내지 않는다.
-- 반환 예:
-- { "id": "mid-001", "level": "intermediate", "rows": 13, "cols": 13,
--   "blocks": [[1,1], ...],
--   "clues": [{"id": 17, "no": 1, "dir": "across", "row": 0, "col": 0, "length": 8,
--              "meaning_ko": "일정", "definition_en": "...", "example_blank": "..."}] }
-- ---------------------------------------------------------------------------
create function public.get_puzzle(p_puzzle_id text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p.id, 'level', p.level, 'rows', p.rows, 'cols', p.cols,
    'template', p.template, 'blocks', p.blocks,
    'clues', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', pw.id, 'no', pw.no, 'dir', pw.dir,
               'row', pw.row, 'col', pw.col, 'length', pw.length,
               'meaning_ko', w.meaning_ko, 'definition_en', w.definition_en,
               'example_blank', w.example_blank)
             order by pw.dir, pw.no)
      from public.puzzle_words pw
      join public.words w on w.id = pw.word_id
      where pw.puzzle_id = p.id), '[]'::jsonb))
  from public.puzzles p
  where p.id = p_puzzle_id and p.published and auth.uid() is not null;
$$;

revoke execute on function public.get_puzzle(text) from public, anon;
grant execute on function public.get_puzzle(text) to authenticated;

-- ---------------------------------------------------------------------------
-- delete_my_account: 계정 삭제. auth.users 를 지우면 연결된 모든 행이 cascade로 지워진다.
-- ---------------------------------------------------------------------------
create function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- 함수는 기본으로 public 실행 권한이 있으므로 트리거 함수도 막아 둔다.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
