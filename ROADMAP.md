# Bunk Planner: Attendance Track — Roadmap

Living tracker. Checkboxes: `[x]` done · `[~]` partial · `[ ]` not started.

---

## Shipped — v1.7 (UX + ads hygiene)

Released. Local data survives App Store updates (Core Data / UserDefaults).

### Home & habit
- [x] Home Level-1 (hero %, bunks, tomorrow attend/skip; calculator collapsed)
- [x] Mark Today as daily center (Yes / Missed / Holiday + celebration)
- [x] Subject picker bottom sheet
- [x] Contextual FAB (morning / evening / recovery / streak)
- [x] Welcome empty state → Get Started
- [x] Lightweight onboarding (skip for returning users)

### Insights & forecast
- [x] This Week / streak / top / needs-attention + light XP badges
- [x] Forecast Assumptions (collapsible) + Planned Bunks primary input
- [x] Semester dates → auto weeks remaining
- [x] Accordion subject forecast + Safe / Warning / Critical
- [x] Primary answer: “safely bunk N” / “attend N consecutive”
- [x] Classes/week fallback when no timetable

### Overview & Pro
- [x] All Subjects dashboard cards
- [x] Outcome-based Pro paywall copy
- [x] Quiet mode / Pro upsell CTA on Home / Insights (watch-ad path removed)

### Ads & notifications
- [x] Banner: shared unit + 1.5s dwell + only while tab active
- [x] Insights / Overview banners restored (active-tab gated)
- [x] App-open cold-start show fix; interstitial present snappier
- [x] 8 PM mark reminder + Mon kickoff + Fri buffer nudges

---

## v1.8 — In progress: Habit + Semester OS + Focus

**Theme:** *Know before you bunk — track every day, plan the semester, focus when you study.*

### Pillar 1 — Daily loop (DAU)

| ID | Sub-task | Status |
|----|----------|--------|
| 1.1 | Home Screen widget: current % + safe bunks left | [x] |
| 1.2 | Lock Screen widget: same glance metrics | [x] |
| 1.3 | 8 PM “Did you mark today?” reminder | [x] |
| 1.4 | Monday kickoff reminder | [x] |
| 1.5 | Friday bunk-buffer reminder | [x] |
| 1.6 | Reminder copy uses live subject % / bunks (personalized) | [x] |
| 1.6b | Witty, context-aware notification personality layer | [x] |
| 1.7 | Streak display on Insights | [x] |
| 1.8 | Shareable streak card (“12-day streak”) | [x] |
| 1.9 | Mark Today — single subject (one-tap) | [x] |
| 1.10 | Mark Today — **all subjects today** in one flow | [x] |
| 1.11 | Morning / evening multi-subject prompt variants | [x] |
| 1.12 | **Focus Timer** (Pomodoro 25/5, Tools hub, today minutes) | [x] |

**Pillar 1 progress:** 13 done · 0 partial · 0 open

---

### Pillar 2 — Semester brain (retention)

| ID | Sub-task | Status |
|----|----------|--------|
| 2.1 | Semester start/end stored (`SemesterSettings`) | [x] |
| 2.2 | Forecast weeks auto from semester end | [x] |
| 2.3 | Semester dates editable in Forecast Assumptions | [x] |
| 2.4 | “Classes left this semester” on Home / subject cards | [x] |
| 2.5 | Classes left uses timetable × weeks − holidays − bunks | [x] |
| 2.6 | India holiday presets (e.g. Diwali week) — light | [x] |
| 2.7 | Apply holiday preset → College Holidays count | [x] |
| 2.8 | Insights “This Week” attended / bunks / delta | [x] |
| 2.9 | Weekly digest **notification** (Sun/Mon summary) | [x] *Pro Sunday digest* |
| 2.10 | Semester progress strip (week N of M) | [x] |

**Pillar 2 progress:** 10 done · 0 partial · 0 open

---

### Pillar 3 — Money (without killing UX)

| ID | Sub-task | Status |
|----|----------|--------|
| 3.1 | Pro IAP + restore | [x] |
| 3.2 | Rewarded “Hide ads” (Settings + Home) | [x] *removed — low usage; Pro-only* |
| 3.3 | Forecast lock → Go Pro | [x] *watch-ad path removed* |
| 3.4 | At-risk Home moment → Go Pro (contextual) | [x] *recovery CTA + cooldown re-prompt* |
| 3.5 | Forecast unlock UX feels native (less “ad wall”) | [~] *improved accordion; lock CTA still separate* |
| 3.6 | Soft paywall after 7-day streak | [x] *re-prompts every 10 days* |
| 3.7 | Soft paywall after at-risk week | [x] *first at-risk week, not 3rd* |
| 3.8 | One mediation network for India | [ ] *after show-rate check* |
| 3.9 | Measure show rate ≥40% before mediation | [ ] *ops / post-ship* |

**Pillar 3 progress:** 6 done · 1 partial · 2 open

---

### Pillar 4 — Trust / share (growth)

| ID | Sub-task | Status |
|----|----------|--------|
| 4.1 | Share result image + text from Home | [x] |
| 4.2 | Share card polish (“I can bunk N safely”) | [~] *works; needs visual refresh* |
| 4.3 | Welcome empty → Get Started first-value path | [x] |
| 4.4 | First-run: add subject → Mark Today guided | [x] |
| 4.5 | CSV export of attendance log | [x] *Pro* |
| 4.6 | Pro PDF attendance report | [x] |
| 4.7 | **Firebase viral referral** (invite link + redeem + 7d ad-free both sides) | [ ] *backlog — see [docs/plans/firebase-viral-referral.md](docs/plans/firebase-viral-referral.md)* |

**Pillar 4 progress:** 5 done · 1 partial · 1 open

---

### Pillar 5 — US / UK market (expansion)

| ID | Sub-task | Status |
|----|----------|--------|
| 5.1 | Locale market detection + Settings override (`StudentMarket`) | [x] |
| 5.2 | Region-aware copy (bunk vs skip) on Home + share | [x] |
| 5.3 | Grades tab: US 4.0 GPA calculator | [x] |
| 5.4 | Exams & deadlines list with countdown | [x] |
| 5.5 | Default attendance target by market (75 IN / 80 US·UK) | [x] *auto on first launch* |
| 5.6 | UK module % / degree classification calculator (+ year weighting) | [x] |
| 5.6b | India 10-point CGPA / UGC grades + target calculator | [x] |
| 5.6c | Deadline reminders (T-7/T-3/T-1) + exam×attendance Home warning | [x] |
| 5.6d | Semester/term grouping (SGPA + archive) + grades in Pro PDF | [x] |
| 5.7 | Soften India-only holiday presets; add US/UK breaks later | [ ] |
| 5.8 | App Store localization (en-GB + en-US metadata) | [ ] |

**Pillar 5 progress:** 8 done · 0 partial · 2 open

---

## v1.8 first-slice focus (this build)

1. **1.10 + 1.11** — Multi-subject Mark Today — done  
2. **2.4 + 2.5** — Classes left this semester on Home — done  
3. **1.1 + 1.2** — Home + Lock Screen widgets — done  
4. **1.12** — Focus Timer (Academics) — done  
5. **1.6 + 1.8 + 1.6b** — Personalized + witty notifications, streak share — done  

See [docs/release-notes-1.7.0.md](docs/release-notes-1.7.0.md).

---

## v1.7.2 — Retention & student hub (ready to ship)

See [docs/release-notes-1.7.2.md](docs/release-notes-1.7.2.md) · Marketing **1.7.2** · Build **20**

Branch: `feature/retention-monetization-sprint` — merge to `main` before archive.

---

## v1.7.1 — Pro conversion fix (shipped)

**Goal:** Ask for Pro after value, not after install. Fix purchase analytics gap.

See [docs/release-notes-1.7.1.md](docs/release-notes-1.7.1.md) · Marketing **1.7.1** · Build **19** *(App Store prior release)*

| ID | Sub-task | Status |
|----|----------|--------|
| P1.1 | No Pro on onboarding (intro only) | [x] |
| P1.2 | Soft paywall: at-risk week 1, streak 7, subject cap, locked forecast | [x] |
| P1.3 | Delay `habit_value` paywall to day 5+ after install | [x] |
| P1.4 | `habit_value` only after first Mark Today (not calculator-only) | [x] |
| P1.5 | Paywall copy: outcome-first (forecast / recovery), ads last | [x] |
| P1.6 | Log `pro_purchase_succeeded` + revenue from StoreKit `Transaction.updates` | [x] |

**Watch after ship (Firebase, 2 weeks):** `purchase_started / paywall_viewed` > 3% · paywall dismiss < 85%.

---

## Backlog — Retention (P2)

Fix week-1 return (~14% today → target 25%+).

| ID | Sub-task | Status |
|----|----------|--------|
| P2.1 | Day-2 push if installed but never marked | [x] |
| P2.2 | First-run guided path: add subject → Mark Today (4.4) | [x] |
| P2.3 | Notification deep links → Mark Today; improve open rate | [x] *branch: feature/retention-monetization-sprint* |
| P2.4 | Weekly digest notification Sun/Mon (2.9) | [x] *Pro Sunday digest* |
| P2.5 | One-time widget prompt after first mark | [x] |
| P2.6 | Instrument Focus Timer + Academics tab in analytics | [x] |
| P2.7 | Notification engagement throttle (5+ sends, 0 opens → 1/week) | [x] *branch: feature/retention-monetization-sprint* |
| P2.8 | Evening mark nudge (8 PM if opened app but didn't mark) | [x] *branch: feature/retention-monetization-sprint* |
| P2.9 | At-risk alerts deep link → Skip Planner (not generic Home) | [x] *branch: feature/retention-monetization-sprint* |
| P2.10 | Tappable FAB → Mark Today scroll/highlight or Skip Planner | [x] *branch: feature/retention-monetization-sprint* |
| P2.11 | Pro purchase Try Again + Restore on failure | [x] *branch: feature/retention-monetization-sprint* |
| P2.12 | Legacy IAP restore (`com.schoolabe.bunkplanner.*`) | [x] *branch: feature/retention-monetization-sprint* |
| P2.13 | Locked forecast free preview line before Go Pro | [x] *branch: feature/retention-monetization-sprint* |
| P2.14 | At-risk Home card → “Plan skips free” entry | [x] *branch: feature/retention-monetization-sprint* |
| P2.15 | Soft paywall cooldown 5 days; at-risk week 3 source | [x] *branch: feature/retention-monetization-sprint* |

**Target after ship:** notif open rate 12% → 25%+ · `day_marked`/WAU > 6 · `skip_planner_viewed` > 15% WAU.

---

## Backlog — Student hub & ecosystem (P5)

**Strategy:** Keep users in-app with everything a student needs — but **connect features to the attendance loop**, not only the Tools tab. Tools tab stays as explorer directory; Home + notifications are the front door.

**North-star metric:** **Multi-feature WAU** — % of weekly actives using **2+ of:** mark / skip planner / focus / forecast / widget.

| ID | Sub-task | Status |
|----|----------|--------|
| P5.1 | Post–Mark Today prompt: “Focus 25 min on [subject]?” → Focus Timer | [x] *branch: feature/retention-monetization-sprint* |
| P5.2 | Focus Timer pre-fill subject tag from last marked subject | [x] *branch: feature/retention-monetization-sprint* |
| P5.3 | After Focus completes → optional “Mark study session?” / return Home | [x] *Live Activity mark prompt* |
| P5.4 | Measure Focus loop: `day_marked` → `focus_timer_started` → next-day `day_marked` | [x] *funnel in [docs/analytics-wow-review.md](docs/analytics-wow-review.md)* |
| P5.5 | Home rotating promo card (weekly): Skip Planner / Focus / Export / Widget | [x] *branch: feature/retention-monetization-sprint* |
| P5.6 | Tools tab subtitle: “More tools” — secondary hub, not primary navigation story | [x] *branch: feature/retention-monetization-sprint* |
| P5.7 | Firebase dashboard: multi-feature user % (2+ features/week) | [x] *`multi_feature_weekly` + user props* |
| P5.8 | Mark `tools_viewed`, `skip_planner_viewed`, `focus_timer_started` as key events | [x] *listed in analytics doc — mark in Firebase console* |
| P5.9 | Exam deadline warning → deep link to Academics/deadlines (126 events, low follow-through) | [x] *branch: feature/retention-monetization-sprint* |
| P5.10 | Widget install prompt on all mark paths (FAB, log, Siri — not only celebration) | [x] *centralized in `recordDayMarked`* |
| P5.11 | Guided setup: ensure fires for new users (currently ~0 events) | [x] *refresh after onboarding + `guided_setup_started`* |
| P5.12 | Share after at-risk: “I can skip N safely” card (viral loop; 2 shares/week today) | [x] *branch: feature/retention-monetization-sprint* |
| P5.13 | Siri / Shortcuts discoverability: Settings tip after streak 3 | [x] *branch: feature/retention-monetization-sprint* |
| P5.14 | **Do not add new tabs** until `skip_planner_viewed` ≥ 15% WAU for 2 weeks | [ ] *guardrail — monitor weekly* |

**Principle:** Focus Timer + GPA + deadlines stay in the product; **lead marketing and Home with attendance → bunk → plan skip → focus**.

---

## Backlog — Marketing & ASO (P6)

**Positioning:** *“Know before you bunk”* — not generic student productivity.

| ID | Sub-task | Status |
|----|----------|--------|
| P6.1 | App Store subtitle: safe bunk / attendance calculator angle | [ ] |
| P6.2 | Screenshot 1: Mark Today (all subjects, one tap) | [ ] |
| P6.3 | Screenshot 2: Skip Planner calendar (“which day can I skip?”) | [ ] |
| P6.4 | Screenshot 3: At-risk + safe bunk count | [ ] |
| P6.5 | Screenshot 4: Semester forecast preview | [ ] |
| P6.6 | Screenshot 5: Widget + Focus Timer (breadth, not lead) | [ ] |
| P6.7 | Keywords: bunk planner, attendance calculator, 75 attendance, skip class | [ ] |
| P6.8 | “What’s New” template: lead core loop, list Tools/Focus as “also included” | [ ] |
| P6.9 | Pro copy everywhere: “Pay once for the semester — know every safe skip” | [ ] |
| P6.10 | India pricing narrative on paywall (₹49 one-time / semester framing) | [ ] |
| P6.11 | Short-form video scripts: at-risk moment → Skip Planner → Pro (Reels/TikTok) | [ ] |
| P6.12 | Referral CTA copy after streak 7 (pairs with 4.7 viral referral) | [ ] |

See also [docs/aso-1.6.6.md](docs/aso-1.6.6.md) for prior ASO notes.

---

## Backlog — Analytics & ops (P7)

Weekly review checklist (export Firebase + AdMob every Saturday).

| ID | Sub-task | Status |
|----|----------|--------|
| P7.1 | Firebase key events: `day_marked`, `notif_opened`, `pro_purchase_succeeded`, `skip_planner_viewed` | [x] *see [docs/analytics-wow-review.md](docs/analytics-wow-review.md)* |
| P7.2 | Funnel: notif scheduled → opened → deep_link → day_marked | [x] *§3.1 in analytics doc* |
| P7.3 | Funnel: soft_paywall → paywall_viewed → started → succeeded/failed (by reason) | [x] *§3.2 in analytics doc* |
| P7.4 | Funnel: banner requested → loaded → shown (by placement) | [x] *§3.3 in analytics doc* |
| P7.5 | Link AdMob revenue → Firebase (unified ARPDAU) | [x] *§4 in analytics doc* |
| P7.6 | WoW dashboard template (DAU, day_marked, Pro $, ad $, D1 retention) | [x] *[docs/analytics-wow-review.md](docs/analytics-wow-review.md)* |
| P7.7 | Cohort compare: 1.7.1 vs sprint branch after ship | [x] *§6 in analytics doc* |

**5× revenue watch (1 week):** Pro + ads ~$2.30 → target **$10+** · Pro success/started > 40% · banner load > 35%.

---

## Backlog — Pricing (P3)

Run **after** P1 ships + 2 weeks of data — do not change price in the same release.

| ID | Sub-task | Status |
|----|----------|--------|
| P3.1 | ₹99 list + ₹69 launch offer for subject-cap / at-risk users | [ ] |
| P3.2 | A/B or time-box: test ₹79 permanent if launch offer converts | [ ] |
| P3.3 | Remote Config / second SKU for regional pricing | [ ] |

**Target:** 4+ Pro sales/week at ≥ ₹69 average.

---

## Backlog — Ads (P4)

Do not enable mediation until banner show-rate ≥ 40% (currently ~15%).

| ID | Sub-task | Status |
|----|----------|--------|
| P4.1 | Diagnose banner fill failures (unit, consent, placement) | [~] *quick retries + consent reset on branch* |
| P4.2 | Mediation network for India (3.8) — after show-rate gate | [ ] |
| P4.3 | Weekly show-rate check in Firebase + AdMob | [ ] |

---

## Later backlog (not this slice)

- [ ] **Firebase viral referral loop** — Auth + Firestore + Functions + Hosting invite links; both sides get 7 days ad-free. Full plan: [docs/plans/firebase-viral-referral.md](docs/plans/firebase-viral-referral.md). Also tracked as **4.7** and **P6.12**.
- [x] **Student hub integration** — P5 complete except P5.14 guardrail monitoring.
- [ ] **Marketing & ASO refresh** — full list in **P6**.
- [ ] India holiday presets (2.6)
- [ ] Mediation (3.8) — wait on show-rate
- [ ] iCloud / CloudKit sync  
- [ ] App Intents / Siri Shortcuts  
- [ ] Full localization  
- [ ] Surface calculation breakdown card  
- [ ] Deeper gamification seasons  
- [ ] Remote push / win-back when semester ends  
- [ ] Remote Config / A-B for paywall & pricing  
- [x] Focus Timer Live Activities *(Lock Screen + Dynamic Island while focus/break runs)*
- [ ] Focus Timer white-noise

Shipped with Pro expansion: skip planner, CSV export (4.5), custom Focus Timer, Sunday weekly digest (2.9).

Shipped v1.8 retention slice: semester progress strip, holiday presets, guided setup, day-2 nudge, Mark Today deep links, widget prompt, market default attendance.

Shipped stickiness: Focus Timer Live Activity on Lock Screen and Dynamic Island.

Shipped habit glue: Focus → Mark prompt on Live Activity; Siri “safest skip this week” + “mark all attended today”.

Shipped Tools tab: unified hub for Focus Timer, CGPA/GPA calculator, and exam deadlines.

**In progress (branch `feature/retention-monetization-sprint`):** notification action routes, engagement throttle, evening mark nudge, tappable FAB, forecast preview, Pro retry, legacy IAP restore, at-risk Skip Planner entry, banner ad retries, **P5 ecosystem hooks + P7 analytics ops doc**.

**Next slice priority:** merge sprint branch → ship → mark Firebase key events in console → **P6.1–P6.7** (ASO) → monitor P5.14 guardrail (skip planner ≥ 15% WAU).

## Notes

- Attendance marks are **additive** (log ↔ subject counters stay in sync).  
- Persistence is **on-device** (Core Data + UserDefaults); App Store updates do not wipe data.  
- Update this file when a sub-task ships.
