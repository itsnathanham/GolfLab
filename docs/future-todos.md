# Future todos

Ideas and follow-ups that are **not** scheduled work—capture here so they are not lost.

---

## Current product backlog (phone + Watch test pass)

Ordered list from field testing. **Do these in sequence** unless a quick win is bundled.


| #   | Item                                                                                                                                                      | Status   |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| 1   | **Typography** — larger central type scale (`Font.gl`*), hierarchy preserved; `docs/design.md` + `DESIGN_REFERENCE.md` updated                            | **Done** |
| 2   | **Profile in tab bar** — removed; profile only from Home → `NavigationLink` to `ProfileView`                                                              | **Done** |
| 3   | **Watch ↔ iPhone active round** — immediate merge of Watch saves; `WatchRoundState` push for current hole + saved holes; reachability / `onAppear` resync | **Done** |
| 4   | **Watch hole entry UX** — full-width score/putts steppers (44pt targets), stacked GIR/FIR/**Penalty** rows, “Save hole” CTA                               | **Done** |
| 5   | **iPhone tap targets** — hole steppers 62×62 −/+ with full-cell `contentShape`; stat toggles `minHeight` 68                                               | **Done** |
| 6   | **New Round** — tee row removed; course `TextField` uses `prompt` with `textSecondary`                                                                    | **Done** |
| 7   | **History scorecard** — course name tap → sheet; Supabase `updateRoundCourseName`                                                                         | **Done** |
| 8   | **New Round date picker sheet** — custom header + `preferredColorScheme(.light)` + `DatePicker` `tint` (no translucent nav chrome)                        | **Done** |
| 9   | **Chart intro animations** — line reveal on trend charts (legacy sparkline path removed; `VsParLineChartView` cards)                                      | **Done** |


**After the backlog:** consider items below in this file (9 vs 18 filter, GIR/FIR guardrails, branded loading, etc.). **Penalties — tracking and stats** is partially satisfied by per-hole penalty on phone + Watch; that section still applies if you want event types, counts in Stats, etc.

---

## Average cumulative score vs par — Last round summary + Stats chart

**Todo:** Add **average cumulative score versus par** functionality on **Last round summary**, and add a matching **chart on the Stats** page.

**Why:** Users already see hole-by-hole vs-par progression on Last round; a cumulative average line (or equivalent) makes it easier to see when a round turned vs when it stayed level. Stats should expose the same metric across rounds for season-level trend review.

**Open decisions:**

- **Last round:** Extend `RoundVsParProgressCard` (or a sibling card) vs a separate visualization; clarify label copy (cumulative vs par vs running average).
- **Stats:** Placement in chart stack (near scoring trend vs separate card); same `VsParLineChartView` / series rules as other round-based metrics.
- **Aggregation:** Per-hole cumulative for one round vs per-round cumulative average across the season; axis labels and grid style alignment with existing trend cards.
- **Incomplete rounds:** Behavior when hole rows are partial (same rules as existing Last round / Stats hole-loading paths).

**Status:** Consider / not implemented.

---

## Average score by par — approach and visual

**Todo:** Design and ship an **average score by par** view (par 3 / 4 / 5): how users compare to their typical performance on each par type, with a clear visual treatment (chart, card, or breakdown).

**Why:** Scoring vs par alone hides where rounds are won or lost; par-type averages help users see whether they leak strokes on par 3s, 4s, or 5s.

**Open decisions:**

- **Visual:** Bar chart, grouped cards, sparkline per par type, or table with trend; alignment with existing Stats chart stack and `VsParLineChartView` patterns.
- **Scope:** All-time vs season vs last N rounds; minimum sample per par type before showing a value.
- **Metric:** Raw average score vs average vs par for that par type; label copy and decimal formatting.
- **Placement:** Stats tab (primary), Home highlight, and/or Last round summary sibling to cumulative vs-par work.

**Status:** Consider / not implemented.

---

## Stats — breakdowns by hole par type

**Todo:** Add **Stats breakdowns segmented by hole par type** (par 3 / 4 / 5): e.g. scoring, GIR%, FIR% (par 4–5 only), putts/hole, penalties—so users can compare habits across par types, not only round-level aggregates.

**Why:** Round-level Stats obscure par-specific strengths and weaknesses; par-type slices support targeted practice and course-management review.

**Open decisions:**

- **Metrics:** Which cards get par-type tabs or filters vs dedicated sub-sections; reuse shared aggregation helpers vs one-off queries.
- **FIR / GIR rules:** Same eligibility rules as FIR% review (par 3 excluded from FIR opportunities); document denominators per par type.
- **Filter interaction:** Combine with 9 vs 18 and season/last-10 filters; empty states when a par type has no holes in range.
- **UX:** Segmented control, picker, or expandable rows; phone layout vs future iPad width.

**Status:** Consider / not implemented.

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

## Loading UI — branded experience

**Idea:** Replace basic loading states with a branded/fancier treatment (e.g. golf ball animation, wordmark motion, or subtle Golf Lab-themed loader) to improve perceived quality while data is preparing.

**Open decisions:**

- Visual direction: golf ball spin/bounce vs minimal brand pulse vs skeleton + branded accent.
- Reuse strategy: one shared loading component/tokenized style across Home, Stats, Round detail, and Last round summary.
- Performance/accessibility: keep animation lightweight, respect Reduce Motion, and preserve clear loading text for VoiceOver.
- Timing behavior: minimum display duration and crossfade rules to avoid flicker on very fast loads.

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

## Charts — high–round-count scaling

**Scaling — many rounds (100+):** Plan how trends behave for **all-time** (or large) datasets: e.g. decimation / bucketing vs drawing every segment, min horizontal spacing per point, horizontal scroll vs fixed width, axis tick density, and performance of `Canvas` + animations. Validate readability on small phone widths when `values.count` is large.

**Status:** Consider / not implemented.

---

## Stats — advanced layout & exploration UX

**Todo:** Think through richer **Stats** interactions and presentation: e.g. **user-reorderable or movable chart cards** (drag to prioritize scoring vs GIR vs putts), optional **expand/collapse** or **full-screen chart** modes, **brush-linked** selections across charts, and **comparison windows** (this season vs last, or vs handicap baseline).

**Why:** Power users want to personalize dashboards and dig into relationships between metrics without leaving the tab; light-touch defaults with optional depth keeps the surface approachable.

**Open decisions:**

- Reorder persistence: in-session only vs saved preference (UserDefaults / profile).
- Haptics, accessibility, and Reduce Motion when dragging or animating layout changes.
- Whether reordering applies on **iPad** / large width only, or on phone too (screen real estate).
- Technical approach: `Grid` + drag API vs custom layout; impact on shared `GLStatTrendCard` / `VsParLineChartView`.

**Status:** Consider / not implemented.

---

