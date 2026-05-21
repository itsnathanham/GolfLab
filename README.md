# Golf Lab

**Cut through the noise to improve your on-course scoring.**

Golf Lab is a production-grade iOS and watchOS app for frictionless round logging, clear trend analytics, and weekly practice accountability—with an AI strategy coach planned as a layer on top of the data foundation.

---

## Start here (product)

| Document | What you'll find |
|----------|------------------|
| [**Product thinking**](docs/PRODUCT.md) | Vision, jobs-to-be-done, scope, success metrics, feature map, and **explicit tradeoffs** |
| [**Ideal customer profile**](docs/ICP.md) | **Committed recreational golfer** (ICP v1.0) |
| [**Problems & positioning**](docs/PROBLEMS.md) | What hurts, why alternatives fail, positioning (v1.0) |
| [**Design brief**](docs/design.md) | Visual language, tokens, and UI principles |
| [**Design reference**](docs/DESIGN_REFERENCE.md) | Implementation digest for SwiftUI |
| [**Roadmap & ideas**](docs/future-todos.md) | Backlog and open product decisions |

---

## What it does today

- **Round logging** — Score, putts, GIR, FIR, and penalty per hole on iPhone and Apple Watch, optimized for few taps on-course.
- **Home & Stats** — Key scoring metrics and trends without dashboard clutter.
- **History** — Past rounds, calendar, scorecard detail, practice log.
- **Weekly goals & streak** — Round and practice targets with consecutive-week completion tracking (primary success metric).
- **AI Strategy Coach** — Tab and positioning defined; implementation follows analytics maturity.

---

## How this repo is documented

The public docs describe a **shipped product** and the **product discipline** behind it—intended for PM and design partners reviewing portfolio work.

| Layer | What it shows |
|-------|----------------|
| **Product** | [Problems](docs/PROBLEMS.md) → [Product thinking](docs/PRODUCT.md) (incl. tradeoffs) → [ICP](docs/ICP.md) → [Design](docs/design.md) |
| **Process** | Persona, positioning, validation plans, and acquisition tiers as **design lens** artifacts—not a statement of live go-to-market |
| **Engineering** | Production-ready choices: Supabase sync, Watch ↔ iPhone round state, field-tested on-course UX ([backlog](docs/future-todos.md)) |

The app is **owner-operated** (built for daily use, not commercialized). ICP and positioning language read market-facing on purpose: that is how product decisions are stress-tested before they ship in code.

---

## Built with

| Layer | Stack |
|-------|--------|
| **Client** | Swift, SwiftUI (iOS + watchOS), Watch Connectivity |
| **Backend** | [Supabase](https://supabase.com) — auth, Postgres, row sync (`supabase-swift`) |
| **Design** | Custom design system — IBM Plex Sans / Mono ([brief](docs/design.md)) |
| **Tooling** | Xcode; [Cursor](https://cursor.com) for AI-assisted design and implementation |

---

## For reviewers

Evaluate **why**, not only **how**: [Problems](docs/PROBLEMS.md) → [Product thinking](docs/PRODUCT.md) (tradeoffs) → [ICP](docs/ICP.md) → [Design brief](docs/design.md). See [How this repo is documented](#how-this-repo-is-documented) for scope and intent.

---

## Development

Xcode project: `GolfLab.xcodeproj`. Local secrets: copy `GolfLab/Config/Secrets.local.example.xcconfig` to `Secrets.local.xcconfig` (not committed).
