-- 정답 확인·점수 규칙 검사 (3주차). run_rls_check.sh 가 migration 다음에 실행한다.
-- 하나라도 틀리면 ERROR 로 멈춘다. 끝까지 가면 마지막 줄에 'score_check: 모두 통과'.
\set ON_ERROR_STOP 1
\set QUIET 1

-- 검사 도우미 (테스트 DB 에만 만든다)
create function public.t_ok(p_cond boolean, p_label text) returns void language plpgsql as $$
begin
  if p_cond is distinct from true then raise exception 'FAIL: %', p_label; end if;
  raise notice 'ok  %', p_label;
end; $$;
create function public.t_raises(p_sql text, p_msg text, p_label text) returns void language plpgsql as $$
declare v_ok boolean := false;
begin
  begin
    execute p_sql;
  exception when others then
    if sqlerrm like p_msg || '%' then v_ok := true;
    else raise exception 'FAIL: % — expected "%", got "%"', p_label, p_msg, sqlerrm; end if;
  end;
  if not v_ok then raise exception 'FAIL: % — expected "%", but it succeeded', p_label, p_msg; end if;
  raise notice 'ok  %', p_label;
end; $$;
grant execute on function public.t_ok(boolean, text), public.t_raises(text, text, text) to authenticated, anon;

-- 데이터: 퍼즐 t-001(CONTRACT, RETAIL), t-002(TRADE), t-003(ORDER)
insert into auth.users (id) values ('aaaaaaaa-0000-0000-0000-000000000001'), ('bbbbbbbb-0000-0000-0000-000000000002');
insert into public.words (word, type, level, meaning_ko, source) values
  ('CONTRACT', 'learn', 'intermediate', '계약', 'TSL'), ('RETAIL', 'learn', 'beginner', '소매', 'TSL'),
  ('TRADE', 'learn', 'beginner', '무역', 'TSL'), ('ORDER', 'fill', 'beginner', '주문', 'NGSL');
insert into public.puzzles (id, level, rows, cols, template, word_count, published) values
  ('t-001', 'beginner', 9, 9, 'uk-9-01', 2, true), ('t-002', 'beginner', 9, 9, 'uk-9-02', 1, true),
  ('t-003', 'beginner', 9, 9, 'uk-9-03', 1, true);
insert into public.puzzle_words (puzzle_id, no, dir, row, col, length, word_id) values
  ('t-001', 1, 'across', 0, 0, 8, (select id from public.words where word = 'CONTRACT')),
  ('t-001', 1, 'down', 0, 0, 6, (select id from public.words where word = 'RETAIL')),
  ('t-002', 1, 'across', 0, 0, 5, (select id from public.words where word = 'TRADE')),
  ('t-003', 1, 'across', 0, 0, 5, (select id from public.words where word = 'ORDER'));
select (select id from public.puzzle_words where puzzle_id = 't-001' and dir = 'across') as c1,
       (select id from public.puzzle_words where puzzle_id = 't-001' and dir = 'down') as c2,
       (select id from public.puzzle_words where puzzle_id = 't-002') as c3 \gset

select public.t_ok(public.word_score(1::smallint, 0::smallint) = 100, '한 번에 정답 100점');
select public.t_ok(public.word_score(3::smallint, 0::smallint) = 80, '2번 틀리고 정답 80점');
select public.t_ok(public.word_score(2::smallint, 2::smallint) = 50, '힌트 2회 + 1번 틀림 50점');
select public.t_ok(public.word_score(5::smallint, 2::smallint) = 20, '최소 20점');

-- ---------------------------------------------------------------- 사용자 A
set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-000000000001', false) \gset x_

select public.start_attempt('t-001') as s \gset
select (:'s'::jsonb ->> 'attempt_id')::bigint as aid \gset
select public.t_ok((:'s'::jsonb ->> 'resumed')::boolean = false, '시작: 새 기록');
select public.t_ok(jsonb_array_length(:'s'::jsonb -> 'words') = 2, '시작: 단어 2개');
select public.t_ok(not (:'s'::jsonb::text ~ 'CONTRACT'), '시작: 정답 철자 없음');
select public.t_ok((public.start_attempt('t-001') ->> 'attempt_id')::bigint = :aid
                   and (public.start_attempt('t-001') ->> 'resumed')::boolean, '다시 시작하면 이어 풀기');

select public.t_raises($q$select public.check_word($q$ || :aid || ', ' || :c1 || $q$, 'CON')$q$, 'invalid_guess', '글자 수가 다르면 거부 (시도 안 셈)');
select public.t_raises($q$select public.check_word($q$ || :aid || ', ' || :c1 || $q$, 'CONTRAC3')$q$, 'invalid_guess', '알파벳 아니면 거부');

select public.check_word(:aid, :c1, 'CONTRACX') as r \gset
select public.t_ok((:'r'::jsonb ->> 'correct')::boolean = false and (:'r'::jsonb ->> 'tries')::int = 1
                   and (:'r'::jsonb ->> 'counted')::boolean and not (:'r'::jsonb ? 'answer'), '오답: 시도 1, 정답 안 알려 줌');
select public.check_word(:aid, :c1, 'CONTRACX') as r \gset
select public.t_ok((:'r'::jsonb ->> 'tries')::int = 1 and not (:'r'::jsonb ->> 'counted')::boolean, '같은 오답 반복은 안 셈');

select public.check_word(:aid, :c1, 'CONTRACY', '11111111-2222-3333-4444-555555555555') as r \gset
select public.t_ok((:'r'::jsonb ->> 'tries')::int = 2, '다른 오답: 시도 2');
select public.check_word(:aid, :c1, 'CONTRACY', '11111111-2222-3333-4444-555555555555') as r \gset
select public.t_ok((:'r'::jsonb ->> 'tries')::int = 2, '같은 요청 재전송은 한 번만 처리');

select public.check_word(:aid, :c1, 'contract') as r \gset
select public.t_ok((:'r'::jsonb ->> 'correct')::boolean and (:'r'::jsonb ->> 'tries')::int = 3
                   and (:'r'::jsonb ->> 'score')::int = 80 and :'r'::jsonb ->> 'answer' = 'CONTRACT', '소문자 정답 인정, 2번 틀려 80점, 철자 공개');
select public.check_word(:aid, :c1, 'CONTRACX') as r \gset
select public.t_ok((:'r'::jsonb ->> 'solved')::boolean and not (:'r'::jsonb ->> 'counted')::boolean, '맞힌 단어는 잠김');

select public.check_word(:aid, :c2, w) from unnest(array['AAAAAA','BBBBBB','CCCCCC','DDDDDD','EEEEEE']) w \g /dev/null
select public.t_raises($q$select public.check_word($q$ || :aid || ', ' || :c2 || $q$, 'FFFFFF')$q$, 'no_tries_left', '5번 틀리면 더 못 함');
select public.t_raises($q$select public.check_word($q$ || :aid || ', ' || :c2 || $q$, 'RETAIL')$q$, 'no_tries_left', '5번 뒤에는 정답도 못 넣음');
select public.t_raises($q$select public.check_word($q$ || :aid || ', ' || :c3 || $q$, 'TRADE')$q$, 'clue_not_in_puzzle', '다른 퍼즐의 단어는 거부');

select public.t_raises($q$insert into public.attempts (puzzle_id, score) values ('t-001', 9999)$q$, 'permission denied', '앱이 기록을 직접 만들 수 없음');
select public.t_raises($q$update public.attempt_words set score = 100$q$, 'permission denied', '앱이 점수를 직접 바꿀 수 없음');

select public.finish_attempt(:aid) as f \gset
select public.t_ok((:'f'::jsonb ->> 'score')::int = 80 and (:'f'::jsonb ->> 'correct')::int = 1
                   and (:'f'::jsonb ->> 'total')::int = 2 and (:'f'::jsonb ->> 'accuracy')::numeric = 0.5, '제출: 80점, 1/2, 정답률 0.5');
select public.t_ok(:'f'::jsonb::text ~ 'RETAIL', '제출 결과에는 못 푼 단어 정답도 있음');
select public.t_ok((public.finish_attempt(:aid) ->> 'score')::int = 80, '다시 제출해도 같은 결과');
select public.t_raises($q$select public.check_word($q$ || :aid || ', ' || :c2 || $q$, 'RETAIL')$q$, 'attempt_closed', '제출 뒤에는 확인 불가');
select public.t_ok((public.start_attempt('t-001') ->> 'resumed')::boolean = false, '같은 퍼즐 다시 풀기는 새 기록');

-- 진행 중에 비공개로 바뀐 퍼즐
select (public.start_attempt('t-002') ->> 'attempt_id')::bigint as aid2 \gset
reset role;
update public.puzzles set published = false where id = 't-002';
set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-000000000001', false) \gset x_
select public.t_ok(public.get_puzzle('t-002') is not null, '진행 중이면 비공개 퍼즐도 계속 풀 수 있음');
select (public.start_attempt('t-003') ->> 'attempt_id')::bigint as aid3 \gset
reset role;
update public.attempts set started_at = now() - interval '25 hours' where id = :aid3;
set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-000000000001', false) \gset x_
select public.t_ok((public.start_attempt('t-003') ->> 'attempt_id')::bigint <> :aid3, '24시간 지나면 포기 처리 후 새 기록');
select public.t_ok((select status from public.attempts where id = :aid3) = 'abandoned', '오래된 기록은 abandoned');

-- ---------------------------------------------------------------- 사용자 B
select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-000000000002', false) \gset x_
select public.t_raises($q$select public.check_word($q$ || :aid2 || ', ' || :c3 || $q$, 'TRADE')$q$, 'attempt_not_found', '남의 기록은 확인 불가');
select public.t_raises($q$select public.finish_attempt($q$ || :aid2 || $q$)$q$, 'attempt_not_found', '남의 기록은 제출 불가');
select public.t_ok(public.get_puzzle('t-002') is null, '진행 중 기록이 없으면 비공개 퍼즐 안 보임');
select public.t_raises($q$select public.start_attempt('t-002')$q$, 'puzzle_not_found', '비공개 퍼즐은 새로 시작 불가');
select public.t_ok((select count(*) from public.attempts) = 0, '남의 기록은 목록에도 안 보임');

-- ---------------------------------------------------------------- 비로그인
set role anon;
select set_config('request.jwt.claim.sub', '', false) \gset x_
select public.t_raises($q$select public.start_attempt('t-001')$q$, 'permission denied', '비로그인은 시작 불가');
reset role;

\echo 'score_check: 모두 통과'
