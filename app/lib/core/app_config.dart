/// 빌드할 때 `--dart-define-from-file=env/dev.json`으로 넘긴 값을 읽는다.
///
/// 값이 없으면 Supabase 없이 로컬 모드(메모리 안의 가짜 로그인)로 실행한다.
class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabasePublishableKey});

  factory AppConfig.fromEnvironment() => const AppConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      );

  final String supabaseUrl;

  /// `sb_publishable_` 로 시작하는 공개용 키. 앱에 넣어도 안전하다.
  /// `sb_secret_` 키는 RLS를 우회하므로 절대 앱에 넣지 않는다.
  final String supabasePublishableKey;

  bool get hasSupabase => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
