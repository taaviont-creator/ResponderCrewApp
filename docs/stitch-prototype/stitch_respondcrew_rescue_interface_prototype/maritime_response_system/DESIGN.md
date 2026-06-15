---
name: Maritime Response System
colors:
  surface: '#f9f9ff'
  surface-dim: '#d3daea'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f3ff'
  surface-container: '#e7eefe'
  surface-container-high: '#e2e8f8'
  surface-container-highest: '#dce2f3'
  on-surface: '#151c27'
  on-surface-variant: '#43474f'
  inverse-surface: '#2a313d'
  inverse-on-surface: '#ebf1ff'
  outline: '#737780'
  outline-variant: '#c3c6d1'
  surface-tint: '#3a5f94'
  primary: '#001e40'
  on-primary: '#ffffff'
  primary-container: '#003366'
  on-primary-container: '#799dd6'
  inverse-primary: '#a7c8ff'
  secondary: '#526069'
  on-secondary: '#ffffff'
  secondary-container: '#d3e2ed'
  on-secondary-container: '#56656e'
  tertiary: '#002504'
  on-tertiary: '#ffffff'
  tertiary-container: '#003d0b'
  on-tertiary-container: '#5ead5c'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d5e3ff'
  primary-fixed-dim: '#a7c8ff'
  on-primary-fixed: '#001b3c'
  on-primary-fixed-variant: '#1f477b'
  secondary-fixed: '#d6e5ef'
  secondary-fixed-dim: '#bac9d3'
  on-secondary-fixed: '#0f1d25'
  on-secondary-fixed-variant: '#3b4951'
  tertiary-fixed: '#a3f69c'
  tertiary-fixed-dim: '#88d982'
  on-tertiary-fixed: '#002204'
  on-tertiary-fixed-variant: '#005312'
  background: '#f9f9ff'
  on-background: '#151c27'
  surface-variant: '#dce2f3'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-bold:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  status-badge:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  container-padding: 16px
  stack-gap: 12px
  section-margin: 24px
  touch-target-min: 48px
---

## Brand & Style

The design system is engineered for **RespondCrew**, focusing on high-stakes reliability and rapid information processing for sea rescue volunteers. The brand personality is authoritative yet calm—providing a steady hand during emergency operations. 

The aesthetic follows a **Corporate Modern** approach with a focus on **High-Contrast Utility**. It prioritizes extreme legibility and physical ease-of-use (tactility) to ensure the interface remains functional under stress, varying light conditions, and "on-the-move" maritime environments. 

The emotional goal is to instill confidence and clarity. Every UI element must feel intentional and robust, avoiding decorative flourishes in favor of structured, purposeful layouts that respect the urgency of the user's mission.

## Colors

The palette is anchored by **Deep Sea Blue**, conveying institutional trust and maritime heritage. 

- **Primary & Action:** Deep Sea Blue (#003366) is used for primary buttons, active states, and structural headers.
- **Surface & Background:** A clean white base with Light Surface Greys (F9FAFB) distinguishes between different content modules without adding visual clutter.
- **Status Indicators:** 
    - **Valves/Aktiivne (Ready):** Emerald Green (#2E7D32) signifies operational readiness.
    - **Hoiatus (Warning):** Amber (#F59E0B) indicates delays or equipment checks.
    - **Kriitiline (Urgent):** Emergency Red (#DC2626) is reserved exclusively for active callouts and life-safety alerts.
    - **Mitteaktiivne (Inactive):** Neutral Grey (#6B7280) denotes off-duty status or secondary information.

Maintain high contrast ratios (minimum 4.5:1) for all text against backgrounds to ensure readability in direct sunlight.

## Typography

This design system utilizes **Inter** for its exceptional legibility and neutral, systematic tone. The hierarchy is intentionally "top-heavy," using bold weights for status updates and mission-critical data.

- **Headlines:** Use `headline-md` for screen titles like "Aktiivsed väljakutsed" (Active calls).
- **Status Emphasis:** Labels for priority levels (e.g., "KRIITILINE") should use `label-bold` with high-contrast color backing.
- **Readability:** Body text uses a slightly increased line-height to ensure that even in vibrating or unstable environments (like a rescue boat), the text remains scannable.
- **Language Support:** Full support for Estonian glyphs (ä, ö, ü, õ) is mandatory across all weights.

## Layout & Spacing

The layout employs a **Fluid Grid** with a strong emphasis on vertical stacking to facilitate easy one-handed scrolling on mobile devices.

- **Safe Zones:** A 16px horizontal margin (container-padding) is standard for all screens.
- **Rhythm:** A 4px baseline grid ensures consistent vertical alignment. Use 12px (`stack-gap`) between related items in a list and 24px (`section-margin`) between distinct functional blocks.
- **Touch Targets:** For critical actions like "Vasta väljakutsele" (Respond to call), buttons must adhere to a minimum 48px height, though 56px is preferred for primary emergency actions to accommodate gloved hands or wet screens.
- **Information Density:** Use generous whitespace (24px+) around primary call-to-action cards to prevent accidental taps during high-stress maneuvers.

## Elevation & Depth

To maintain a professional and structured feel, the design system uses **Tonal Layers** combined with **Ambient Shadows**.

- **Level 0 (Background):** Solid white or #F9FAFB.
- **Level 1 (Cards/Surface):** White background with a subtle 1px border (#E5E7EB) and a soft, low-opacity shadow (Y: 2px, Blur: 4px, Opacity: 5%). This is the standard container for "Väljakutse info" (Call info).
- **Level 2 (Active/Floating):** Used for bottom navigation bars and floating action buttons. These use a more pronounced shadow (Y: 4px, Blur: 12px, Opacity: 10%) to appear physically closer to the user.
- **Interactive States:** On press, elements should visually "sink" (reduce elevation) or change fill color to provide immediate tactile feedback.

## Shapes

The shape language is **Rounded**, using a 12px-16px radius to strike a balance between modern friendliness and professional structure.

- **Standard Elements:** Use 8px (rounded) for small input fields and secondary buttons.
- **Primary Cards & Large Buttons:** Use 16px (rounded-xl) for main information containers and "Reageerin" (I am responding) buttons. This creates a large, inviting surface area that feels physically substantial.
- **Status Badges:** Use a fully pill-shaped (rounded-full) radius to distinguish them from interactive buttons.

## Components

### Buttons
- **Primary (Emergency):** Solid Deep Sea Blue or Emergency Red. Heavy 56px height. Text: Bold, Uppercase.
- **Secondary:** Calm Sky Blue background with Deep Sea Blue text. Used for "Märgi varustus" (Mark equipment).

### Status Badges
- High-visibility markers with a left-aligned icon and bold text. Example: A green circle icon followed by "VALVES" (On duty).

### Information Cards
- Containers for callout details. Header area features the priority color as a 4px left-border accent to quickly communicate urgency at a glance.

### Organization Switcher
- Located in the top header. A compact, borderless dropdown menu that displays the current station or unit (e.g., "Tallinna Vabatahtlik Merepääste").

### Bottom Navigation
- Uses persistent icons with `label-md` text. Active states are indicated by the Deep Sea Blue color and a subtle top-border highlight on the active icon.

### Input Fields
- Structured with clear labels above the field. High-contrast 1.5px borders when focused to ensure the user knows exactly where they are typing, even in low-light conditions.