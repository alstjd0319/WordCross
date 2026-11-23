import 'package:material_ui/material_ui.dart';

import 'v3_theme.dart';

export 'v3_theme.dart';

/// 앱 전체 색. Figma v3(포근한 손그림 + 고양이) 팔레트([V3Colors])에 역할 이름을 붙인 것.
/// 2026-11-19 교수님 확인 후 1주차 화면도 v3로 바꿨다.
abstract final class AppColors {
  /// 주 버튼 (복숭아)
  static const primary = V3Colors.peach;
  static const onPrimary = Color(0xFFFFFFFF);

  /// 선택된 탭·강조 바탕 (버터)
  static const primaryContainer = V3Colors.butter;

  /// 로컬 모드 띠 등 눈에 띄어야 하는 표시
  static const accent = V3Colors.peach;
  static const accentStrong = V3Colors.butter;
  static const accentContainer = V3Colors.apricot;

  /// 앱 배경 (크림)
  static const background = V3Colors.cream;

  /// 카드·입력칸 바탕
  static const surface = V3Colors.paper;
  static const surfaceVariant = V3Colors.cream;

  /// 손그림 선 (코코아)
  static const outline = V3Colors.cocoa;
  static const text = V3Colors.cocoa;
  static const textMuted = V3Colors.cocoaMuted;

  static const error = Color(0xFFC8423A);
  static const errorContainer = Color(0xFFFDE3DC);
  static const success = Color(0xFF3F8F4A);
  static const cellBlack = V3Colors.chocolate;
}

/// ColorScheme에 자리가 없는 WordCross 전용 색.
@immutable
class WordCrossColors extends ThemeExtension<WordCrossColors> {
  const WordCrossColors({
    required this.textMuted,
    required this.accentStrong,
    required this.success,
    required this.cellBlack,
  });

  final Color textMuted;
  final Color accentStrong;
  final Color success;
  final Color cellBlack;

  static const light = WordCrossColors(
    textMuted: AppColors.textMuted,
    accentStrong: AppColors.accentStrong,
    success: AppColors.success,
    cellBlack: AppColors.cellBlack,
  );

  @override
  WordCrossColors copyWith({Color? textMuted, Color? accentStrong, Color? success, Color? cellBlack}) {
    return WordCrossColors(
      textMuted: textMuted ?? this.textMuted,
      accentStrong: accentStrong ?? this.accentStrong,
      success: success ?? this.success,
      cellBlack: cellBlack ?? this.cellBlack,
    );
  }

  @override
  WordCrossColors lerp(WordCrossColors? other, double t) {
    if (other == null) return this;
    return WordCrossColors(
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      success: Color.lerp(success, other.success, t)!,
      cellBlack: Color.lerp(cellBlack, other.cellBlack, t)!,
    );
  }
}

extension WordCrossThemeX on BuildContext {
  WordCrossColors get wcColors => Theme.of(this).extension<WordCrossColors>()!;
}

abstract final class AppTheme {
  /// v3 글꼴: 제목·버튼 Jua, 영단어·숫자 Fredoka, 본문 Gowun Dodum.
  static const _textTheme = TextTheme(
    displaySmall: TextStyle(fontFamily: V3Fonts.fredoka, fontFamilyFallback: V3Fonts.fallback, fontSize: 36, height: 44 / 36, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(fontFamily: V3Fonts.jua, fontFamilyFallback: V3Fonts.fallback, fontSize: 24, height: 32 / 24),
    titleMedium: TextStyle(fontFamily: V3Fonts.jua, fontFamilyFallback: V3Fonts.fallback, fontSize: 18, height: 24 / 18),
    bodyLarge: TextStyle(fontFamily: V3Fonts.gowun, fontSize: 15, height: 22 / 15),
    bodyMedium: TextStyle(fontFamily: V3Fonts.gowun, fontSize: 15, height: 22 / 15),
    labelLarge: TextStyle(fontFamily: V3Fonts.jua, fontFamilyFallback: V3Fonts.fallback, fontSize: 15, height: 20 / 15),
    bodySmall: TextStyle(fontFamily: V3Fonts.gowun, fontSize: 13, height: 18 / 13),
    labelSmall: TextStyle(fontFamily: V3Fonts.gowun, fontSize: 12, height: 16 / 12),
  );

  /// 입력칸 높이. 손그림 그림자를 입력칸 뒤에 같은 크기로 깔 때 쓴다 (shared/widgets.dart).
  static const fieldHeight = 52.0;
  static const fieldRadius = 12.0;
  static const buttonRadius = 14.0;

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.text,
      secondary: V3Colors.butter,
      onSecondary: AppColors.text,
      secondaryContainer: AppColors.accentContainer,
      onSecondaryContainer: AppColors.text,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      surfaceContainerHighest: AppColors.surfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outline,
    );

    final textTheme = _textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text);
    const buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(buttonRadius)));
    const line = BorderSide(color: AppColors.outline, width: 2);
    OutlineInputBorder field(Color color, [double width = 2]) => OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(fieldRadius)),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: V3Fonts.gowun,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      extensions: const [WordCrossColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
          shape: const WidgetStatePropertyAll(buttonShape),
          side: const WidgetStatePropertyAll(line),
          elevation: const WidgetStatePropertyAll(0),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge!.copyWith(fontSize: 17)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? Color.lerp(AppColors.primary, AppColors.background, 0.45) : AppColors.primary,
          ),
          foregroundColor: const WidgetStatePropertyAll(AppColors.onPrimary),
          overlayColor: WidgetStatePropertyAll(V3Colors.cocoa.withValues(alpha: 0.08)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: AppColors.text,
          backgroundColor: AppColors.surface,
          side: line,
          shape: buttonShape,
          textStyle: textTheme.labelLarge!.copyWith(fontSize: 17),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.text,
          textStyle: textTheme.labelLarge!.copyWith(decoration: TextDecoration.underline, decorationThickness: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        // 15px 글자(줄 높이 22) + 위아래 15 = 52 (fieldHeight)
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        hintStyle: const TextStyle(fontFamily: V3Fonts.gowun, color: AppColors.textMuted),
        border: field(AppColors.outline),
        enabledBorder: field(AppColors.outline),
        focusedBorder: field(AppColors.primary, 2.5),
        errorBorder: field(AppColors.error),
        focusedErrorBorder: field(AppColors.error, 2.5),
        errorStyle: const TextStyle(fontFamily: V3Fonts.gowun, color: AppColors.error, fontSize: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.text,
        contentTextStyle: textTheme.bodyLarge!.copyWith(color: AppColors.background),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    );
  }
}
