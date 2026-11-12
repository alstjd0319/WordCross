# app — Flutter 앱

담당: 지태웅

## 실행하기

Flutter 3.47.6 이상 (CI도 이 버전으로 검사합니다).

```
cd app
flutter pub get
flutter run
```

Supabase 접속 정보 없이 실행하면 **로컬 모드**로 동작합니다. 화면 오른쪽 위에 "로컬 모드" 띠가 보이고, 회원가입·로그인은 앱 메모리 안에서만 처리됩니다(앱을 끄면 사라짐). 서버 없이 화면을 개발하고 테스트할 때 씁니다.

### Supabase에 연결하기

1. `env/dev.example.json`을 복사해 `env/dev.json`을 만들고 값을 채웁니다. `env/dev.json`은 커밋되지 않습니다.
   - `SUPABASE_URL`: 프로젝트 URL
   - `SUPABASE_PUBLISHABLE_KEY`: `sb_publishable_`로 시작하는 공개용 키. 구형 `anon` 키도 동작하지만 Supabase가 2026년 말까지 폐기할 예정입니다.
   - `sb_secret_` / `service_role` 키는 RLS를 우회하므로 **절대 앱에 넣지 않습니다.**
2. 실행합니다.

```
flutter run --dart-define-from-file=env/dev.json
```

## 검사

```
flutter analyze
flutter test
```

`main`에 PR을 올리면 GitHub Actions(`.github/workflows/app.yml`)가 같은 검사를 실행합니다.

## 구조

```
lib/
├─ main.dart                 Supabase 연결 여부에 따라 인증 구현을 고름
├─ app/                      앱 전체: 테마(Figma 색·글자 스타일), 라우터, 하단 메뉴
├─ core/                     설정, 입력값 검사
├─ shared/                   여러 화면이 함께 쓰는 위젯
└─ features/
   ├─ auth/                  로그인, 회원가입, 인증 저장소(Supabase / 로컬)
   ├─ home/                  홈 (4주차)
   ├─ puzzles/               퍼즐 목록·상세 (3주차)
   ├─ wrong_notes/           오답 노트·복습 카드 (4~5주차)
   └─ my_page/               마이페이지 (5주차)
```

- **디자인:** Figma "WordCross 화면 설계" 파일. 색은 `lib/app/theme.dart`의 `AppColors`에 같은 값으로 들어 있습니다.
- **상태 관리:** Riverpod. 화면은 `authRepositoryProvider` 같은 Provider로만 데이터에 접근하고, 테스트에서는 가짜 구현으로 바꿉니다.
- **화면 이동:** go_router. 하단 메뉴 4개 탭은 `StatefulShellRoute`로 탭마다 상태를 유지합니다. 퍼즐 풀이·결과·복습 카드처럼 메뉴를 숨기는 화면은 root navigator에 올립니다.
- **Material:** Flutter SDK에 들어 있던 Material은 지원 중단 예정이라 `material_ui` 패키지를 씁니다. `import 'package:material_ui/material_ui.dart';`

## 들어갈 화면

- 홈, 퍼즐 목록·상세, 퍼즐 풀이(격자, 힌트 바, 전용 키보드), 결과
- 오답 노트·복습 카드, 마이페이지·통계, 알림 설정

복습 알림 패키지(`flutter_local_notifications`, `timezone`)는 5주차에 추가합니다. 최신판이 Android compileSdk 37, AGP 9.1.1 이상을 요구해 빌드 설정을 함께 올려야 합니다.
