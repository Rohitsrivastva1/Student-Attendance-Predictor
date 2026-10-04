# Spec (PARKED): Class event types — Cancelled / Extra / OD / Medical

**Status:** Parked draft — **no Designer/Coder handoff**, **no ROADMAP checkbox flip** until Manager/Rohit greenlights after ship slice.  
**Source:** Researcher landscape brief 2026-09-12; current log model (`AttendanceLogEntry.isHoliday`).  
**Owner:** BunkPlanner BA  
**Date:** 2026-09-12  
**Depends on:** University presets epic preferred first (floors-only dual criteria), but this epic can ship after if Manager reorders.  
**Constraints:** P5.14-safe (no new tabs); floors-first product posture; personal log ≠ official ERP.

---

## Problem

Mark Today today is effectively **Attend / Missed / Holiday**. `isHoliday` zeroes contribution to total and attended. Real Indian classrooms also need:

| Type | Student intent | Typical effect on personal tally |
|------|----------------|----------------------------------|
| **Cancelled** | Class did not run | Exclude from denominator (like holiday for that subject/period) |
| **Extra** | Extra / makeup lecture held | Increase scheduled (+ optionally attended if present) |
| **OD** | On duty / official activity | Often credited as present by college policy — **user-configurable credit** |
| **Medical** | Medical leave | Often excluded or specially handled; **do not invent condonation fees** |

Competitors (BunkWell cancelled/extra/exchange; RollCall users asking for cancelled) win realism here. Bundling everything into “Holiday” makes Safe/Critical and bunk runway wrong.

**Explicitly out of scope:** proxy attendance, biometric spoof tips, claiming OD/Medical will be accepted by the college.

---

## Goals

1. First-class mark reasons beyond Attend / Missed / Holiday.
2. Forecast, Skip Planner, streak, widgets, and dual-criteria engine (when presets ship) all respect the same contribution rules.
3. Clear UX copy + ERP disclaimer; no cheat framing.
4. Free for core mark types (correctness); do not Pro-gate Cancelled.

## Non-goals

- Auto-import from college portal.
- Legal determination of OD/Medical eligibility.
- New top-level tabs or replacing Mark Today.

---

## Current baseline

- `AttendanceLogEntry`: `scheduledClasses`, `attendedClasses`, `isHoliday`.
- Holiday → `totalContribution = 0`, `attendedContribution = 0`.
- Streak: holidays do not break streak.
- DayMarkStatus maps holiday to neutral “Holiday” legend.
- Semester holiday presets adjust Forecast Assumptions count (separate from daily mark type).

---

## Contribution rules (v1)

Coder may rename enums; semantics are normative.

| Mark | scheduled Δ | attended Δ | Breaks streak? | Notes |
|------|-------------|------------|----------------|-------|
| Attended | +N | +N | No (counts as marked) | Existing |
| Missed | +N | +0 | Yes if all missed that day | Existing |
| Holiday | 0 | 0 | No | Keep for full-day college closed |
| **Cancelled** | 0 | 0 | No | Prefer for *this subject/period didn’t run*; distinct label in UI/log |
| **Extra (attended)** | +N | +N | No | N default 1; user can bump |
| **Extra (missed)** | +N | +0 | Per streak rules | Optional sub-choice |
| **OD** | +N | +N **or** 0 based on setting | No if credited | Default **credit as attended** for India; setting: “Count OD as present” |
| **Medical** | 0 | 0 | No | v1 = exclude from tally (same math as cancelled); copy says college may treat differently |

**Phase 2 (not this parked v1):** Anna-style medical recalculation bands; separate “medical with certificate” vs without; exchange/swap class with another subject.

---

## Stories

### US-CE-1 — Mark reason on Mark Today

**As a** student,  
**I want** to mark Cancelled, Extra, OD, or Medical for today’s class,  
**so that** my % matches how the day actually went.

**Acceptance criteria**

1. Mark Today (single + all-subjects) exposes reasons: Attend, Missed, Holiday, Cancelled, Extra, OD, Medical (Holiday may stay for “college closed”; Cancelled for “this lecture dropped”).
2. Choosing Extra asks attended vs missed (or stepper for count) before save.
3. OD uses the “Count OD as present” setting (default on for IN market).
4. Medical applies exclude-from-tally rule; shows one-line note: college rules vary; this is your personal log.
5. Existing holiday preset / Forecast holiday count unchanged by daily Cancelled marks (different concepts).
6. Analytics: `day_marked` includes `mark_reason` enum; no PII.
7. Free tier: all reasons available (not Pro-gated).

**Edge cases**

- Timetable gap (0 scheduled): Extra still allowed (creates scheduled Δ); Cancelled with 0 scheduled is no-op with gentle empty state.
- Multi-period day: reason applies to periods being marked in that action.
- Editing a past log day: same reasons; additive counters stay in sync (existing invariant).

---

### US-CE-2 — Log, Insights, and export reflect reasons

**As a** student reviewing the week,  
**I want** Cancelled / OD / Medical visible on the calendar and in exports,  
**so that** I can explain gaps to myself or parents.

**Acceptance criteria**

1. Calendar DayMarkStatus (or extension) distinguishes Cancelled / OD / Medical / Extra from plain Holiday (color + legend).
2. Insights “This Week” counts: attended, missed, cancelled, OD, medical, extras — at least attended/missed/cancelled in v1; others may fold into a “other” bucket if UI tight.
3. CSV export (Pro) adds a `reason` column; PDF report lists reason labels.
4. Streak logic follows contribution table above.

**Edge cases**

- Legacy entries with only `isHoliday=true` migrate to reason Holiday.
- Unknown future reasons: fail closed to Missed or Holiday only if corrupt; prefer migration map.

---

### US-CE-3 — Bunk math & dual criteria respect exclusions

**As a** student planning skips,  
**I want** Cancelled/Medical exclusions and Extra lectures to change safe-bunk math,  
**so that** runway isn’t fiction.

**Acceptance criteria**

1. Safe bunk / recovery / Skip Planner use contribution rules from this doc.
2. When university presets exist: excluding a cancelled class must not falsely push a subject under its floor; adding Extra attended improves % correctly.
3. Widgets refresh after reason marks (same snapshot pipeline).
4. Offline: all reason marks work without network.

---

### US-CE-4 — Trust copy

**Acceptance criteria**

1. First use of OD or Medical shows short disclaimer (dismissible): personal tracker; college ERP/biometric is official; OD/Medical acceptance is the college’s call.
2. No copy that coaches proxy attendance or faking biometric.
3. Settings toggle: “Count OD as present” with helper text.

---

## Design notes

- Mark Today: primary Attend / Missed; secondary “More” sheet for Holiday / Cancelled / Extra / OD / Medical (avoid 7 equal buttons).
- Legend on Log tab updated; keep accessible contrast.
- Don’t add a new tab (P5.14).

## Pro vs free

- Core reasons + math: **free**.
- CSV/PDF already Pro — just extend columns/labels.

## Trade-offs (Manager)

1. Medical v1 = exclude-only (not Anna recalculation) — avoids fake legal precision.
2. OD default credit-as-present may disagree with some colleges — mitigated by toggle + disclaimer.
3. Extra on free path slightly increases mark UI complexity — worth it vs Android competitors.
4. Ship after university presets preferred so dual floors + reasons compose; if presets slip, CE can still ship on single-%.

## Test matrix

| Case | Expect |
|------|--------|
| Cancelled 1 lecture | % unchanged; scheduled not incremented |
| Extra attended | scheduled +1, attended +1; % up or stable |
| OD with credit on | same as attended |
| OD with credit off | same as missed (scheduled +1, attended +0) |
| Medical | same contribution as cancelled; distinct label |
| Holiday full day | unchanged legacy behavior |
| Skip Planner after cancelled mid-week | runway uses reduced remaining classes correctly |

## Handoff (when unparked)

- Designer: More-sheet + legend  
- Coder: model migration + Contribution rules + Mark Today / Log / export / widgets  
- Researcher: optional per-uni OD/Medical policy notes (not blocking)  
- Manager: sequence vs presets + 1.7.2 ship  

---

*Parked — do not flip ROADMAP items until approved.*
