import 'package:material_ui/material_ui.dart';

/// Figma "WordCross 화면 설계" v3 (포근한 손그림 + 고양이) 디자인 규칙.
///
/// 앱 전체의 기본 팔레트다. 화면에서는 역할 이름이 붙은 `AppColors`(theme.dart)를 주로 쓰고,
/// 퍼즐 격자처럼 팔레트 색 자체가 뜻을 갖는 곳(살구 = 선택 단어 등)은 여기 값을 바로 쓴다.
abstract final class V3Colors {
  /// 코코아 · 선·글자
  static const cocoa = Color(0xFF7A5236);

  /// 크림 · 앱 배경
  static const cream = Color(0xFFFFF5E3);

  /// 복숭아 · 주 버튼
  static const peach = Color(0xFFF49D5E);

  /// 버터 · 현재 칸·중급·선택 탭
  static const butter = Color(0xFFFFD872);

  /// 살구 · 선택 단어
  static const apricot = Color(0xFFFFD3C6);

  /// 민트 · 맞힘·초급·숙달
  static const mint = Color(0xFFBDE5BF);

  /// 라벤더 · 글자 힌트·고급
  static const lavender = Color(0xFFD3BFF0);

  /// 초콜릿 · 검은 칸
  static const chocolate = Color(0xFFA0735A);

  /// 카드·흰 칸·키 바탕. 시안에서 크림보다 밝게 보이는 면 (Figma 값 확인 전 근사값).
  static const paper = Color(0xFFFFFCF6);

  /// 보조 글자. 크림 배경과 대비 약 5:1 (읽기 기준 4.5:1 이상).
  static const cocoaMuted = Color(0xFF85634E);
}

/// v3 글꼴 (assets/fonts, 모두 SIL OFL 1.1).
abstract final class V3Fonts {
  /// 제목·버튼
  static const jua = 'Jua';

  /// 영단어·숫자
  static const fredoka = 'Fredoka';

  /// 본문
  static const gowun = 'GowunDodum';

  /// Jua에는 ×·· 같은 기호가, Fredoka에는 한글이 없다. 빠진 글자는 Gowun Dodum으로 채운다.
  static const fallback = [gowun];
}

abstract final class V3Text {
  static const title = TextStyle(fontFamily: V3Fonts.jua, fontFamilyFallback: V3Fonts.fallback, fontSize: 22, height: 1.2, color: V3Colors.cocoa);
  static const button = TextStyle(fontFamily: V3Fonts.jua, fontFamilyFallback: V3Fonts.fallback, fontSize: 16, height: 1.2, color: V3Colors.cocoa);
  static const body = TextStyle(fontFamily: V3Fonts.gowun, fontSize: 15, height: 1.4, color: V3Colors.cocoa);
  static const caption = TextStyle(fontFamily: V3Fonts.gowun, fontSize: 13, height: 1.3, color: V3Colors.cocoaMuted);

  /// 영단어·숫자. 굵기는 가변 글꼴 축(wght)으로 준다.
  static TextStyle word(double size, {FontWeight weight = FontWeight.w600, Color color = V3Colors.cocoa}) => TextStyle(
        fontFamily: V3Fonts.fredoka,
        fontFamilyFallback: V3Fonts.fallback,
        fontSize: size,
        height: 1,
        color: color,
        fontWeight: weight,
        fontVariations: [FontVariation.weight(weight.value.toDouble())],
      );
}

/// v3 손그림 모양: 갈색 선 2~2.5px, 아래로 3px 그림자(갈색 18%), 모서리 9~22.
BoxDecoration v3Box({
  Color color = V3Colors.paper,
  double radius = 14,
  double borderWidth = 2,
  bool shadow = true,
  Color borderColor = V3Colors.cocoa,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor, width: borderWidth),
    boxShadow: shadow ? [BoxShadow(color: V3Colors.cocoa.withValues(alpha: 0.18), offset: const Offset(0, 3))] : null,
  );
}
