# Future todos

Ideas and follow-ups that are **not** scheduled work—capture here so they are not lost.

---

## Current product backlog (phone + Watch test pass)

Ordered list from field testing. **Do these in sequence** unless a quick win is bundled.

| # | Item | Status |
|---|------|--------|
| 1 | **Typography** — larger central type scale (`Font.gl*`), hierarchy preserved; `docs/design.md` + `DESIGN_REFERENCE.md` updated | **Done** |
| 2 | **Profile in tab bar** — removed; profile only from Home → `NavigationLink` to `ProfileView` | **Done** |
| 3 | **Watch ↔ iPhone active round** — immediate merge of Watch saves; `WatchRoundState` push for current hole + saved holes; reachability / `onAppear` resync | **Done** |
| 4 | **Watch hole entry UX** — full-width score/putts steppers (44pt targets), stacked GIR/FIR/**Penalty** rows, “Save hole” CTA | **Done** |
| 5 | **iPhone tap targets** — hole steppers 62×62 −/+ with full-cell `contentShape`; stat toggles `minHeight` 68 | **Done** |
| 6 | **New Round** — tee row removed; course `TextField` uses `prompt` with `textSecondary` | **Done** |
| 7 | **History scorecard** — course name tap → sheet; Supabase `updateRoundCourseName` | **Done** |
| 8 | **New Round date picker sheet** — custom header + `preferredColorScheme(.light)` + `DatePicker` `tint` (no translucent nav chrome) | **Done** |
| 9 | **Chart intro animations** — `pauseBeforeLine`, slower line reveal, eased timing curve (`GLChartIntroAnimation` presets + `AccentSparklineIntroHost`) | **Done** |

**After the backlog:** consider items below in this file (9 vs 18 filter, GIR/FIR guardrails, branded loading, etc.). **Penalties — tracking and stats** is partially satisfied by per-hole penalty on phone + Watch; that section still applies if you want event types, counts in Stats, etc.

---

## Home / Stats — round length filter (9 vs 18 holes)

**Idea:** Add a separate control (in addition to season / last 10 / all time) to filter or segment metrics by **all rounds**, **9-hole rounds only**, or **18-hole rounds only**.

**Why:** Mixing 9- and 18-hole rounds in one average vs-par (and related trends) can obscure how someone actually plays; scores vs par also behave differently by round length and fatigue.

**Open decisions:**

- Add the filter on **Home** (top stat cards + chart), **or** leave Home unchanged and add this filter only on **Stats** for deeper analysis, **or** both with different defaults.
- Define behavior when a filter excludes all rounds (empty state copy).
- Align with any future normalization (e.g. per-hole rate) if you revisit how 9 vs 18 are compared.

**Status:** Consider / not implemented.

---

## Hole entry guardrails — GIR/FIR/putts/score constraints

**Todo:** Add validation/guardrails in Hole Entry to restrict invalid or inconsistent combinations across **GIR/FIR/putts/score**.

**Open decisions:**

- Rule set: define hard constraints (blocked save) vs soft warnings (allow override) for edge cases.
- GIR/FIR logic coupling: e.g. FIR unavailable on par 3, GIR implications by score/putts state, and handling partial edits.
- Putts vs score consistency: minimum/maximum relationships (e.g. putts cannot exceed score in valid saved state).
- Input bounds: realistic range limits per hole for score and putts, including recovery/penalty-heavy holes.
- UX behavior: inline helper text vs toast/alert, when to validate (live vs on save), and accessibility messaging.

**Status:** Consider / not implemented.

---

## Loading UI — branded experience

**Idea:** Replace basic loading states with a branded/fancier treatment (e.g. golf ball animation, wordmark motion, or subtle Golf Lab-themed loader) to improve perceived quality while data is preparing.

**Open decisions:**

- Visual direction: golf ball spin/bounce vs minimal brand pulse vs skeleton + branded accent.
- Reuse strategy: one shared loading component/tokenized style across Home, Stats, Round detail, and Last round summary.
- Performance/accessibility: keep animation lightweight, respect Reduce Motion, and preserve clear loading text for VoiceOver.
- Timing behavior: minimum display duration and crossfade rules to avoid flicker on very fast loads.

**Status:** Consider / not implemented.

---

## Round summary in History / Round detail

**Idea:** Add a richer **round summary experience** to History/scorecard views so users get more than hole-by-hole entries (e.g. round-level stats, context, and trend comparisons).

**Why:** The scorecard is useful for raw tracking, but users also need quick interpretation of what that round means (strengths, misses, and how it compares to their typical play).

**Open decisions:**

- Scope: what lives on `RoundDetailView` vs a dedicated round-summary subview/sheet (cards for score vs par, GIR%, FIR%, putts/hole, penalties when available).
- Comparison baseline for historical rounds: for a round played in **2025**, should "Season" mean 2025-only rounds, rolling trailing window, or current-season reference.
- Time-safety of metrics: ensure averages/trends are computed from rounds available **up to that round date** (avoid future-data leakage in historical comparisons).
- Trend method: define stable aggregation rules (per-round vs per-hole weighting, minimum sample size, and handling missing/partial hole records).
- 9 vs 18 handling: decide which summary metrics compare within matching round length and which can be merged.

**Status:** Consider / not implemented.

---

## Hole entry — wire "Your par X avg"

**Todo:** Replace the current placeholder (`--`) in Hole Entry with a real average for the current par type (par 3 / 4 / 5), e.g. `Your par 4 avg: 4.6`.

**Proposed logic:**

- Aggregate saved historical holes by user and `par`.
- For the active hole, compute mean score for matching par only.
- Define scope (all-time vs season) and minimum sample behavior (e.g. show `--` if sample too small).
- Keep formatting consistent (`1` decimal place) and document in design/analytics notes.

**Status:** Consider / not implemented.

---

## Yardage (yds) — source of truth and UX

**Review:** Define a clear approach for **yardage (`yds`)** since it is shown on Hole Entry today but not consistently managed across setup, round flow, and history surfaces.

**Open decisions:**

- Data source hierarchy: manual entry in setup, imported scorecard/photo, course templates, GPS/rangefinder, or external course DB.
- Per-hole editing model: editable only in setup vs editable during round with lock rules.
- Missing values: placeholder strategy (`-- yds` vs hide row) and downstream behavior in analytics.
- Persistence: how yardage syncs in Supabase for new rounds and edits.

**Status:** Consider / not implemented.

---

## Charts — dashed guides and high–round-count scaling

**Review / fix — dashed lines:** Audit dashed chart guides (e.g. par line, average line, grid) for crispness on 1pt/non-retina scaling, dash phase vs path length, and consistency between semantic vs-par charts and accent sparklines. Decide if any lines should be solid hairlines instead of dashed where dashes look broken or uneven.

**Scaling — many rounds (100+):** Plan how trends behave for **all-time** (or large) datasets: e.g. decimation / bucketing vs drawing every segment, min horizontal spacing per point, horizontal scroll vs fixed width, axis tick density, and performance of `Canvas` + animations. Validate readability on small phone widths when `values.count` is large.

**Status:** Consider / not implemented.

---

## Penalties — tracking and stats

**Idea:** Add **penalty functionality** during round play / hole entry (e.g. stroke-and-distance, lateral hazard, unplayable) and surface **penalty-related stats** (counts per round or season, trends, maybe vs expected baselines).

**Why:** Penalties drive a large share of scoring variance; tracking them explicitly improves post-round review and coaching-style insights.

**Open decisions:**

- Data model: per-hole penalty events vs aggregate counts; sync with Supabase / watch.
- UX: quick-add from hole entry vs dedicated flow; undo/edit.
- Stats placement: **Stats** tab cards, **Round detail** summary, and/or **Home** highlights.

**Status:** Consider / not implemented.

---

## FIR% — correctness and par 3’s

**Review:** Verify **FIR%** (fairways in regulation) is calculated consistently everywhere it appears (Home, Stats, round summaries, any watch paths). Confirm numerator/denominator match the intended definition (e.g. FIR only on holes where a fairway is in play).

**Par 3’s:** There is **no FIR** on par 3’s in the usual sense. Decide explicitly how they affect the rate:

- **Eligible holes only:** `FIR% = fairways_hit / fairway_opportunities` where opportunities exclude par 3’s (and optionally par 4/5 only), **or**
- **Round holes denominator:** use total holes and treat par 3 as non-opportunity (same as exclude), **or**
- **Separate reporting:** show “FIR% (par 4–5)” vs raw counts so the metric is never ambiguous.

Document the chosen rule in code comments / design brief so Stats and Home stay aligned.

**Status:** Consider / not implemented.

---

## Stats — advanced layout & exploration UX

**Todo:** Think through richer **Stats** interactions and presentation: e.g. **user-reorderable or movable chart cards** (drag to prioritize scoring vs GIR vs putts), optional **expand/collapse** or **full-screen chart** modes, **brush-linked** selections across charts, and **comparison windows** (this season vs last, or vs handicap baseline).

**Why:** Power users want to personalize dashboards and dig into relationships between metrics without leaving the tab; light-touch defaults with optional depth keeps the surface approachable.

**Open decisions:**

- Reorder persistence: in-session only vs saved preference (UserDefaults / profile).
- Haptics, accessibility, and Reduce Motion when dragging or animating layout changes.
- Whether reordering applies on **iPad** / large width only, or on phone too (screen real estate).
- Technical approach: `Grid` + drag API vs custom layout; impact on shared `GLStatTrendCard` / `VsParTrendChartView`.

**Status:** Consider / not implemented.

---

## Layout — heading height and cross-surface alignment

**Idea:** Audit **top-of-screen structure** (wordmark / screen title / nav, first section headings, horizontal inset, vertical rhythm above the first scrollable block) across **Home**, **History**, **Stats**, **Round** flows, **Round detail**, **Hole entry**, and **Profile** so that as users tap through tabs and push onto detail screens, **headings and key elements sit on the same visual plane** (aligned baselines, consistent top padding, no large jumps from large titles vs inline headers).

**Why:** Small inconsistencies in toolbar vs custom chrome vs `NavigationStack` title modes make the app feel fragmented; a single “header lane” contract improves perceived quality.

**Open decisions:**

- Prefer **one pattern** (e.g. always custom top bar + hidden nav title, or always large titles) vs per-screen exceptions documented in `docs/design.md`.
- Define tokens: **min header height**, **first content offset from safe area**, shared `GLLayout` / modifier if helpful.
- Snapshot or checklist when adding new surfaces.

**Status:** Consider / not implemented.
