-- 3주차: 정답 확인과 점수 규칙 (기획서 4장)
--
--   start_attempt(p_puzzle_id)                         풀이 시작 또는 이어 풀기
--   check_word(p_attempt_id, p_clue_id, p_guess, p_request_id)   단어 하나 채점 ("확인")
--   finish_attempt(p_attempt_id)                       퍼즐 끝내기 ("제출"), 결과
--
-- 점수: 맞힌 단어 = max(20, 100 - 10 × 틀린 확인 횟수 - 20 × 글자 힌트 횟수)
--       정답 공개·못 푼 단어 = 0. 퍼즐 점수 = 단어 점수의 합.
-- 시도: 단어당 확인 최대 5회. 바로 앞과 같은 오답은 다시 세지 않는다.
-- 예외: 진행 중 기록은 퍼즐당 하나, 시작 후 24시간이 지나면 포기(abandoned) 처리.
--       같은 p_request_id 로 다시 보내면 한 번만 처리하고 처음 결과를 돌려준다.
-- 글자 힌트·정답 공개 RPC 와 오답 노트 자동 기록은 4주차.

-- ---------------------------------------------------------------------------
-- 앱이 풀이 기록을 직접 만들지 못하게 한다 (점수를 마음대로 넣을 수 있었음).
-- 기록은 start_attempt 로만 만든다.
-- ---------------------------------------------------------------------------
drop policy if exists "own attempts: insert" on public.attempts;
revoke insert, update, delete on public.attempts, public.attempt_words from authenticated;

-- 진행 중인 기록은 사용자·퍼즐마다 하나
create unique index attempts_one_in_progress
  on public.attempts (user_id, puzzle_id) where status = 'in_progress';

-- 같은 오답 반복·같은 요청 재전송을 가려내기 위한 칸
alter table public.attempt_words
  add column last_guess text,
  add column last_request_id uuid,
  add column last_result jsonb;

-- ---------------------------------------------------------------------------
-- 내부 도우미
-- ---------------------------------------------------------------------------
create function public.word_score(p_tries smallint, p_letter_hints smallint)
returns smallint
language sql
immutable
set search_path = ''
as $$
  -- p_tries = 맞힌 확인까지 포함한 확인 횟수 → 틀린 횟수 = p_tries - 1
  select greatest(20, 100 - 10 * greatest(p_tries - 1, 0) - 20 * p_letter_hints)::smallint;
$$;

-- 24시간이 지난 진행 중 기록을 포기로 바꾼다.
create function public.expire_stale_attempts(p_user uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.attempts
     set status = 'abandoned', finished_at = now()
   where user_id = p_user
     and status = 'in_progress'
     and started_at < now() - interval '24 hours';
$$;

-- 기록 하나의 단어별 상태 (정답 철자는 맞혔거나 공개된 단어만)
create function public.attempt_words_json(p_attempt_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'clue_id', pw.id, 'no', pw.no, 'dir', pw.dir,
           'solved', aw.solved, 'revealed', aw.revealed,
           'tries', aw.tries, 'tries_left', 5 - aw.tries,
           'letter_hints', aw.letter_hints, 'score', aw.score,
           'answer', case when aw.solved or aw.revealed then w.word end)
         order by pw.dir, pw.no), '[]'::jsonb)
  from public.attempt_words aw
  join public.puzzle_words pw on pw.id = aw.puzzle_word_id
  join public.words w on w.id = pw.word_id
  where aw.attempt_id = p_attempt_id;
$$;

-- ---------------------------------------------------------------------------
-- start_attempt: 풀이 시작. 같은 퍼즐의 진행 중 기록이 있으면 그것을 돌려준다(이어 풀기).
-- ---------------------------------------------------------------------------
create function public.start_attempt(p_puzzle_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_attempt public.attempts;
  v_resumed boolean := false;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;
  perform public.expire_stale_attempts(v_user);

  select * into v_attempt from public.attempts
   where user_id = v_user and puzzle_id = p_puzzle_id and status = 'in_progress';

  if found then
    v_resumed := true;
  else
    if not exists (select 1 from public.puzzles where id = p_puzzle_id and published) then
      raise exception 'puzzle_not_found';
    end if;
    insert into public.attempts (user_id, puzzle_id, total_count)
    values (v_user, p_puzzle_id,
            (select count(*) from public.puzzle_words where puzzle_id = p_puzzle_id))
    returning * into v_attempt;
    insert into public.attempt_words (attempt_id, puzzle_word_id)
    select v_attempt.id, pw.id from public.puzzle_words pw where pw.puzzle_id = p_puzzle_id;
  end if;

  return jsonb_build_object(
    'attempt_id', v_attempt.id, 'puzzle_id', v_attempt.puzzle_id,
    'started_at', v_attempt.started_at, 'resumed', v_resumed,
    'words', public.attempt_words_json(v_attempt.id));
end;
$$;

-- ---------------------------------------------------------------------------
-- check_word: 단어 하나 채점 ("확인" 버튼)
-- 반환: {correct, solved, revealed, tries, tries_left, score, answer?, counted}
--   counted = 이번 확인이 시도 횟수에 들어갔는지 (같은 오답 반복·이미 맞힘이면 false)
-- 오류(예외 메시지): not_authenticated, attempt_not_found, attempt_closed,
--   clue_not_in_puzzle, invalid_guess, no_tries_left
-- ---------------------------------------------------------------------------
create function public.check_word(p_attempt_id bigint, p_clue_id bigint, p_guess text,
                                  p_request_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_attempt public.attempts;
  v_aw public.attempt_words;
  v_word text;
  v_guess text := upper(coalesce(p_guess, ''));
  v_correct boolean;
  v_result jsonb;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;
  perform public.expire_stale_attempts(v_user);

  select * into v_attempt from public.attempts
   where id = p_attempt_id and user_id = v_user for update;
  if not found then
    raise exception 'attempt_not_found';
  end if;
  if v_attempt.status <> 'in_progress' then
    raise exception 'attempt_closed';
  end if;

  select aw.* into v_aw from public.attempt_words aw
    join public.puzzle_words pw on pw.id = aw.puzzle_word_id
   where aw.attempt_id = p_attempt_id and aw.puzzle_word_id = p_clue_id
     and pw.puzzle_id = v_attempt.puzzle_id
   for update of aw;
  if not found then
    raise exception 'clue_not_in_puzzle';
  end if;

  -- 같은 요청을 다시 보냄 (응답을 못 받고 재전송) → 처음 결과 그대로
  if p_request_id is not null and v_aw.last_request_id = p_request_id then
    return v_aw.last_result;
  end if;

  select w.word into v_word from public.puzzle_words pw
    join public.words w on w.id = pw.word_id where pw.id = p_clue_id;

  -- 이미 맞혔거나 공개한 단어 → 세지 않고 상태만
  if v_aw.solved or v_aw.revealed then
    return jsonb_build_object('correct', v_aw.solved, 'solved', v_aw.solved, 'revealed', v_aw.revealed,
                              'tries', v_aw.tries, 'tries_left', 5 - v_aw.tries, 'score', v_aw.score,
                              'answer', v_word, 'counted', false);
  end if;

  -- 빈칸·글자 수 다름·알파벳 아님 → 시도로 세지 않음
  if v_guess !~ '^[A-Z]+$' or length(v_guess) <> length(v_word) then
    raise exception 'invalid_guess';
  end if;

  v_correct := v_guess = v_word;

  -- 바로 앞과 같은 오답 → 세지 않음
  if not v_correct and v_aw.last_guess = v_guess then
    return jsonb_build_object('correct', false, 'solved', false, 'revealed', false,
                              'tries', v_aw.tries, 'tries_left', 5 - v_aw.tries, 'score', 0,
                              'counted', false);
  end if;

  if v_aw.tries >= 5 then
    raise exception 'no_tries_left';
  end if;

  v_aw.tries := v_aw.tries + 1;
  if v_correct then
    v_aw.solved := true;
    v_aw.score := public.word_score(v_aw.tries, v_aw.letter_hints);
    update public.attempts set correct_count = correct_count + 1 where id = p_attempt_id;
  end if;

  v_result := jsonb_build_object(
    'correct', v_correct, 'solved', v_aw.solved, 'revealed', false,
    'tries', v_aw.tries, 'tries_left', 5 - v_aw.tries, 'score', v_aw.score, 'counted', true)
    || case when v_correct then jsonb_build_object('answer', v_word) else '{}'::jsonb end;

  update public.attempt_words
     set tries = v_aw.tries, solved = v_aw.solved, score = v_aw.score,
         last_guess = v_guess, last_request_id = p_request_id, last_result = v_result
   where attempt_id = p_attempt_id and puzzle_word_id = p_clue_id;

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- finish_attempt: 퍼즐 끝내기 ("제출"). 빈칸이 있어도 된다 (못 푼 단어 0점).
-- 이미 끝낸 기록에 다시 부르면 같은 결과를 돌려준다.
-- 반환: {attempt_id, puzzle_id, score, max_score, correct, total, accuracy, duration_sec, words[]}
--   words[] 에는 모든 단어의 정답 철자·뜻이 들어간다 (결과 화면·오답 확인용)
-- ---------------------------------------------------------------------------
create function public.finish_attempt(p_attempt_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_attempt public.attempts;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  select * into v_attempt from public.attempts
   where id = p_attempt_id and user_id = v_user for update;
  if not found then
    raise exception 'attempt_not_found';
  end if;
  if v_attempt.status = 'abandoned' then
    raise exception 'attempt_closed';
  end if;

  if v_attempt.status = 'in_progress' then
    update public.attempts a
       set status = 'finished',
           finished_at = now(),
           duration_sec = greatest(0, extract(epoch from now() - a.started_at))::integer,
           score = (select coalesce(sum(score), 0) from public.attempt_words where attempt_id = a.id),
           correct_count = (select count(*) from public.attempt_words
                             where attempt_id = a.id and solved and not revealed)
     where a.id = p_attempt_id
     returning * into v_attempt;
  end if;

  return jsonb_build_object(
    'attempt_id', v_attempt.id, 'puzzle_id', v_attempt.puzzle_id,
    'score', v_attempt.score, 'max_score', v_attempt.total_count * 100,
    'correct', v_attempt.correct_count, 'total', v_attempt.total_count,
    'accuracy', case when v_attempt.total_count > 0
                     then round(v_attempt.correct_count::numeric / v_attempt.total_count, 3) else 0 end,
    'duration_sec', v_attempt.duration_sec,
    'words', (select coalesce(jsonb_agg(jsonb_build_object(
                'clue_id', pw.id, 'no', pw.no, 'dir', pw.dir, 'word', w.word,
                'meaning_ko', w.meaning_ko, 'solved', aw.solved, 'revealed', aw.revealed,
                'tries', aw.tries, 'letter_hints', aw.letter_hints, 'score', aw.score)
              order by pw.dir, pw.no), '[]'::jsonb)
              from public.attempt_words aw
              join public.puzzle_words pw on pw.id = aw.puzzle_word_id
              join public.words w on w.id = pw.word_id
             where aw.attempt_id = v_attempt.id));
end;
$$;

-- ---------------------------------------------------------------------------
-- get_puzzle: 진행 중 기록이 있으면 비공개로 바뀐 퍼즐도 끝까지 풀 수 있게 한다.
-- ---------------------------------------------------------------------------
create or replace function public.get_puzzle(p_puzzle_id text)
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
  where p.id = p_puzzle_id
    and auth.uid() is not null
    and (p.published or exists (select 1 from public.attempts a
                                 where a.puzzle_id = p.id and a.user_id = auth.uid()
                                   and a.status = 'in_progress'));
$$;

-- ---------------------------------------------------------------------------
-- 권한: 앱(로그인 사용자)은 세 RPC 만. 내부 도우미는 막는다.
-- ---------------------------------------------------------------------------
revoke execute on function public.start_attempt(text) from public, anon;
revoke execute on function public.check_word(bigint, bigint, text, uuid) from public, anon;
revoke execute on function public.finish_attempt(bigint) from public, anon;
grant execute on function public.start_attempt(text) to authenticated;
grant execute on function public.check_word(bigint, bigint, text, uuid) to authenticated;
grant execute on function public.finish_attempt(bigint) to authenticated;

revoke execute on function public.word_score(smallint, smallint) from public, anon, authenticated;
revoke execute on function public.expire_stale_attempts(uuid) from public, anon, authenticated;
revoke execute on function public.attempt_words_json(bigint) from public, anon, authenticated;
