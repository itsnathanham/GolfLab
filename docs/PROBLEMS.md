# Problems & positioning — Golf Lab


|             |                                                                                                                                                               |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Version** | v1.0                                                                                                                                                          |
| **Date**    | May 21, 2026                                                                                                                                                  |
| **Owner**   | Nathan Hamilton                                                                                                                                               |
| **Status**  | Grounded in owner use, field testing, and [ICP v1.0](ICP.md)                                                                                                  |
| **Related** | [Product thinking](PRODUCT.md) · [ICP](ICP.md) · [Design brief](design.md) · [README § How this repo is documented](../README.md#how-this-repo-is-documented) |


---

## Problem in one sentence

**Committed recreational golfers want to know if they're actually getting better—but the tools available make on-course tracking feel like admin work and off-course analytics feel like noise.**

---

## Who feels this problem

The primary sufferer matches the [committed recreational golfer](ICP.md): plays 4+ times a month, cares about scoring, has **tried and abandoned** apps like 18Birdies or The Grint, and carries the emotional blocker that the *next* app will also get in the way.

Problem ranks below are validated through **owner use and phone + Watch field testing** ([backlog](future-todos.md)), written in market language because that is how product choices in the repo are explained and reviewed.

---

## The problems (ranked)

### 1. On-course tracking breaks the round

**Problem:** Logging stats mid-round competes with pace of play, sunlight, and social context. Full-featured apps push GPS maps, shot-by-shot flows, and deep menus at the moment the golfer least wants cognitive load.

**Evidence from building:**

- Repeated deletion of complex apps by the 3rd hole (ICP narrative)
- Field-test backlog prioritized **Watch-first entry**, **44pt+ tap targets**, **auto-advance on save**, and stripping setup friction (e.g. removed tee row from New Round)
- Design brief: light-only, high legibility outdoors—not dark chrome or gamified sports UI

**Job to be done:** *Log score, putts, GIR, FIR, and penalty in ~30 seconds per hole without pulling the group behind.*

---

### 2. Round-to-round scoring hides whether you're improving

**Problem:** A 92, then an 89, then a 95 feels like noise. Without structured history, golfers can't tell if GIR, putting, or penalties are moving in the right direction over a season.

**Evidence from building:**

- Home and Stats focus on **vs par, GIR, FIR, putts, penalties**—metrics tied to scoring, not every possible stat
- Season filters and trend charts (with intentional chart intro polish) reward **months-later review**, not live dashboard staring
- Open product tension: 9 vs 18-hole rounds mixed in averages ([future-todos](future-todos.md))—acknowledges the problem isn't fully solved

**Job to be done:** *Open the app weeks later and see a trend—"GIR up since March," not another static scorecard.*

---

### 3. Practice and play don't connect to habits

**Problem:** Playing more doesn't automatically mean practicing more—or vice versa. Without lightweight accountability, improvement intent fades between rounds.

**Evidence from building:**

- **Weekly goals** (rounds + practice sessions) and **streak completion** as the primary success metric ([PRODUCT.md](PRODUCT.md))
- Practice log in History; celebration UX when a week completes
- Profile demoted off the tab bar so navigation stays round- and insight-centric

**Job to be done:** *Stay accountable across the calendar week, not just remember the last round.*

---

### 4. "Coaching" products solve the wrong gap

**Problem:** Swing video, tip feeds, and GPS caddie features don't answer: *Given my actual rounds, what should I do on the course to score better?* Many golfers don't need another swing tip—they need strategy grounded in **their** trends.

**Evidence from building:**

- Explicit **out of scope:** swing analytics, GPS shot guidance, per-hole phone caddie ([PRODUCT.md](PRODUCT.md))
- AI tab copy: *"Personalized on-course strategy from your stats—built to help you score, not rebuild your swing"* (`CoachView`)—shipped as positioning before implementation
- Phased vision: **analytics foundation first**, AI strategy coach second

**Job to be done (future):** *Turn owned round history into course strategy, not generic instruction.*

---

## Why existing alternatives fail


| Alternative                            | What it optimizes for                      | Why it fails this user                                                     |
| -------------------------------------- | ------------------------------------------ | -------------------------------------------------------------------------- |
| **18Birdies, similar "platform" apps** | GPS, social, games, swing content, breadth | Feature depth creates mid-round friction; abandoned on-course              |
| **The Grint**                          | Official handicap, forms, leaderboards     | Form-first; less insight-first for long-arc trends                         |
| **Arccos / sensor stacks**             | Frictionless capture via hardware          | $200+ setup, club sensors, management overhead—not "just show up and play" |
| **Scorecard / Notes**                  | Zero app friction                          | No trends, no season view, no accountability—progress stays invisible      |
| **Memory & feel**                      | No admin                                   | Unreliable; can't prove improvement to yourself (or a coach)               |


**Positioning wedge:** Golf Lab does not win on feature count. It wins on **intentional simplicity** (no hardware, no GPS, no shot-by-shot) plus a **long-arc analytics payoff** competitors treat as secondary.

---

## What Golf Lab does about it


| Problem             | Product response                                                               | Where it shows up                                                     |
| ------------------- | ------------------------------------------------------------------------------ | --------------------------------------------------------------------- |
| On-course friction  | Watch-primary logging; large steppers/toggles; save-and-advance; iPhone backup | `HoleEntryView`, Watch app, Watch Connectivity sync                   |
| Invisible progress  | Restrained Home/Stats metrics; season trends; History calendar & scorecard     | `HomeView`, `StatsView`, `HistoryView`                                |
| Weak habits         | Weekly round + practice targets; streak UI; practice log                       | `GLWeeklyGoalsStreak`, `WeeklyGoalsStreakSection`, `LogPracticeSheet` |
| Wrong coaching lane | Deferred AI strategy on **owned data**; no swing/GPS scope                     | `CoachView` (coming soon), [tradeoffs in PRODUCT.md](PRODUCT.md)      |


**Design supports the problem, not the other way around:** analytics-dashboard aesthetic ([design.md](design.md)), fewer metrics over data density, clarity in sunlight.

---

## Positioning

### Category

Simple golf stat tracker and personal scoring analytics—not a GPS caddie, not a swing lab, not a social golf network.

### For

Committed recreational golfers who will log **4–5 stats per hole** if entry stays invisible, then review trends on iPhone after the round.

### Unlike

Apps that ask for attention every shot, or hardware systems that automate capture at the cost of setup and ongoing management.

### Promise

**Cut through the noise to improve your on-course scoring.**

- **On-course:** ~30 seconds per hole; Watch when playing.
- **Off-course:** Trends that answer "am I getting better?" without dashboard clutter.
- **Between rounds:** Weekly goals and streaks that reward showing up.

### Not for

See [ICP exclusion criteria](ICP.md#exclusion-criteria): beginners with no history, GPS-primary shoppers, swing-video seekers, Android-only (today).

---

## What we learned while building (problem → decision)

These are real product calls driven by the problems above—not a roadmap wish list.


| Learning                                   | Decision                                                                     |
| ------------------------------------------ | ---------------------------------------------------------------------------- |
| Phone in pocket during play                | **Apple Watch is primary** for active round; tab switches to Round when live |
| Tab bar crowded with low-value surface     | **Profile removed from tabs**; minimal profile on Home only                  |
| Watch and phone diverging mid-round        | **Immediate merge** of Watch saves; resync on reachability / appear          |
| Sunlight + gloves + pace                   | **Bigger typography**, 62×62 hole steppers on phone, 44pt Watch targets      |
| Translucent sheets unreadable outdoors     | **Light-forced** date picker sheet; custom chrome                            |
| Analytics without delight still feels dead | Chart intro animation—in service of **review moment**, not on-course         |
| Data must survive device loss              | Supabase sync—even for single-user, **production-ready** persistence         |
| Streak is the behavior we want             | **Streak completion** = primary success metric, not DAU vanity               |


Full shipped backlog context: [future-todos.md](future-todos.md) (phone + Watch test pass).

---

## What's still hard (honest gaps)

Problems **not** fully solved in v1—tracked openly so the doc stays credible for PM reviewers:


| Gap                                   | Why it matters                                           |
| ------------------------------------- | -------------------------------------------------------- |
| 9-hole vs 18-hole mixed in aggregates | Trends can misread improvement when round lengths differ |
| GIR/FIR/putts validation              | Edge-case combinations can save inconsistent states      |
| Penalties in analytics                | Per-hole penalty exists; richer penalty stats still open |
| Yardage / course setup                | Shown in UI; source of truth not settled                 |
| AI strategy coach                     | Positioned; needs enough owned history to be useful      |
| Handicap officialization              | Out of scope today; may matter later                     |


Details: [future-todos.md](future-todos.md).

---

## How to read this in the doc set


| Doc                       | Question it answers                                                    |
| ------------------------- | ---------------------------------------------------------------------- |
| **This file**             | What hurts, why incumbents fail, what Golf Lab commits to              |
| [ICP.md](ICP.md)          | Who hurts most, how they behave, tiers, competition                    |
| [PRODUCT.md](PRODUCT.md)  | Vision, JTBD priority, tradeoffs, surface map                          |
| [design.md](design.md)    | How UX should *feel* when solving problems 1–2                         |
| [README.md](../README.md) | Entry, [how docs are scoped](../README.md#how-this-repo-is-documented) |


---

## Validation note

Problem framing is **owner- and field-test-informed**, aligned with ICP v1.0. Interview and cohort validation in [ICP](ICP.md#data--research-inputs) describe the **next** PM step—not a claim that this doc is already customer-validated at scale. If research contradicts a problem rank, update this file and [PRODUCT.md](PRODUCT.md) together.