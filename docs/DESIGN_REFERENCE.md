# GolfLab — design reference (implementation digest)

**Authoritative prose + examples:** `docs/design.md` (full brief).

**This file:** quick token tables, layout numbers, and component rules for day-to-day SwiftUI work.

---

## 1. Direction (one line)

**Dark-only**, pure black backgrounds, bold green accents, data-dense spacing; IBM Plex Sans for UI copy, IBM Plex Mono for numbers; Robinhood-inspired stock-app aesthetic; no shadows, borders for separation.

---

## 2. Color → Swift token map

Implement in `GolfLab/DesignSystem/Colors.swift`.

| Token (brief) | Hex / value | Role |
|---------------|-------------|------|
| `bgPrimary` | `#000000` | Page / screen background (pure black) |
| `bgCard` | `#1C1C1E` | Cards, panels, off-state toggles |
| `bgElevated` | `#2C2C2E` | Stepper −/+, inactive pill surfaces |
| `borderDefault` | `Color.white.opacity(0.08)` | Default 1px borders |
| `borderAccent` | `#00C805` @ 25% | Active accent borders |
| `borderPenalty` | `#FF453A` @ 28% | Penalty borders |
| `textPrimary` | `#FFFFFF` | Primary text (pure white) |
| `textSecondary` | `#8E8E93` | Secondary text (Apple gray) |
| `textTertiary` | `#636366` | Labels, captions (muted) |
| `accent` | `#00C805` | Brand / CTAs / under-par (Robinhood green) |
| `accentMid` | `#5AC53B` | Positive trends, lighter accent |
| `accentDim` | `#00C805` @ 12% | Active panels, filter bg |
| `accentDimmer` | `#00C805` @ 6% | Subtle fills |
| `ctaOnAccent` | `#000000` | Text on green button (black) |
| **Score-only** | | *Never use for general chrome* |
| `chartPositive` | `#00C805` | Under-par series |
| `chartNegative` | `#FF453A` | Over-par series (Apple red) |
| `chartNegativeStrong` | `#FF375F` | Double-bogey+ |
| `chartNeutral` | `#8E8E93` | Steady series |
| **Extended chart palette** | | *Multi-series, data emphasis* |
| `chartCyan` | `#30D5C8` | Distance, pace, yardage trends |
| `chartMagenta` | `#FF2D55` | Penalty emphasis, focus metrics |
| `chartYellow` | `#FFD60A` | Par baseline, neutral trends |
| `chartPurple` | `#BF5AF2` | Practice data, putting stats |
| `chartOrange` | `#FF9F0A` | Peak performance, best rounds |
| **Weekly goals** | | *Consistent with main accent* |
| `streakSuccess` | `#00C805` | Met week circle, flame (green) |
| `streakSuccessDeep` | `#5AC53B` | Confetti particles |
| `streakOnSuccess` | `#000000` | Checkmark on green circles (black) |
| `streakTextActive` | `#00C805` | Streak footer (green) |
| **Calendar** | | |
| `calendarRoundDot` | `#00C805` | Round completion (green) |
| `calendarPracticeDot` | `#636366` | Practice session (muted gray) |

---

## 3. Typography

**Fonts:** IBM Plex Sans (UI), IBM Plex Mono (numbers, wordmark, axes, badges).

**Scale (reduced for density)**

| Style | Font | Size | Weight | Use |
|-------|------|------|--------|-----|
| Display | Mono | 32 | 600 | Round score, big stats (reduced from 34) |
| Title | Sans | 20 | 600 | Screen titles (reduced from 22) |
| Headline | Sans | 17 | 500 | Card titles, sections (reduced from 18) |
| Body | Sans | 15 | 400 | Body, descriptions (reduced from 16) |
| Subhead | Sans | 14 | 500 | Secondary labels |
| Caption | Sans | 12 | 500 | Field labels (uppercase + tracking) |
| Eyebrow | Sans | 11 | 500 | Dense uppercase chrome |
| Footnote | Sans | 11 | 400 | Compact tertiary lines |
| Micro | Mono | 10 | 500 | Badges, tiny meta |
| Axis | Mono | 9 | 400 | Chart axes |
| Nav title | Sans | 14 | 600 | `GLScreenTopBar` center title |
| Button primary | Sans | 14 | 600 | Full-width primary CTAs |
| Button secondary | Sans | 14 | 500 | Ghost secondary CTAs |
| Filter pills | Sans | 11 | 600 / 500 | Active / inactive pills |

**Field labels:** Sans 12 / 500, uppercase, **0.10em** tracking, `textTertiary`. **Values:** Mono, heavier.

Implement in `GolfLab/DesignSystem/Typography.swift`: `Font.gl*` tokens.

---

## 4. Layout & radii (moderate density)

| Constant | Value | Notes |
|----------|--------|-------|
| Screen horizontal inset | **18pt** | Reduced from 22pt |
| Card padding | **12pt** × **12pt** | Reduced from 14pt |
| Section gap | **16–20pt** | Reduced from 20–24pt |
| Intra-card gap | **6–10pt** | Reduced from 8–12pt |
| Card / button / stepper / toggle radius | **12pt** | Increased from 8pt for modern feel |
| Filter pill radius | **8pt** | Increased from 6pt |
| Tab bar content top padding | **10pt** | Reduced from 12pt |
| Tab bar scroll bottom margin | **16pt** | Reduced from 20pt |
| Sheet content bottom padding | **28pt** | Reduced from 32pt |

No decorative dividers; separation = surface contrast + **1px** borders. **No shadows.**

---

## 5. Components (build checklist)

| Component | Spec location | Notes |
|-----------|---------------|--------|
| Card | Cards & Panels | #1C1C1E card, 1px white @ 8%, 12pt radius |
| Accent panel | Cards & Panels | 3pt left border, accent @ 60% |
| Data grid | Cards & Panels | 1px cell rules, 1px gap |
| Primary button | Buttons | Green fill, black text, ~48pt tall, 12pt radius |
| Secondary button | Buttons | Ghost + borderDefault, 12pt radius |
| Stepper | Steppers | 56×56 controls, 32pt mono value, light haptic |
| Stat toggles | Toggles | On-state fills + borders; 8pt dot; 150ms ease; 12pt radius |
| Charts | Charts | 2.5pt stroke, 20% gradient fill (stock-app style) |
| Filters | Filters | Custom pills, 8pt radius |
| Tab bar | Tab Bar | #1C1C1E bar, SF Symbol icons, green dot active |

### 5.1 SwiftUI central components (`GolfLab/DesignSystem`)

| Pattern | Where | Use |
|---------|--------|-----|
| `GLScreenTopBar` | `GLChrome.swift` | Centered **14pt semibold** title with **68pt** leading/trailing columns (reduced from 72pt). |
| `GLHubRootTopBar` | `GLChrome.swift` | **Golf Lab** wordmark (mono, accent green) + trailing hub title. |
| `GLTopBarMetrics` | `GLChrome.swift` | Tighter top padding (4pt screenRoot, 16pt sheet). |
| `GLPrimaryCTAButton` | `GLButtonStyles.swift` | Green fill, black text, **48pt**, uppercase, tracking, 12pt radius. |
| `GLSecondaryGhostButton` | `GLButtonStyles.swift` | Ghost secondary with white @ 8% border, 12pt radius. |
| `GLFormFieldLabel` | `GLFormChrome.swift` | Uppercase caption label (12pt, 0.10em tracking). |
| `GLTrendCardHeader` | `Typography.swift` | 11pt uppercase chart title + hairline. |
| `GLStatSummaryTile` | `Typography.swift` | 2×2 summary cell: micro label + mono value. |
| `WeeklyGoalsStreakSection` | `Views/Components/` | Home + History: round/practice bars (green), week scroll row (green circles). |
| `WeeklyGoalCelebrationOverlay` | `Views/Components/` | Root overlay: banner + green confetti. |

**Navigation split:** Tab roots use **hidden** `NavigationStack` chrome and the components above. Pushed editors may use visible `navigationTitle` / toolbar.

**Weekly goals logic:** `GLWeeklyGoalsStreak.swift`, `WeeklyGoalCelebration.swift`, `RoundStore` queues overlay.

---

## 6. Motion & haptics

| Interaction | Spec |
|-------------|------|
| Chart draw-in | 600ms ease-out, stroke-dash |
| Toggle | 150ms ease-in-out (bg + border) |
| Button press | scale **0.97**, **100ms** |
| Navigation | Default SwiftUI push/pop |
| Stepper ± | `.light` impact |
| Hole saved | `.success` notification |
| Penalty on | `.medium` impact |
| Weekly goals complete | `.success` notification, then `.medium` impact (~120ms later) |

---

## 7. Accessibility & product constraints

- **Outdoor / sunlight:** pure black backgrounds and high-contrast green/white text optimized for OLED + bright conditions.
- **Dark-only** — no light theme. Pure black (#000000) always.
- **Dynamic Type:** brief uses fixed pt sizes — preserve hierarchy when adopting Dynamic Type.

---

## 8. Platform

| Area | Note |
|------|------|
| iPhone | Primary target. |
| watchOS | Reuses spirit (legibility, green accent, no decorative chrome). See `WatchPalette.swift` for token mapping. |

---

## 9. Anti-patterns (short list)

Light backgrounds · pure white cards on light bg · small corner radius (< 12pt) · shadows · heavy gradients · multiple accent colors · thin borders (< 8% opacity) · Mono on labels · decorative tab icons · pastel colors · amber/gold separate palette.

---

## Revision log

| Date | Change |
|------|--------|
| 2026-10-16 | **Robinhood dark theme rewrite:** pure black backgrounds, bold green accents (#00C805), moderate density (18pt inset, 12pt card padding, reduced typography), 12pt corner radius, Apple system red for penalties, consistent green weekly goals (removed amber), muted gray practice dots, 20% gradient fills, watch palette updated. Dark-only, no light mode. |
