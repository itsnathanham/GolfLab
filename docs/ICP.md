# Ideal customer profile — Golf Lab


|                 |                                                                            |
| --------------- | -------------------------------------------------------------------------- |
| **Version**     | v1.0                                                                       |
| **Date**        | May 21, 2026                                                               |
| **Owner**       | Nathan Hamilton                                                            |
| **Next review** | At 100 users (post-launch)                                                 |
| **Status**      | Directional — validate with customer interviews before scaling acquisition |


This ICP defines **who the product is designed for** and documents PM process (tiers, competition, validation, activation)—as it would be for a product entering market. The shipped app is **owner-operated** and not commercialized; this doc is the **design lens** for tradeoffs in code. See [README § How this repo is documented](../README.md#how-this-repo-is-documented).

---

## ICP summary

**Archetype:** The committed recreational golfer

**In one sentence:** A golfer who plays 4+ rounds per month, has tried and abandoned complex golf apps, and wants a frictionless way to track their game so they can see—months and years later—that all those rounds are actually making them better.

---

## ICP narrative

> I play golf seriously—not competitively, but seriously. I'm out there 4, 5, sometimes 6 times a month. I've downloaded the apps. 18Birdies, The Grint, a couple others. Every time I'm on the 3rd hole fumbling through menus, trying to log a shot, watching the group behind me catch up—I end up deleting them by the 19th hole.
>
> The thing is, I genuinely want to know if I'm improving. Golf is a game where progress is invisible round to round. You shoot a 92, then an 89, then a 95, and you have no idea if you're getting better or just having a good day.
>
> I want something I can actually use on the course—30 seconds per hole, no GPS nonsense—and then open on my phone a few months later and actually see a trend. Show me my GIR is up 8% since March. Show me I'm two-putting more. That's the whole thing. Just don't get in my way while I'm playing.

**Emotional blocker:** *"Every app I've tried makes me feel like I'm doing admin work while I'm supposed to be enjoying a round. I don't trust that any app will actually stay out of my way."* The hesitation is past failure—they've been burned before and assume the next app will be the same.

---

## Consumer profile


| Attribute             | Profile                                                                      |
| --------------------- | ---------------------------------------------------------------------------- |
| **Segment**           | Committed recreational golfer                                                |
| **Rounds per month**  | 4+ (plays year-round or near year-round)                                     |
| **Handicap range**    | 8–28 (serious amateurs; not beginners, not scratch)                          |
| **Age range**         | 28–55 (primary); skews 35–50                                                 |
| **Household income**  | $75K–$200K+ (golf is a consistent budget line)                               |
| **Geography**         | US primary; English-speaking markets (UK, Australia, Canada) secondary       |
| **Device**            | iPhone primary; Apple Watch for on-course data entry                         |
| **Shopping channels** | App Store discovery, word of mouth at the course, golf subreddits, Instagram |
| **Price sensitivity** | Willing to pay for quality; resistant to bloated subscription tiers          |
| **Life stage**        | Established career, disposable income, golf as a core hobby identity         |


---

## Pain points & buying triggers

### Primary pain points

- Existing apps are too complex to use during a round—menus, GPS maps, shot-by-shot logging break the flow of play
- Progress in golf is invisible round-to-round; no clear way to see improvement over months or a season
- Feature overload creates cognitive load at exactly the wrong moment (mid-round)
- Apps optimized for data collection, not for the player's experience on the course

### What triggers them to start looking

- Downloads a complex app, uses it for 1–2 rounds, deletes it out of frustration
- Has a stretch of rounds and realizes they have no record of their progression
- Starts taking lessons or working on a specific part of their game and wants to track it
- Friend mentions they're tracking stats and it resurfaces the desire to do it right

---

## Behavioral profile


| Dimension               | Behavior                                                                                                                 |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **Research**            | App Store search, r/golf and r/golfswing, YouTube golf creators, word of mouth at the club                               |
| **Influencers**         | Playing partners, golf content creators (YouTube/Instagram), golf subreddit communities                                  |
| **Success measure**     | Visible trend improvement over a season (GIR %, putts per round, scoring average); app feels invisible during play       |
| **Minimum involvement** | ~30 seconds per hole logging 4–5 stats; reviews analytics on phone post-round                                            |
| **Content lane**        | Golf improvement YouTube (Me and My Golf, Rick Shiels), golf subreddits, equipment podcasts; trusts peers over brand ads |


---

## Value drivers

- **Frictionless on-course experience** — Data entry takes seconds, not minutes; never interrupts the round
- **Long-arc progress visibility** — Core emotional payoff: real improvement across months and seasons, not a scorecard dump
- **Clean, analytics-forward design** — Data presented visually; not buried in tables
- **Apple Watch integration** — Logging from the wrist without pulling out a phone mid-round
- **No hardware required** — Frictionless by design, not by adding sensors or peripherals
- **Future: AI course strategy coaching** — Not swing mechanics; on-course decision-making informed by their own data

---

## Buyer intent signals


| Signal                                                           | What it means                               | Recommended action                                       |
| ---------------------------------------------------------------- | ------------------------------------------- | -------------------------------------------------------- |
| Searches "golf stat tracking app" or "simple golf scorecard app" | Actively in-market; frustrated with options | App Store SEO on "simple" and "frictionless"             |
| Posts in r/golf asking for app recommendations                   | High intent; peer-validation seeking        | Authentic community presence; word-of-mouth              |
| Downloads app, completes first round, returns for analytics      | Activation—they get it                      | Retention nudge; prompt next round                       |
| Opens app to review historical charts 2+ weeks post-round        | Core value prop landing                     | Referral ask or upgrade prompt                           |
| Mentions lessons or working on a specific weakness               | Ready to track meaningful data              | Highlight GIR, FIR, putt tracking for coaching alignment |


---

## Green / yellow / red classification

Tiers use **verifiable attributes** (rounds/month, app history, device)—not motivation, which surfaces over time. **Green** is who the product is built for. **Yellow** is experiment. **Red** means don't sell to them.


| Tier          | Criteria                                                                                                                        | Action                                                         |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| 🟢 **Green**  | 4+ rounds/month, iPhone user, tried and abandoned ≥1 golf app, plays for enjoyment and improvement (not touring pro), age 28–55 | Primary acquisition—App Store, golf communities, word of mouth |
| 🟡 **Yellow** | 2–3 rounds/month, curious about stats but never tracked, may be Android (future), seasonal bursts only                          | Engage if inbound; don't prioritize early paid acquisition     |
| 🔴 **Red**    | Complete beginner (first season), wants GPS/course mapping primary, wants pro swing/video coaching                              | Don't sell to them                                             |


---

## Exclusion criteria

- **Complete beginners** — Value is longitudinal progress; no history means no payoff
- **GPS / course mapping seekers** — Deliberate non-feature; misaligned expectations drive churn
- **Swing mechanics coaching seekers** — Not the lane (strategic/course coaching is future, not current)
- **Android-only users** — Apple Watch is core; Android is a future consideration

**Churn pattern to watch:** Users expecting GPS or full shot-tracking (Arccos-style) who feel the product is incomplete. Manage expectations in App Store copy and onboarding—**simplicity is the feature**, not a limitation.

---

## Competitive landscape


| Competitor    | Who they serve                                              | Golf Lab differentiation                                                            |
| ------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| **18Birdies** | Full platform—GPS, social, swing tips, games                | Wins on simplicity; their depth is what our user abandoned                          |
| **The Grint** | Handicap-focused, GHIN integration, social leaderboards     | Wins on frictionless UX and analytics depth; they're form-first, not insight-first  |
| **Arccos**    | Hardware sensors on every club for automatic shot detection | Wins on zero-hardware, zero-setup; Arccos needs ~$200 sensors and active management |


**Positioning note:** Arccos nails frictionless capture via hardware automation. Golf Lab's path is **intentional simplicity**—no hardware, no auto-detection (today), clean ~30-second-per-hole UI. The **long-arc analytics layer** is the differentiated payoff competitors don't own clearly.

---

## Data & research inputs

This ICP is built on **product vision and competitive observation**, not validated customer interviews. Use it for acquisition and retention **planning** in docs and reviews—not for significant budget allocation—until gaps below are closed.

### Recommended next steps

- 8–12 interviews with **Green tier** golfers—focus on the emotional blocker: what made them delete the last app?
- Validate handicap range (8–28 inferred)
- Validate household income proxy ($75K–$200K)
- Validate age range (may skew 40–55)
- Quantify Android appetite before ruling out permanently
- Test App Store copy: "simple" and "frictionless" as pull terms (ASO at launch)

### Customer interview prompts

- What was happening that made you start looking for a stat-tracking app?
- Walk me through using a golf app mid-round. What's frustrating?
- What would have to be true for you to stick with a golf app for a full season?
- When you look back at a year of golf, what do you wish you knew about your game?

---

## Activation recommendations

### Marketing

- **App Store:** Own "simple golf stat tracker" and "golf scorecard app"; hero claim **"30 seconds per hole"**
- **Reddit:** Authentic presence in r/golf and r/golfswing—feedback asks, not ads
- **Content:** Short video of real round entry (<60s)—the demo is the pitch
- **Word of mouth:** Referral mechanic early; one evangelist ≈ a foursome

### Retention

- **Onboarding:** First-round completion + first weekly streak goal = activation moments
- **Aha moment:** First multi-round trend chart—target within **3 rounds**
- **Re-engagement:** Seasonal triggers ("12 rounds this season—here's your progress")

### Product roadmap signals from ICP

- **Apple Watch entry** — Table stakes for Green tier; must be excellent
- **Long-arc trends + streak mechanics** — Season/year views are core emotional payoffs
- **AI course strategy** — Future expansion for the same user without breaking frictionless positioning

---

## Validation schedule


| Frequency    | Method                                             | Owner             |
| ------------ | -------------------------------------------------- | ----------------- |
| At 100 users | Qualitative interviews (8–10); validate Green tier | Founder           |
| Quarterly    | Retention cohorts by channel; churn patterns       | Product / Founder |
| Bi-annually  | In-app survey on fit, pain, feature value          | Product           |
| Annually     | Full ICP re-analysis vs retention/engagement data  | Founder           |


---

## How this fits the doc set


| Doc                        | Role                                                              |
| -------------------------- | ----------------------------------------------------------------- |
| [PROBLEMS.md](PROBLEMS.md) | What hurts and positioning                                        |
| **This file**              | Who it's for; G/Y/R tiers; competitive and validation **process** |
| [PRODUCT.md](PRODUCT.md)   | Vision, tradeoffs, shipped surface map                            |


Shaped product choices for this build: Watch-primary logging, restrained analytics, weekly streak as success metric, AI strategy coach as a later layer.