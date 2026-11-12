import 'package:material_ui/material_ui.dart';

/// Figma "WordCross 화면 설계" 파일의 색상 변수(WordCross 컬렉션)와 같은 값.
abstract final class AppColors {
  static const primary = Color(0xFF0F766E);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFCCFBF1);
  static const accent = Color(0xFFD97706);
  static const accentStrong = Color(0xFFFCD34D);
  static const accentContainer = Color(0xFFFEF3C7);
  static const background = Color(0xFFF7F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFEFF1EE);
  static const outline = Color(0xFFDDE1DC);
  static const text = Color(0xFF1C1C1E);
  static const textMuted = Color(0xFF6B7280);
  static const error = Color(0xFFDC2626);
  static const errorContainer = Color(0xFFFEE2E2);
  static const success = Color(0xFF15803D);
  static const cellBlack = Color(0xFF1F2937);
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
  /// Figma 텍스트 스타일 WC/* 와 같은 크기·굵기·줄 높이.
  static const _textTheme = TextTheme(
    displaySmall: TextStyle(fontSize: 36, height: 44 / 36, fontWeight: FontWeight.w700), // WC/Display
    titleLarge: TextStyle(fontSize: 22, height: 30 / 22, fontWeight: FontWeight.w700), // WC/Title
    titleMedium: TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w700), // WC/Heading
    bodyLarge: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400), // WC/Body
    bodyMedium: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500), // WC/Label
    bodySmall: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w400), // WC/Caption
    labelSmall: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w400),
  );

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.accent,
      onSecondary: AppColors.onPrimary,
      secondaryContainer: AppColors.accentContainer,
      onSecondaryContainer: AppColors.accent,
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
    const radius12 = BorderRadius.all(Radius.circular(12));
    const radius10 = BorderRadius.all(Radius.circular(10));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      extensions: const [WordCrossColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const RoundedRectangleBorder(borderRadius: radius12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: AppColors.text,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.outline),
          shape: const RoundedRectangleBorder(borderRadius: radius12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: textTheme.labelLarge),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(borderRadius: radius10, borderSide: BorderSide(color: AppColors.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: radius10, borderSide: BorderSide(color: AppColors.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: radius10, borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: radius10, borderSide: BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radius10, borderSide: BorderSide(color: AppColors.error, width: 1.5)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryContainer,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.bodySmall!.copyWith(
            color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
