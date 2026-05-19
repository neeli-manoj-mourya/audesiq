import 'package:flutter/material.dart';

/// Audesiq color palette — single source of truth.
/// Use these constants everywhere in the app instead of hardcoding hex values.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  /// Primary purple — buttons, active states, icons, headers.
  static const Color primary = Color(0xFF5B4DFF);

  /// Darker primary — hover / pressed state for primary purple.
  static const Color primaryDark = Color(0xFF4A3FE6);

  /// Accent yellow — progress arcs, highlights, badges overlay.
  static const Color accent = Color(0xFFFFD400);

  // ── Backgrounds ────────────────────────────────────────────────────────────
  /// App-wide light canvas (scaffold background).
  static const Color background = Color(0xFFF5F3FF);

  /// Page / large surface — full white sections.
  static const Color surface = Color(0xFFFFFFFF);

  /// Soft purple tint — section backgrounds, chips, input fills.
  static const Color surfaceAccent = Color(0xFFEDEBFF);

  // ── Cards ──────────────────────────────────────────────────────────────────
  /// Default card background.
  static const Color card = Color(0xFFFFFFFF);

  // ── Text ───────────────────────────────────────────────────────────────────
  /// Primary body text — headings, movie titles, CC text.
  static const Color textPrimary = Color(0xFF1E1E1E);

  /// Secondary / muted text — metadata, placeholders, captions.
  static const Color textSecondary = Color(0xFF6B7280);

  /// Disabled text color.
  static const Color textDisabled = Color(0xFF9CA3AF);

  // ── Borders & Dividers ─────────────────────────────────────────────────────
  /// Subtle divider / outline.
  static const Color divider = Color(0xFFEDEBFF);

  /// Very subtle divider (8 % primary opacity).
  static const Color dividerSoft = Color(0x145B4DFF);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFEF4444);

  // ── Overlays ───────────────────────────────────────────────────────────────
  /// White semi-opaque overlay used under CC / subtitle text.
  static const Color subtitleOverlay = Color(0xE6FFFFFF); // ~0.9 opacity

  /// Dark overlay for poster scrim.
  static const Color darkOverlay = Color(0x99000000); // ~0.6 opacity

  // ── Gradients ──────────────────────────────────────────────────────────────
  /// Splash screen background gradient (top → bottom).
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.4, 1.0],
    colors: [background, surfaceAccent, primary],
  );

  /// Optional button hover / active gradient.
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6B5FFF), primary],
  );

  /// Poster placeholder gradient.
  static const LinearGradient posterPlaceholder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceAccent, Color(0xFFC4BCFF)],
  );
}
