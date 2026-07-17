# CoffeeGrams — Design System (spec, pending implementation)

**Status:** Requirements captured 2026-07-17. To be implemented in two parts:
- **Foundation** (color tokens + typography, applied to current screens) — *before M6*.
- **Rich assets** (custom method icons, motion, app icon, launch screen) — *M11*.

This is the source of truth for the app's visual language. Implement colors as
semantic tokens (Asset Catalog color sets + a `Color` theme extension), never as
hardcoded hex in views.

## Brand palette & the 60-30-10 rule

| Share | Role | Color (brand name) | Usage |
|---|---|---|---|
| **60%** | Background | **Cream** | App background, cards, readable surfaces |
| **30%** | Primary text / surfaces | **Espresso Brown** | Headings, body text, primary UI |
| **10%** | Accent / actions | **Caramel / Warm Gold** | Primary buttons, active timer, key accents only |
| (muted) | Secondary text | **Medium Roast Taupe** | Low-priority labels (tips, notes) — a desaturated step of the Espresso Brown, *not* a new hue |

**Avoid over-coloring:** gold stays ~10%, reserved for primary actions and the
active-timer state. Everything else is cream / espresso / taupe.

### Semantic tokens to define (light + dark variants each)
- `color.background` — cream
- `color.surface` — cream/near-cream card fill
- `color.textPrimary` — espresso brown
- `color.textSecondary` — medium roast taupe
- `color.accent` — caramel gold (filled buttons)
- `color.timerActive` — a **deeper** gold for large numerals (see contrast note)

## Typography
- Large, legible text per Apple HIG. Body uses the system font (SF Pro) with
  **Dynamic Type** support so text scales with the user's accessibility setting.
- Result numerals: large, rounded (currently 48pt) — scale with Dynamic Type
  where layout allows.
- Optional branded display font for the wordmark/headings — TBD at M11.

## Timer active state (approved)
- When a phase is counting down, shift the large clock numerals from **Espresso
  Brown → Caramel/Deeper Gold** as a peripheral "running" signal.
- **Accessibility guard:** pair the color change with a redundant non-color cue
  (subtle pulse/scale animation or a "RUNNING" caption). HIG: never rely on color
  alone to convey state.
- **Contrast:** vibrant caramel on cream can fail the 3:1 minimum for large text.
  Use a deeper gold for numerals; reserve the brightest gold for filled buttons
  with dark-brown labels.

## Iconography — NO GIFs (decision)
GIFs are the wrong format for a premium iOS app: 256-color, heavy, choppy loops,
no native SwiftUI support, battery cost. Instead:
- **Method icons** (Chemex, V60, AeroPress, French Press, Cold Brew, Espresso):
  a cohesive **custom vector line-icon set** (SVG/PDF in the asset catalog, or
  SwiftUI `Path`s). Crisp at any size, tiny, tintable with the palette. A small
  icon sits next to each method name in the picker and calculator header.
- **Water / pour motion** (if desired): native SwiftUI animation (a filling
  shape) or **Lottie** (vector JSON) — the premium standard, not GIF.
- **SF Symbols** as immediate placeholders until the custom set exists.

## Accessibility (also an App Store review concern)
- Support **Dynamic Type**; verify layouts at the largest sizes.
- Contrast: small text ≥ 4.5:1, large text ≥ 3:1 — measure the gold/taupe
  combinations, don't eyeball them.
- Never convey state by color alone.
- Support **Dark Mode** — define dark variants for every token.

## Implementation sequencing
1. Design foundation (tokens + type) applied to `MethodPickerView` /
   `CalculatorView` — before M6.
2. M6 guided-brew timer built on the theme (gold active-state baked in).
3. M11: custom method icon set, optional Lottie motion, app icon, launch screen.
