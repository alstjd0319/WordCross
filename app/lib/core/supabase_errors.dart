import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// 로그인이 풀려서 서버가 거절했는지.
/// 비로그인 호출은 테이블·함수 권한(42501)에서, 만료되거나 잘못된 토큰은 PostgREST(PGRST301·303)에서 막히고,
/// 함수 안에서는 not_authenticated(delete_my_account 는 'not authenticated') 예외로 온다.
bool isLoginExpired(Object error) =>
    error is PostgrestException &&
    (const {'42501', 'PGRST301', 'PGRST303'}.contains(error.code) ||
        error.message == 'not_authenticated' ||
        error.message == 'not authenticated');
