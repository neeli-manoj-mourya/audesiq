import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_dimens.dart';

/// Builds the main [ThemeData] for Audesiq.
///
/// Usage in main.dart:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.light,
///   ...
/// )
/// ```
abstract final class AppTheme {
  // ──────────────────────────────────────────────────────────────────────────
  // Light Theme (primary)
  // ──────────────────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: _lightColorScheme,
    textTheme: buildTextTheme(),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: _appBarTheme,
    cardTheme: _cardTheme,
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    textButtonTheme: _textButtonTheme,
    inputDecorationTheme: _inputDecorationTheme,
    chipTheme: _chipTheme,
    dividerTheme: _dividerTheme,
    sliderTheme: _sliderTheme,
    navigationBarTheme: _navigationBarTheme,
    iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
    primaryIconTheme: const IconThemeData(color: AppColors.primary, size: 24),
    fontFamily: 'Montserrat',
  );

  // ──────────────────────────────────────────────────────────────────────────
  // ColorScheme
  // ──────────────────────────────────────────────────────────────────────────
  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.surface,
    primaryContainer: AppColors.surfaceAccent,
    onPrimaryContainer: AppColors.primary,
    secondary: AppColors.accent,
    onSecondary: AppColors.textPrimary,
    secondaryContainer: Color(0xFFFFF8CC),
    onSecondaryContainer: AppColors.textPrimary,
    tertiary: AppColors.primaryDark,
    onTertiary: AppColors.surface,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceAccent,
    onSurfaceVariant: AppColors.textSecondary,
    error: AppColors.error,
    onError: AppColors.surface,
    outline: AppColors.divider,
    outlineVariant: AppColors.dividerSoft,
    shadow: Color(0x145B4DFF),
    scrim: AppColors.darkOverlay,
  );

  // ──────────────────────────────────────────────────────────────────────────
  // AppBar
  // ──────────────────────────────────────────────────────────────────────────
  static final AppBarTheme _appBarTheme = AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.textPrimary,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
    titleTextStyle: AppTextStyles.titleLarge.copyWith(
      color: AppColors.primary,
      fontSize: 16,
    ),
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
    toolbarHeight: AppDimens.headerHeight,
    shape: const Border(
      bottom: BorderSide(color: AppColors.divider, width: 1),
    ),
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Cards
  // ──────────────────────────────────────────────────────────────────────────
  static const CardThemeData _cardTheme = CardThemeData(
    color: AppColors.card,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppDimens.radiusLg)),
    ),
    shadowColor: Color(0x145B4DFF),
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Elevated Button  →  primary filled button
  // ──────────────────────────────────────────────────────────────────────────
  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.surface,
      disabledBackgroundColor: AppColors.surfaceAccent,
      disabledForegroundColor: AppColors.textDisabled,
      elevation: 0,
      shadowColor: Colors.transparent,
      minimumSize: const Size(0, AppDimens.buttonHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.buttonHorizontalPadding,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppDimens.buttonRadius)),
      ),
      textStyle: AppTextStyles.button,
    ),
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Outlined Button  →  secondary / ghost button
  // ──────────────────────────────────────────────────────────────────────────
  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.primary, width: 1.5),
      minimumSize: const Size(0, AppDimens.buttonHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.buttonHorizontalPadding,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppDimens.buttonRadius)),
      ),
      textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
    ),
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Text Button
  // ──────────────────────────────────────────────────────────────────────────
  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: AppTextStyles.buttonSmall.copyWith(color: AppColors.primary),
    ),
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Input Decoration  →  search bar and text fields
  // ──────────────────────────────────────────────────────────────────────────
  static final InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    hintStyle: AppTextStyles.searchPlaceholder,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppDimens.space4,
      vertical: AppDimens.space4,
    ),
    constraints: const BoxConstraints(minHeight: AppDimens.searchBarHeight),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.searchBarRadius),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.searchBarRadius),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.searchBarRadius),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Chip  →  AD / CC badges
  // ──────────────────────────────────────────────────────────────────────────
  static final ChipThemeData _chipTheme = ChipThemeData(
    backgroundColor: AppColors.surfaceAccent,
    selectedColor: AppColors.primary,
    labelStyle: AppTextStyles.badge.copyWith(color: AppColors.textSecondary),
    secondaryLabelStyle: AppTextStyles.badge,
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimens.badgeHorizontalPadding,
      vertical: 0,
    ),
    shape: const StadiumBorder(),
    elevation: 0,
    pressElevation: 0,
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Divider
  // ──────────────────────────────────────────────────────────────────────────
  static const DividerThemeData _dividerTheme = DividerThemeData(
    color: AppColors.divider,
    thickness: 1,
    space: 1,
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Slider  →  seek bar
  // ──────────────────────────────────────────────────────────────────────────
  static const SliderThemeData _sliderTheme = SliderThemeData(
    activeTrackColor: AppColors.primary,
    inactiveTrackColor: AppColors.surfaceAccent,
    thumbColor: AppColors.surface,
    overlayColor: Color(0x1A5B4DFF),
    trackHeight: AppDimens.seekTrackHeight,
    thumbShape: RoundSliderThumbShape(
      enabledThumbRadius: AppDimens.seekThumbSize / 2,
    ),
    overlayShape: RoundSliderOverlayShape(
      overlayRadius: AppDimens.seekTouchTarget / 2,
    ),
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Navigation Bar  →  bottom nav
  // ──────────────────────────────────────────────────────────────────────────
  static final NavigationBarThemeData _navigationBarTheme =
      NavigationBarThemeData(
    backgroundColor: AppColors.surface,
    indicatorColor: AppColors.surfaceAccent,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: AppColors.primary);
      }
      return const IconThemeData(color: AppColors.textSecondary);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppTextStyles.navLabel.copyWith(color: AppColors.primary);
      }
      return AppTextStyles.navLabel.copyWith(color: AppColors.textSecondary);
    }),
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
  );
}
