\set ON_ERROR_STOP 0
insert into auth.users (id, email, raw_user_meta_data) values
 ('11111111-1111-1111-1111-111111111111','a@x.com','{"nickname":"민성"}'),
 ('22222222-2222-2222-2222-222222222222','b@x.com','{}');
select id, nickname from public.profiles;
insert into public.words (word,type,level,meaning_ko,definition_en,example,example_blank,source) values
 ('SCHEDULE','learn','intermediate','일정','a plan of times','Check the schedule.','Check the _____.','TSL'),
 ('SUPPLY','learn','intermediate','공급','to provide',null,null,'TSL');
insert into public.puzzles (id,level,rows,cols,template,blocks,word_count,published) values
 ('mid-001','intermediate',13,13,'uk-13-01','[[1,1]]',2,true), ('mid-002','intermediate',13,13,'uk-13-02','[]',0,false);
insert into public.puzzle_words (puzzle_id,no,dir,row,col,length,word_id) values
 ('mid-001',1,'across',0,0,8,1),('mid-001',1,'down',0,0,6,2);

set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
\echo '--- [A] 퍼즐 목록 (공개만 보여야 함: mid-001)'
select id, published from public.puzzles;
\echo '--- [A] words 직접 읽기 (거부돼야 함)'
select word from public.words;
\echo '--- [A] puzzle_words 직접 읽기 (거부돼야 함)'
select * from public.puzzle_words;
\echo '--- [A] get_puzzle (정답 철자·원문 예문 없어야 함)'
select public.get_puzzle('mid-001');
\echo '--- [A] 비공개 퍼즐 get_puzzle (null)'
select public.get_puzzle('mid-002');
\echo '--- [A] 내 프로필만 보임 (1행)'
select id, nickname from public.profiles;
\echo '--- [A] 풀이 기록 추가 (성공)'
insert into public.attempts (puzzle_id) values ('mid-001') returning user_id;
\echo '--- [A] 다른 사람 이름으로 풀이 기록 (거부)'
insert into public.attempts (user_id, puzzle_id) values ('22222222-2222-2222-2222-222222222222','mid-001');
\echo '--- [A] 점수 직접 수정 (0행: 정책 없음)'
update public.attempts set score = 9999;
\echo '--- [A] 오답 직접 추가 (거부: RPC로만)'
insert into public.wrong_words (word_id) values (1);
reset role;
insert into public.wrong_words (user_id, word_id) values ('11111111-1111-1111-1111-111111111111',1),('22222222-2222-2222-2222-222222222222',1);
set role authenticated; select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
\echo '--- [B] 내 오답만 (1행, user 2222)'
select user_id, word_id from public.wrong_words;
\echo '--- [B] A의 풀이 기록 안 보임 (0행)'
select count(*) from public.attempts;
\echo '--- [B] 계정 삭제'
select public.delete_my_account();
reset role;
\echo '--- 삭제 후 B의 데이터 (users 1, profiles 1, wrong_words 1)'
select (select count(*) from auth.users) users, (select count(*) from public.profiles) profiles, (select count(*) from public.wrong_words) wrong;
set role anon; select set_config('request.jwt.claim.sub','',false);
\echo '--- [anon] 퍼즐 목록/ get_puzzle (거부)'
select id from public.puzzles;
select public.get_puzzle('mid-001');
reset role;
