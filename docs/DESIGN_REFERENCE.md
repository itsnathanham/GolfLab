# GolfLab — design reference (implementation digest)

**Authoritative prose + examples:** `docs/design.md` (full brief).

**This file:** quick token tables, layout numbers, and component rules for day-to-day SwiftUI work. When anything conflicts, **`docs/design.md` wins.** (Static HTML screen mocks lived under `docs/reference-html/` for the initial build only; those files were removed.)

---

## 1. Direction (one line)

Light-only, green-tinted surfaces, data-dashboard tone; IBM Plex Sans for UI copy, IBM Plex Mono for numbers only; one accent green, no shadows, borders for separation.

---

## 2. Color → Swift token map

Implement in `GolfLab/DesignSystem/Colors.swift` (names can match or alias these).

| Token (brief) | Hex / value | Role |
|---------------|-------------|------|
| `bgPrimary` | `#F4F6F4` | Page / screen background |
| `bgCard` | `#FFFFFF` | Cards, panels, off-state toggles |
| `bgElevated` | `#EAEEEA` | Stepper −/+, inactive pill surfaces |
| `borderDefault` | `Color.black.opacity(0.07)` | Default 1px borders |
| `borderAccent` | `#19693A` @ 25% | Active accent borders |
| `borderPenalty` | `#C0412D` @ 28% | Penalty borders |
| `textPrimary` | `#111A13` | Primary text |
| `textSecondary` | `#4A6655` | Secondary text |
| `textTertiary` | `#8FA898` | Labels, captions |
| `accent` | `#19693A` | Brand / CTAs / sparse emphasis |
| `accentMid` | `#22874E` | Positive deltas, lighter accent |
| `accentDim` | `#19693A` @ 8% | Active panels, active filter bg |
| `accentDimmer` | `#19693A` @ 4% | Positive toggle on-state bg |
| `ctaOnAccent` | `#F2F8F4` | Text on primary button |
| **Score-only** | | *Never use for general chrome* |
| `scoreEagle` | `#9A7020` | Eagle (−2 or better) |
| `scoreBirdie` | `#19693A` | Birdie (−1) |
| `scorePar` | `#8FA898` | Par (E) |
| `scoreBogey` | `#C05020` | Bogey (+1) |
| `scoreDouble` | `#C0412D` | Double+ |
| **Charts** | | |
| `chartImproving` | `#19693A` | Improving series |
| `chartNeutral` | `#4A6655` | Steady series |
| `chartNegative` | `#C05020` | Negative trend |
| **Weekly goals only** | | *Habit lane — not scorecard chrome* |
| `streakSuccess` | `#D4952A` | Met week circle, active flame |
| `streakSuccessDeep` | `#9A7020` | Confetti particles (eagle-gold family) |
| `streakOnSuccess` | `#FFFBF3` | Checkmark on amber circles |
| `streakTextActive` | `#8F6420` | Streak footer when streak > 0 |

**System blue:** do not use for app chrome (practice calendar dot `#4268AE` is History-only).

---

## 3. Typography

**Fonts:** IBM Plex Sans (UI), IBM Plex Mono (numbers, wordmark, chart axes, badges). Until custom fonts are bundled, brief allows fallbacks: Sans → system sans; Mono → monospaced system.

**Scale**

| Style | Font | Size | Weight | Use |
|-------|------|------|--------|-----|
| Display | Mono | 34 | 600 | Round score, big stats |
| Title | Sans | 22 | 600 | Screen titles |
| Headline | Sans | 18 | 500 | Card titles, sections |
| Body | Sans | 16 | 400 | Body, descriptions |
| Subhead | Sans | 14 | 500 | Secondary labels |
| Caption | Sans | 12 | 500 | Field labels (uppercase + tracking) |
| Eyebrow | Sans | 11 | 500 | Dense uppercase chrome (tabs, chart titles, stepper sub-labels) |
| Footnote | Sans | 11 | 400 | Compact tertiary lines |
| Micro | Mono | 10 | 500 | Badges, tiny meta |
| Axis | Mono | 9 | 400 | Chart axes, black @ 18% opacity |
| Nav title | Sans | 14 | 600 | `GLScreenTopBar` center title |
| Button primary | Sans | 14 | 600 | Full-width primary CTAs |
| Button secondary | Sans | 14 | 500 | Ghost secondary CTAs |
| Filter pills | Sans | 11 | 600 / 500 | Active / inactive segment-style pills |

**Field labels:** Sans 12 / 500, uppercase, **0.10em** tracking, `textTertiary`. **Values:** Mono, heavier — never Mono for the label row.

Implement in `GolfLab/DesignSystem/Typography.swift`: `Font.gl*` tokens map to the scale above (`glEyebrow`, `glFootnote`, `glNavTitle`, `glButtonPrimary`, …).

---

## 4. Layout & radii

| Constant | Value |
|----------|--------|
| Screen horizontal inset | **22pt** |
| Card padding | **14pt** × **14pt** |
| Section gap | **20–24pt** |
| Intra-card gap | **8–12pt** |
| Card / primary button / stepper / toggle radius | **8pt** |
| Filter pill radius | **6pt** |

No decorative dividers; separation = **bg** contrast + **1px** borders. **No shadows.**

---

## 5. Components (build checklist)

| Component | Spec location in `design.md` | Notes |
|-----------|------------------------------|--------|
| Card | Cards & Panels | White card, 1px `borderDefault`, 8pt radius |
| Accent panel | Cards & Panels | 3pt left, accent @ 60% |
| Data grid | Cards & Panels | 1px cell rules, no zebra |
| Primary button | Buttons | Accent fill, `ctaOnAccent` text, ~48pt tall |
| Secondary button | Buttons | Ghost + `borderDefault` |
| Stepper | Steppers | 56×56 controls, Display value, light haptic |
| Stat toggles | Toggles | On-state fills + borders; 8pt dot; 150ms ease |
| Charts | Charts | 1.5pt stroke, gradient fill, grid rules |
| Filters | Filters / Segment Controls | Custom pills, 6pt radius — not native segmented |
| Tab bar | Tab Bar | White bar, stroke icons, dot active indicator |

### 5.1 SwiftUI central components (`GolfLab/DesignSystem`)

| Pattern | Where | Use |
|---------|--------|-----|
| `GLScreenTopBar` | `GLChrome.swift` | Centered **14pt semibold** (`glNavTitle`) title with **72pt** leading/trailing columns (Scorecard, End round, Last round). |
| `GLHubRootTopBar` | `GLChrome.swift` | **Golf Lab** wordmark (mono) + trailing hub title or control (Home, Stats, History). |
| `GLTopBarMetrics` | `GLChrome.swift` | Shared top padding (`screenRoot` vs `sheet`) and nav bottom gap. |
| `GLPrimaryCTAButton`, `GLPrimaryCTACustomButton`, `GLSecondaryGhostButton` | `GLButtonStyles.swift` | Primary (**48pt**, uppercase, tracking) and ghost secondary per brief. |
| `GLSectionFieldHeading` | `GLFormChrome.swift` | Uppercase caption field labels above form blocks. |
| `GLFormFieldLabel` | `GLFormChrome.swift` | Inline caption label (uppercase, 0.10em tracking) — section rows, profile, bubble captions. |
| `GLTrendCardHeader` | `Typography.swift` | 11pt uppercase chart/table card title (`glEyebrow`) + hairline (`GLStatTrendCard`, Stats “avg by par”). |
| `GLStatSummaryTile` | `Typography.swift` | 2×2 summary cell: micro label + mono value only (Last round, End round, Home quick stats). |
| `GLStatStripCell` | `Typography.swift` | Micro label + mono value + optional “Vs season avg” footnote — Stats four-up strip. |
| `WeeklyGoalsStreakSection` | `Views/Components/WeeklyGoalsStreakSection.swift` | Home + History: round/practice bars (accent), week `Wn` scroll row, streak footer. |
| `WeeklyGoalCelebrationOverlay` | `Views/Components/WeeklyGoalCelebrationOverlay.swift` | Root overlay: banner + confetti when the current week newly completes. |
| `ConfettiEmitterView` | `Views/Components/ConfettiEmitterView.swift` | `CAEmitterLayer` burst; respects Reduce Motion. |

**Navigation split:** Tab roots (Home / Stats / History / Round flows above) use **hidden** `NavigationStack` chrome and the components above. **Pushed** editors and account (e.g. Profile, date picker, hole edit) may use **visible** `navigationTitle` / toolbar where system patterns help (Cancel/Done).

**Weekly goals logic:** `GLWeeklyGoalsStreak.swift` (snapshots + week history); `WeeklyGoalCelebration.swift` (once-per-week guard); `RoundStore` queues overlay after practice/round save.

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

- **Outdoor / sunlight:** prefer spec contrast; avoid thin low-contrast text on `bgPrimary`.
- **Light mode only** per brief (no dark theme requirement in v1).
- **Dynamic Type:** brief uses fixed pt sizes — when adopting Dynamic Type, preserve hierarchy (Display > Caption) and test field labels.

---

## 8. Platform

| Area | Note |
|------|------|
| iPhone | Primary target for this brief. |
| watchOS | Brief does not define Watch-specific tokens; reuse spirit (legibility, no decorative chrome) until a Watch addendum exists. |

---

## 9. Anti-patterns (short list)

Dark page bg · pure white **page** (use `#F4F6F4`) · shadows · pill **buttons** / pill **cards** · non-chart gradients · extra accent hues · heavy borders · Mono on labels · decorative tab icons.

---

## Revision log

| Date | Change |
|------|--------|
| 2026-04-18 | Imported brief from `DESIGN.md`; added digest + repo paths for Cursor. |
| 2026-05-06 | Typography scale nudge for legibility: larger body/caption/subhead, `glEyebrow` / `glFootnote` / nav & button tokens (`Typography.swift`). |
| 2026-05-20 | Weekly goals card: `streak-*` tokens, week history circles (met / missed / in-progress), completion overlay + confetti; documented in `design.md` § Weekly goals. Missed / in-progress: `bg-elevated` + white × or `ellipsis`; met: white check on amber. |
