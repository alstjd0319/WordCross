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
├─ app/                      앱 전체: 테마(Figma v3 색·글꼴·모양), 라우터, 하단 메뉴
├─ core/                     설정, 입력값 검사
├─ shared/                   여러 화면이 함께 쓰는 위젯
└─ features/
   ├─ auth/                  로그인, 회원가입, 인증 저장소(Supabase / 로컬)
   ├─ home/                  홈 (4주차)
   ├─ play/                  퍼즐 풀이: 격자, 칸 선택, 전용 키보드, 힌트 바 (2주차), 퍼즐 저장소(get_puzzle RPC / 로컬 샘플)
   ├─ puzzles/               퍼즐 목록(난이도 필터, 3주차). 상세는 3주차에 더함
   ├─ wrong_notes/           오답 노트·복습 카드 (4~5주차)
   └─ my_page/               마이페이지 (5주차)
```

- **디자인:** Figma "WordCross 화면 설계" 파일의 **v3 시안(포근한 손그림 + 고양이)**. 2026-11-19 교수님 확인 후 앱 전체에 적용했습니다.
  - 팔레트·글꼴·손그림 모양은 `lib/app/v3_theme.dart`(`V3Colors`, `V3Text`, `v3Box`), 역할별 색과 Material 테마는 `lib/app/theme.dart`(`AppColors`, `AppTheme`).
  - 공용 v3 위젯(`shared/widgets.dart`): `PrimaryButton`, `V3Card`, `V3IconButton`, `CatImage`, `LabeledField`, `ComingSoon`. 하단 메뉴는 `app/main_shell.dart`의 `MainNavBar`.
  - 글꼴: Jua(제목·버튼), Fredoka(영단어·숫자), Gowun Dodum(본문). `assets/fonts/`, 모두 SIL OFL 1.1 (`OFL-*.txt`).
  - 고양이: Figma `v3/Cat` 컴포넌트 40마리를 1x·2x·3x PNG로 내보내 `assets/images/cats/`에 넣었습니다. 이름은 `<자세>_<털색>.png` (예: `sit_calico`, `curl_black`), 화면에서는 `CatImage('sit_calico')`.
- **퍼즐 데이터:** 목록은 `puzzles` 테이블(공개된 퍼즐, 정답 없음), 퍼즐 하나는 `get_puzzle()` RPC로 받습니다 (`SupabasePuzzleRepository`).
  - 로컬 모드: `features/play/sample_puzzles.dart`에 난이도별 2개씩(beg/mid/adv-001·002)을 `data/` 의 퍼즐·틀·`words.csv` 로 만든 `get_puzzle()` 모양 JSON으로 넣었습니다. 정답 철자는 넣지 않습니다. `data/` 가 바뀌면 다시 만듭니다.
  - 테스트는 `data/` 가 바뀌어도 깨지지 않도록 `test/fixtures/test_puzzles.dart`의 고정 퍼즐을 씁니다.
  - 예상 풀이 시간은 `PuzzleLevel.estimatedMinutes`(난이도별 단어당 시간 × 단어 수)로 어림합니다.
- **상태 관리:** Riverpod. 화면은 `authRepositoryProvider` 같은 Provider로만 데이터에 접근하고, 테스트에서는 가짜 구현으로 바꿉니다.
- **화면 이동:** go_router. 하단 메뉴 4개 탭은 `StatefulShellRoute`로 탭마다 상태를 유지합니다. 퍼즐 풀이·결과·복습 카드처럼 메뉴를 숨기는 화면은 root navigator에 올립니다.
- **Material:** Flutter SDK에 들어 있던 Material은 지원 중단 예정이라 `material_ui` 패키지를 씁니다. `import 'package:material_ui/material_ui.dart';`

## 들어갈 화면

- 홈, 퍼즐 목록·상세, 퍼즐 풀이(격자, 힌트 바, 전용 키보드), 결과
- 오답 노트·복습 카드, 마이페이지·통계, 알림 설정

복습 알림 패키지(`flutter_local_notifications`, `timezone`)는 5주차에 추가합니다. 최신판이 Android compileSdk 37, AGP 9.1.1 이상을 요구해 빌드 설정을 함께 올려야 합니다.
