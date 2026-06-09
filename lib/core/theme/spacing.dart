/// ZapSafe design system spacing — 4px grid base unit
/// All spacing values are multiples of 4px for visual consistency
///
/// Touch targets follow WCAG 2.1 AAA (75×75dp minimum) — NOT the AA 48dp standard
/// This is a deliberate accessibility choice for a safety-critical app where
/// stressed/scared/elderly users must be able to hit buttons reliably.
library;

class ZapSpacing {
  // ─── Base unit: 4px grid ──────────────────────────────────────────────
  static const xs = 4.0; //  4px
  static const sm = 8.0; //  8px
  static const md = 12.0; // 12px
  static const lg = 16.0; // 16px
  static const xl = 20.0; // 20px
  static const xxl = 24.0; // 24px
  static const xxxl = 32.0; // 32px
  static const huge = 48.0; // 48px
  static const massive = 64.0; // 64px

  // ─── Aliases (semantic naming) ────────────────────────────────────────
  static const tiny = xs; // 4px
  static const small = sm; // 8px
  static const medium = md; // 12px
  static const regular = lg; // 16px
  static const large = xl; // 20px
  static const larger = xxl; // 24px
  static const extraLarge = xxxl; // 32px

  // ─── Standard padding/gap/radius ─────────────────────────────────────
  static const paddingInline = lg; // 16px horizontal padding
  static const paddingBlock = lg; // 16px vertical padding
  static const gap = md; // 12px gap between elements
  static const gapLarge = xxl; // 24px gap for sections
  static const radius = lg; // 16px border radius default
  static const radiusSmall = sm; // 8px small radius
  static const radiusLarge = xxl; // 24px large radius
  static const radiusPill = 999.0; // pill-shaped radius

  // ─── WCAG 2.1 AAA Touch Targets ──────────────────────────────────────
  // Minimum 75×75dp for every interactive element
  // (WCAG AA is 48dp, but for safety apps where users may be stressed/scared/elderly
  //  we go a level higher to AAA — Microsoft & Apple recommend this for accessibility)
  static const minTouchTarget = 75.0; // ← USE THIS EVERYWHERE for taps

  // ─── Component-specific sizes ────────────────────────────────────────
  static const sosButtonDiameter = 80.0; // Dashboard SOS button (slightly above min)
  static const navItemHeight = 75.0; // Bottom nav item height
  static const listItemHeight = 75.0; // List row height (contacts, vault)
  static const buttonHeight = 75.0; // Default button height
  static const inputHeight = 75.0; // Text field height
  static const iconButton = 75.0; // Icon-only button hit area

  // ─── Elevation shadows ───────────────────────────────────────────────
  static const shadowXs = 2.0;
  static const shadowSm = 4.0;
  static const shadowMd = 8.0;
  static const shadowLg = 12.0;
  static const shadowXl = 16.0;
}
