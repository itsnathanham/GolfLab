# Golf Lab — Design Brief

This document defines the visual language for Golf Lab. Reference it when building
any UI. Follow the principles and tokens exactly. Do not invent new colors, fonts,
or component patterns without justification.

---

## Aesthetic Direction

Light-first, data-rich, analytically precise. The app should feel closer to a
well-designed financial dashboard than a sports or fitness app. Clean, considered,
nothing decorative that doesn't earn its place. Approachable but not casual.

Light mode is the primary and only mode. The app is used outdoors in sunlight —
legibility on-course takes priority over dark-mode aesthetics.

Inspired by: precision instruments, high-quality data tools, clean editorial design.
Not inspired by: gamified fitness apps, sports scoreboards, dark developer tools.

---

## Color

All backgrounds use light green-tinted surfaces — not pure white, not neutral gray.
The tint is subtle and grounds the app in its context without being literal about it.

### Background tokens

```swift
// Page / screen background
Color(hex: "#F4F6F4")        // bg-primary

// Card / panel background
Color(hex: "#FFFFFF")        // bg-card

// Elevated / inactive surfaces (stepper buttons, pill backgrounds)
Color(hex: "#EAEEEA")        // bg-elevated
```

### Border tokens

```swift
// Default border (very subtle)
Color.black.opacity(0.07)    // border-default

// Accent border (highlighted panels, active toggles)
Color(hex: "#19693A").opacity(0.25)  // border-accent

// Penalty border
Color(hex: "#C0412D").opacity(0.28)  // border-penalty
```

### Text tokens

```swift
Color(hex: "#111A13")        // text-primary   (near-black, slight green warmth)
Color(hex: "#4A6655")        // text-secondary  (muted green-gray)
Color(hex: "#8FA898")        // text-tertiary   (very muted, labels and captions only)
```

### Accent — single brand color

```swift
Color(hex: "#19693A")        // accent          (deep forest green — primary)
Color(hex: "#22874E")        // accent-mid      (slightly lighter, positive deltas)
Color(hex: "#19693A").opacity(0.08)  // accent-dim      (toggle/panel backgrounds)
Color(hex: "#19693A").opacity(0.04)  // accent-dimmer   (very subtle fills)
```

The accent color appears sparingly: active states, key improving metrics, chart
lines for improving trends, CTAs, the wordmark. Everything else is muted.
One accent doing all the work is more powerful than many colors competing.

### Semantic score colors

Used exclusively for score-vs-par displays. Do not use for general UI.

```swift
Color(hex: "#9A7020")        // eagle (−2 or better) — dark gold
Color(hex: "#19693A")        // birdie (−1) — accent green
Color(hex: "#8FA898")        // par (E) — neutral tertiary
Color(hex: "#C05020")        // bogey (+1) — warm orange
Color(hex: "#C0412D")        // double-bogey or worse (+2 and beyond) — red
```

### Chart line colors

Encode meaning, not identity:

- Improving metrics (lower score, more GIR): accent #19693A
- Neutral / steady metrics: secondary #4A6655
- Negative trend indicators: bogey #C05020

### Weekly goals / streak (habit lane)

A **second, sparing palette** for the Home + History **Weekly goals** card and completion
celebration only. It signals habit momentum (weeks met), not score-vs-par. Do not use these
tokens for scorecards, charts, or general CTAs.

Progress bars inside the card still use **accent** green — only the week history row and streak
footer use gold.

```swift
Color(hex: "#D4952A")        // streak-success     — met week circle, flame (active streak)
Color(hex: "#9A7020")        // streak-success-deep — confetti accent (eagle-gold family)
Color(hex: "#FFFBF3")        // streak-on-success  — checkmark on amber circles
Color(hex: "#8F6420")        // streak-text-active — streak caption when streak > 0
```

**Week history row** (horizontal scroll, oldest → newest, labels `W1`, `W2`, …):


| State                                   | Visual                                                            |
| --------------------------------------- | ----------------------------------------------------------------- |
| Met (past or current week)              | 28pt circle, `streak-success` fill, `streak-on-success` checkmark |
| Missed (finished week only)             | 28pt circle, `bg-elevated` fill, `streak-on-success` ×            |
| In progress (current week, not yet met) | 28pt circle, `bg-elevated` fill, `streak-on-success` `ellipsis`   |


Connectors between nodes: 2pt × 10pt `bg-elevated` bars, vertically aligned to circle centers.
Auto-scroll to the newest week on appear.

**Streak footer:** `flame.fill` (`streak-success`, full opacity) + footnote caption (`streak-text-active`).

**Weekly goal completion celebration** (app-root overlay on `MainTabView`):

- Full-screen confetti (gold / deep gold / `accent-mid` / practice-blue particles) — **off**
when Reduce Motion is enabled.
- Top banner: “Weekly goals complete” + short copy that targets were met **this week** (not
round score). Optional streak line in `streak-text-active`.
- Haptics: `.success` notification, then `.medium` impact ~120ms later.
- Once per calendar week (`UserDefaults`); queued if a sheet (practice log / end round) or
background save would hide the overlay until dismiss or foreground.

---

## Typography

Two fonts only. No exceptions.

**IBM Plex Mono** — numbers, stat values, the wordmark, score badges, time/date
metadata. Monospaced type gives numeric data analytical weight and makes values
instantly legible at a glance. Do not use Mono for labels, navigation, or prose.

**IBM Plex Sans** — everything else: field labels, toggle labels, navigation,
tab labels, card titles, section headers, body copy, course names, descriptions.
Sans is the primary reading font. It keeps the app approachable.

```swift
// In SwiftUI — register as custom fonts or use fallbacks:
// IBM Plex Mono → fallback: .monospacedSystemFont
// IBM Plex Sans → fallback: .systemFont (SF Pro)
```

### Where each font applies

```
Mono:  stat values, round scores, averages, yardages, the wordmark,
       score badges (+14, −1), time displays, axis labels on charts

Sans:  screen titles, section labels, field labels (Score, Putts, GIR),
       toggle labels, tab bar labels, card header titles, body copy,
       course names, hole metadata labels, CTA button text, nav labels
```

### Type scale

```
Display   — Mono, 34pt, weight 600   — large stat values (round score, season avg)
Title     — Sans, 22pt, weight 600   — screen headings
Headline  — Sans, 18pt, weight 500   — card titles, section headers
Body      — Sans, 16pt, weight 400   — content, descriptions, insight copy
Subhead   — Sans, 14pt, weight 500   — secondary labels, metadata
Caption   — Sans, 12pt, weight 500   — field labels (uppercase + tracking)
Eyebrow   — Sans, 11pt, weight 500   — dense uppercase chrome (custom tab labels, chart card titles)
Footnote  — Sans, 11pt, weight 400   — tertiary helper lines under controls
Micro     — Mono, 10pt, weight 500   — badges, compact numeric meta
Axis      — Mono,  9pt, weight 400   — chart axis ticks (minimal)
Nav title — Sans, 14pt, weight 600   — centered bar titles (scorecard flows)
Buttons   — Sans, 14pt, weight 600 / 500 — primary vs ghost CTAs
```

### Label convention

Field labels (Score, Putts, Stats): Sans, 12pt, weight 500, uppercase,
0.10em letter-spacing, text-tertiary color.

Values below those labels: Mono, larger size and weight. The font contrast between
label (Sans) and value (Mono) creates the analytical feel without making labels feel
technical. Do not use Mono for the labels themselves.

---

## Layout & Spacing

Consistent horizontal inset: 22pt from screen edges.
Card internal padding: 14pt vertical, 14pt horizontal.
Gap between sections: 20–24pt.
Gap within a card between elements: 8–12pt.

No decorative dividers. Separation comes from the contrast between white card
surfaces and the off-white page background, plus 1px borders.

---

## Cards & Panels

Cards are data panels — clean and precise, but not cold.

```
Background:    bg-card (#FFFFFF)
Border:        1px solid, black at 7% opacity
Border radius: 8pt
Padding:       14pt × 14pt
```

No shadows. Cards sit on the slightly tinted page background — the contrast
is the separation.

**Accent panel variant** — used for highlighted information (e.g. hole header):

```
Left border:   3pt, accent color at 60% opacity
Background:    bg-card
Border radius: 8pt
```

**Data grid variant** — for side-by-side stat displays:

```
Cells separated by 1px lines at border-default opacity
Overall container: 1px border, 8pt radius
No zebra striping — borders provide the separation
```

---

## Buttons

**Primary CTA:**

```
Background:    accent (#19693A)
Text:          #F2F8F4 (near-white)
Font:          Sans, 14pt, weight 600, uppercase, 0.08em tracking
Border radius: 8pt
Height:        ~48pt (full-width preferred)
```

One primary button per screen. It should be obvious.

**Secondary / ghost:**

```
Background:    transparent
Border:        1px, border-default
Text:          text-secondary
Font:          Sans, 14pt, weight 500
Border radius: 8pt
```

No pill buttons. No gradient buttons.

---

## Steppers (numeric input)

Used for entering scores and counts.

```
Container:     bg-card, 1px border, 8pt radius, full width
− / + buttons: bg-elevated (#EAEEEA), 56pt × 56pt tap target
Value:         Mono, 34pt, weight 600, centered, text-primary
Sub-label:     Sans, 11pt, text-tertiary, uppercase
```

Buttons must be large enough for one-handed use with a glove.
Haptic feedback on every increment/decrement (UIImpactFeedbackGenerator, .light).

---

## Toggles (binary stat selection)

Used for per-hole stat entry (GIR, FIR, Penalty).

```
Default (off):
  Background:    bg-card (#FFFFFF)
  Border:        1px, border-default
  Border radius: 8pt

Active (on) — positive stat (GIR, FIR):
  Background:    accent at 4% opacity
  Border:        1px, border-accent (accent at 25% opacity)
  Label color:   accent (#19693A)

Active (on) — penalty stat:
  Background:    #C0412D at 8% opacity
  Border:        1px, #C0412D at 28% opacity
  Label color:   #C0412D
```

Active indicator: small filled circle (8pt) top-right corner of toggle.
Transition: 150ms, ease-in-out on background and border color.

Label: Sans, 12pt, weight 600. Labels are navigational, not data — use Sans.
Sub-label: Sans, 11pt, text-tertiary.

---

## Charts

Chart lines:

```
Stroke width:  1.5pt
Linecap:       round
Linejoin:      round
Terminal dot:  3pt radius, filled; 6pt radius outer ring at 12% opacity
```

Area fill below line:

```
Linear gradient, vertical
Top: line color at 14% opacity
Bottom: line color at 0% opacity
```

Grid lines (use sparingly):

```
Horizontal only
Stroke: black at 4% opacity, 1pt
```

Average reference line:

```
Stroke: black at 7% opacity, 1pt, dashed (4pt dash, 3pt gap)
```

Axis labels: Mono, 9pt, black at 18% opacity. Minimal — only min/max values.

Chart card header row:

```
Padding:       11pt × 14pt
Border-bottom: border-default
Title:         Sans, 11pt, weight 500, uppercase, text-tertiary (NOT Mono)
Current value: Mono, 11–12pt, weight 600, accent or text-secondary
```

---

## Filters / Segment Controls

Pill-style, not native segmented control:

```
Active pill:
  Background:    accent at 8% opacity
  Border:        1px, border-accent
  Text:          accent, Sans, 11pt, weight 600, uppercase, 0.08em tracking
  Border radius: 6pt

Inactive pill:
  Background:    transparent
  Border:        1px, border-default
  Text:          text-tertiary, Sans, 11pt
  Border radius: 6pt
```

---

## Tab Bar

```
Background:    bg-card (#FFFFFF)
Border-top:    1px, border-default
Tab icons:     18pt × 18pt SVG, 1–1.5pt stroke, no fill
Active tab:    accent color icon + label, 3pt dot indicator below label
Inactive tab:  icon + label at 30% opacity
Label font:    Sans, 11pt, 0.06em tracking (NOT Mono)
```

No background highlight on active tab. The icon color and dot do the work.

---

## Motion & Haptics

Keep animations purposeful and brief. Nothing decorative.

```
Chart line draw-in:    stroke-dasharray animation, left to right, 600ms, ease-out
Toggle state change:   150ms, background + border color transition
Button press:          scale(0.97), 100ms
Screen transitions:    SwiftUI default push/pop — no custom overrides
```

Haptics:

- Stepper increment/decrement: `UIImpactFeedbackGenerator(.light)`
- Hole save confirm: `UINotificationFeedbackGenerator(.success)`
- Penalty toggle activation: `UIImpactFeedbackGenerator(.medium)`
- Weekly goals completed (overlay): `.success` notification, then `.medium` impact

---

## What to Avoid

- **No dark backgrounds** — light mode only, always
- **No pure white page backgrounds** — always use #F4F6F4 for the page surface
- **No shadows** — separation comes from surface contrast and 1px borders
- **No pill-shaped buttons or cards** — 8pt radius maximum
- **No gradients** except the chart area fill (functional, not decorative)
- **No multiple accent colors** — one deep green for product chrome; **exception:** weekly-goals
gold tokens (`streak-success` family) on the Weekly goals card and completion overlay only
- **No system blue** anywhere in the UI
- **No heavy borders** — 1px at low opacity only
- **No Mono font for labels** — Sans only for field labels, toggle labels, tab
labels, section headers, card titles, and navigation. Mono is for numbers
and the wordmark only.
- **No SF Pro** — always use IBM Plex Mono or IBM Plex Sans
- **No decorative icons** — tab bar icons should be simple stroke-only SVGs
- **No card shadows or elevation effects** — flat surfaces only

---

## How to Use This Document with Cursor

Canonical copies in this repo:

- `**docs/design.md`** — full design brief (this file).
- `**docs/DESIGN_REFERENCE.md**` — implementation digest (tokens, spacing, component checklist).

When asking Cursor to build a screen or component:

> "Build [screen name] following the design system in `docs/design.md`.
>  Use the color tokens, typography rules, and component patterns defined there.
>  Do not add any colors, fonts, or visual treatments not specified in the brief."

For specific components:

> "Build a stat card following the card and data grid specs in `docs/design.md`.
>  Use IBM Plex Sans for the label and IBM Plex Mono for the value."

> "Build a numeric stepper following the stepper spec in `docs/design.md`.
>  Include haptic feedback on increment and decrement."

When Cursor drifts from the spec:

> "This doesn't match `docs/design.md` — you used Mono for the field label.
>  Labels use IBM Plex Sans. Fix it to match the spec."

