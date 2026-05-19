import 'package:flutter/material.dart';

/// Audesiq spacing, radius and shadow constants.
abstract final class AppDimens {
  // ── Spacing (8dp grid) ─────────────────────────────────────────────────────
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;

  // ── Screen margins ─────────────────────────────────────────────────────────
  static const double screenHorizontalPadding = 16;
  static const double screenHorizontalPaddingLarge = 24;
  static const double bottomSafeAreaMin = 16;

  // ── Appbar / Header ────────────────────────────────────────────────────────
  static const double headerHeight = 56;

  // ── Border radii ───────────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusXxl = 32;
  static const double radiusPill = 100; // fully rounded

  // ── Buttons ────────────────────────────────────────────────────────────────
  static const double buttonHeight = 52;
  static const double buttonHorizontalPadding = 20;
  static const double buttonRadius = 14;
  static const double buttonSyncMinWidth = 140;

  // ── Playback controls ──────────────────────────────────────────────────────
  static const double playButtonSize = 64;
  static const double skipButtonSize = 44;

  // ── Seek bar ───────────────────────────────────────────────────────────────
  static const double seekTrackHeight = 6;
  static const double seekThumbSize = 18;
  static const double seekThumbSizeMax = 22;
  static const double seekTouchTarget = 44;

  // ── Search bar ─────────────────────────────────────────────────────────────
  static const double searchBarHeight = 56;
  static const double searchBarRadius = 12;

  // ── AD / CC badge ──────────────────────────────────────────────────────────
  static const double badgeHeight = 28;
  static const double badgeHorizontalPadding = 10;
  static const double badgeRadius = 14;

  // ── Movie cards (carousel) ─────────────────────────────────────────────────
  static const double cardPosterWidth = 160;
  static const double cardPosterHeight = 240;
  static const double cardRadius = 12;
  static const double cardGapHorizontal = 12;
  static const double cardGapVertical = 16;

  // ── CC container ──────────────────────────────────────────────────────────
  static const double ccContainerPaddingVertical = 22;
  static const double ccContainerPaddingHorizontal = 16;
  static const double ccContainerRadius = 14;

  // ── Loader / progress ring ─────────────────────────────────────────────────
  static const double loaderRingThickness = 5;
  static const double loaderRingThicknessLarge = 6;

  // ── Touch targets ──────────────────────────────────────────────────────────
  static const double touchTargetMin = 44;
  static const double touchTargetPlay = 64;
  static const double touchTargetSync = 52;

  // ── Section spacing ────────────────────────────────────────────────────────
  static const double sectionGap = 20;
  static const double sectionGapLarge = 24;
  static const double carouselSectionGap = 18;

  // ── Controls strip ────────────────────────────────────────────────────────
  static const double controlStripHeightMin = 110;
  static const double controlStripHeightMax = 140;
}

/// Audesiq elevation / shadow tokens.
abstract final class AppShadows {
  /// Default card elevation.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x145B4DFF), // 8% primary
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  /// Hovered / elevated card.
  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x265B4DFF), // 15% primary
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// Phone / modal sheet shadow.
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x2E5B4DFF),
      blurRadius: 60,
      offset: Offset(0, 20),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Seek thumb drop shadow.
  static const List<BoxShadow> seekThumb = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];
}
