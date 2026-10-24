# Golf Lab — Design Brief

This document defines the visual language for Golf Lab. Reference it when building
any UI. Follow the principles and tokens exactly. Do not invent new colors, fonts,
or component patterns without justification.

---

## Aesthetic Direction

**Dark-only, data-dense, analytically precise.** The app embraces a Robinhood-inspired
aesthetic: pure black backgrounds with bold green accents, tight spacing, and stock-market
data clarity. Designed for quick scanning and outdoor OLED readability.

Dark mode is the only mode. Pure black (#000000) backgrounds create stunning OLED contrast
and superior outdoor readability on golf courses in bright sunlight.

Inspired by: Robinhood, stock trading apps, Apple Fitness, precision data dashboards.
Not inspired by: light-mode productivity apps, traditional golf scorecards, pastel themes.

---

## Color

Pure black backgrounds (#000000) with vibrant green accents. All surfaces float on black
with subtle borders for depth. High contrast ratios throughout for outdoor legibility.

### Background tokens

```swift
// Page / screen background — pure black
Color(hex: "#000000")        // bgPrimary

// Card / panel background
Color(hex: "#1C1C1E")        // bgCard

// Elevated / inactive surfaces (stepper buttons, pill backgrounds)
Color(hex: "#2C2C2E")        // bgElevated
```

### Border tokens

```swift
// Default border (subtle white)
Color.white.opacity(0.08)    // borderDefault

// Accent border (highlighted panels, active toggles)
Color(hex: "#00C805").opacity(0.25)  // borderAccent

// Penalty border
Color(hex: "#FF453A").opacity(0.28)  // borderPenalty
```

### Text tokens

```swift
Color(hex: "#FFFFFF")        // textPrimary   (pure white, max contrast)
Color(hex: "#AEAEB2")        // textSecondary  (one step above system gray)
Color(hex: "#8E8E93")        // textTertiary   (labels and captions)
```

### Accent — bold green primary

```swift
Color(hex: "#00C805")        // accent          (Robinhood green — primary)
Color(hex: "#5AC53B")        // accentMid       (lighter green, positive trends)
Color(hex: "#00C805").opacity(0.12)  // accentDim       (toggle/panel backgrounds)
Color(hex: "#00C805").opacity(0.06)  // accentDimmer    (very subtle fills)
Color(hex: "#00C805").opacity(0.45)  // accentTrack     (goal, par, and hole progress bars)
Color(hex: "#000000")        // ctaOnAccent     (text on green buttons — black)
```

The accent color is vibrant and used for: CTAs, under-par scores, active states, 
improving trends. High contrast against pure black creates instant hierarchy.

### Semantic score colors

Used exclusively for score-vs-par displays. Do not use for general UI.

```swift
Color(hex: "#5AC53B")        // eagle/birdie (−2, −1) — lighter green
Color(hex: "#00C805")        // birdie strong emphasis — accent green
Color(hex: "#636366")        // par (E) — neutral tertiary
Color(hex: "#FF453A")        // bogey/double+ (+1, +2) — Apple system red
Color(hex: "#FF375F")        // double-bogey strong — deeper red
```

### Chart line colors

Encode meaning with high contrast:

- Under-par / improving metrics: accent #00C805
- Neutral / steady metrics: secondary #AEAEB2
- Over-par / negative trends: red #FF453A

### Extended chart palette (multi-series differentiation)

For complex charts with multiple data series, use these Apple Fitness-inspired colors:

```swift
Color(hex: "#30D5C8")        // chartCyan     — distance, pace, yardage
Color(hex: "#FF2D55")        // chartMagenta  — penalty emphasis, hazards
Color(hex: "#FFD60A")        // chartYellow   — par baseline, neutral
Color(hex: "#BF5AF2")        // chartPurple   — practice data, putting
Color(hex: "#FF9F0A")        // chartOrange   — peak performance, best rounds
```

Each includes a 20% opacity fill variant (e.g., `chartCyanFill`, `chartPurpleFill`) 
for stock-style gradient area fills under line charts.

**Usage:**
- Multi-line charts comparing different metrics (distance vs score vs putts)
- Practice vs round differentiation (purple vs green)
- Par baseline overlays (yellow for neutral reference line)
- Peak performance highlights (orange markers for season bests)

All colors tested for OLED contrast against pure black backgrounds.

### Weekly goals / streak

Progress bars stay accent green. Met-week circles, the flame, and the streak caption use hierarchy tertiary (orange). Confetti stays green.

```swift
Color(hex: "#FF9F0A")        // hierarchyTertiary — met week circle, flame, streak caption
Color(hex: "#00C805")        // streakSuccess      — celebration / confetti green
Color(hex: "#5AC53B")        // streakSuccessDeep  — confetti accents
Color(hex: "#000000")        // streakOnSuccess    — checkmark on orange circles
```

**Week history row** (horizontal scroll, oldest → newest, labels `W1`, `W2`, …):

| State                                   | Visual                                                            |
| --------------------------------------- | ----------------------------------------------------------------- |
| Met (past or current week)              | 28pt circle, hierarchy tertiary fill, black checkmark |
| Missed (finished week only)             | 28pt circle, `bgElevated` fill, white ×            |
| In progress (current week, not yet met) | 28pt circle, `bgElevated` fill, white `ellipsis`   |

Connectors between nodes: 2pt × 10pt `bgElevated` bars, vertically aligned to circle centers.
Auto-scroll to the newest week on appear.

**Streak footer:** `flame.fill` (hierarchy tertiary) + footnote caption (hierarchy tertiary).

**Weekly goal completion celebration** (app-root overlay on `MainTabView`):

- Full-screen confetti (green particles) — **off** when Reduce Motion is enabled.
- Top banner: "Weekly goals complete" + short copy that targets were met **this week**.
- Haptics: `.success` notification, then `.medium` impact ~120ms later.
- Once per calendar week; queued if a sheet would hide the overlay.

---

## Typography

Two fonts only. No exceptions.

**IBM Plex Mono** — numbers, stat values, the wordmark, score badges, time/date
metadata. Monospaced type gives numeric data analytical weight and makes values
instantly legible at a glance. Do not use Mono for labels, navigation, or prose.

**IBM Plex Sans** — everything else: field labels, toggle labels, navigation,
tab labels, card titles, section headers, body copy, course names, descriptions.
Sans is the primary reading font. It keeps the app approachable.

### Type scale (reduced for data density)

```
Display   — Mono, 32pt, weight 600   — large stat values (round score, season avg)
Title     — Sans, 20pt, weight 600   — screen headings
Headline  — Sans, 17pt, weight 500   — card titles, section headers
Body      — Sans, 15pt, weight 400   — content, descriptions
Subhead   — Sans, 14pt, weight 500   — secondary labels, metadata
Caption   — Sans, 12pt, weight 500   — field labels (uppercase + tracking)
Eyebrow   — Sans, 11pt, weight 500   — dense uppercase chrome (tabs, chart titles)
Footnote  — Sans, 11pt, weight 400   — tertiary helper lines
Micro     — Mono, 10pt, weight 500   — badges, compact numeric meta
Axis      — Mono,  9pt, weight 400   — chart axis ticks
Nav title — Sans, 14pt, weight 600   — centered bar titles
Buttons   — Sans, 14pt, weight 600 / 500 — primary vs ghost CTAs
```

### Label convention

Field labels (Score, Putts, Stats): Sans, 12pt, weight 500, uppercase,
0.10em letter-spacing, textTertiary color.

Values below those labels: Mono, larger size and weight. The font contrast between
label (Sans) and value (Mono) creates the analytical feel.

---

## Layout & Spacing (moderate density)

Tighter spacing for data-dense, stock-app feel:

```
Horizontal inset: 18pt from screen edges (was 22pt)
Card internal padding: 12pt vertical, 12pt horizontal (was 14pt)
Gap between sections: 16–20pt (was 20–24pt)
Gap within a card: 6–10pt (was 8–12pt)
```

No decorative dividers. Separation comes from surface contrast (#1C1C1E on #000000)
plus 1px subtle white borders.

---

## Cards & Panels

Cards are data surfaces — clean, high-contrast, data-first.

```
Background:    bgCard (#1C1C1E)
Border:        1px solid, white at 8% opacity
Border radius: 12pt (increased for modern feel, was 8pt)
Padding:       12pt × 12pt (reduced from 14pt)
```

No shadows. Cards float on pure black — the contrast is the depth.

**Accent panel variant** — used for highlighted information:

```
Left border:   3pt, accent color at 60% opacity
Background:    bgCard
Border radius: 12pt
```

**Data grid variant** — for side-by-side stat displays:

```
Cells separated by 1px lines at borderDefault opacity
Overall container: 1px border, 12pt radius
Grid gap: 1px (creates hairline rules)
```

---

## Buttons

**Primary CTA:**

```
Background:    accent (#00C805)
Text:          #000000 (pure black for max contrast)
Font:          Sans, 14pt, weight 600, uppercase, 0.08em tracking
Border radius: 12pt
Height:        ~48pt (full-width preferred)
```

One primary button per screen. It should be obvious.

**Secondary / ghost:**

```
Background:    transparent
Border:        1px, borderDefault (white at 8%)
Text:          textSecondary
Font:          Sans, 14pt, weight 500
Border radius: 12pt
```

---

## Steppers (numeric input)

Used for entering scores and counts.

```
Container:     bgCard, 1px border, 12pt radius, full width
− / + buttons: bgElevated (#2C2C2E), 56pt × 56pt tap target
Value:         Mono, 32pt, weight 600, centered, textPrimary
Sub-label:     Sans, 11pt, textTertiary, uppercase
```

Buttons must be large enough for one-handed use with a glove.
Haptic feedback on every increment/decrement (light impact).

---

## Toggles (binary stat selection)

Used for per-hole stat entry (GIR, FIR, Penalty).

```
Default (off):
  Background:    bgCard (#1C1C1E)
  Border:        1px, borderDefault
  Border radius: 12pt

Active (on) — positive stat (GIR, FIR):
  Background:    accent at 6% opacity
  Border:        1px, borderAccent (accent at 25% opacity)
  Label color:   accent (#00C805)

Active (on) — penalty stat:
  Background:    #FF453A at 8% opacity
  Border:        1px, #FF453A at 28% opacity
  Label color:   #FF453A
```

Active indicator: small filled circle (8pt) top-right corner of toggle.
Transition: 150ms, ease-in-out on background and border color.

---

## Charts

Chart lines:

```
Stroke width:  2.5pt (increased from 1.5pt for boldness)
Linecap:       round
Linejoin:      round
Terminal dot:  4pt radius, filled
```

**Gradient fill below line (stock-app style):**

```
Linear gradient, vertical, under solid lines except vs-par progression charts (line only)
Top of the plot: line color at 50% opacity
Mid: line color at 18%, then 4%
Bottom: line color at 0% opacity
```

Grid lines (subtle, horizontal only):

```
Stroke: white at 8% opacity, 1pt
Minimal — use sparingly for readability
```

Chart card header row:

```
Padding:       10pt × 12pt (reduced from 11pt × 14pt)
Border-bottom: borderDefault
Title:         Sans, 11pt, weight 500, uppercase, textTertiary
Current value: Mono, 11–12pt, weight 600, accent or textSecondary
```

---

## Filters / Segment Controls

Pill-style, not native segmented control:

```
Active pill:
  Background:    accent at 12% opacity
  Border:        1px, borderAccent
  Text:          accent, Sans, 11pt, weight 600, uppercase, 0.08em tracking
  Border radius: 8pt

Inactive pill:
  Background:    transparent
  Border:        1px, borderDefault
  Text:          textTertiary, Sans, 11pt
  Border radius: 8pt
```

---

## Tab Bar

```
Background:    bgCard (#1C1C1E)
Border-top:    1px, borderDefault
Tab icons:     16pt × 16pt SF Symbols, monochrome
Active tab:    accent color icon + label, 3pt dot indicator below label
Inactive tab:  icon + label at 30% opacity
Label font:    Sans, 11pt, 0.06em tracking
```

No background highlight on active tab. The icon color and dot do the work.

---

## Motion & Haptics

Keep animations purposeful and brief.

```
Chart line draw-in:    stroke-dasharray animation, left to right, 600ms, ease-out
Toggle state change:   150ms, background + border color transition
Button press:          scale(0.97), 100ms
Screen transitions:    SwiftUI default push/pop
```

Haptics:

- Stepper increment/decrement: `UIImpactFeedbackGenerator(.light)`
- Hole save confirm: `UINotificationFeedbackGenerator(.success)`
- Penalty toggle activation: `UIImpactFeedbackGenerator(.medium)`
- Weekly goals completed: `.success` notification, then `.medium` impact

---

## What to Avoid

- **No light mode** — dark-only, always pure black backgrounds
- **No thin borders** — always 1px at 8% white opacity
- **No small corner radius** — 12pt minimum for modern feel
- **No heavy shadows or elevation** — flat surfaces only
- **No decorative gradients** except functional chart fills
- **No multiple accent colors** — one bold green throughout
- **No pastel or muted accents** — high contrast required
- **No Mono font for labels** — Sans only for UI copy
- **No decorative icons** — simple SF Symbols only

---

## How to Use This Document with Cursor

Canonical copies in this repo:

- `docs/design.md` — full design brief (this file).
- `docs/DESIGN_REFERENCE.md` — implementation digest.

When asking Cursor to build a screen or component:

> "Build [screen name] following the Robinhood dark theme in `docs/design.md`.
>  Use pure black backgrounds, bold green accents, and the moderate density spacing."

For specific components:

> "Build a stat card following the dark theme specs in `docs/design.md`.
>  Use 12pt card padding and 12pt corner radius."

When Cursor drifts from the spec:

> "This doesn't match `docs/design.md` — you used light backgrounds.
>  The theme is dark-only with pure black (#000000). Fix it."
