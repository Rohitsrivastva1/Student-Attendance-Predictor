# Spec: University attendance presets + dual criteria

**Status:** Parked draft (updated) — no Designer/Coder handoff until Rohit confirms  
**Source:** Researcher landscape brief 2026-09-12 + JNTU verified note 2026-09-12 + ROADMAP.md (v1.8)  
**Owner:** BunkPlanner BA  
**Date:** 2026-09-12 (JNTU rows added same day)  

---

## Problem

Bunk Planner today stores a **single** required % (default 75 IN / 80 US·UK via `StudentMarket`). Real India rules are not one number:

| Preset id | Label | Overall | Per subject / course | Notes |
|-----------|-------|---------|----------------------|-------|
| `custom` | Custom | user | optional user | Always available |
| `ugc_75` | UGC floor | ≥75% avg | — | Regulatory floor, not identical everywhere |
| `du_ordinance_vii` | Delhi University | ~66.7% (two-thirds) | together | Ordinance VII |
| `mumbai_o6086` | Mumbai (O.6086) | ≥75% avg | ≥50% each course | Dual criteria |
| `anna_ud_ar2023` | Anna University UD | — | ≥75% each course | Medical path from 65% (phase 2) |
| `vtu_be` | VTU | — | ≥85% each subject | Condonation up to 10% (phase 2 copy only) |
| `jntuh_btech` | JNTUH B.Tech | ≥75% aggregate | — (aggregate only) | Condonation band 65%–<75% (copy only v1); hard floor <65% |
| `jntua_btech_r23` | JNTUA B.Tech (R23) | ≥75% aggregate | ≥40% each subject | Dual criteria; same condonation band copy |

Hardcoding 75% causes wrong Safe/Warning/Critical and bunk math for DU / VTU / Mumbai / JNTU students. Competitors get review complaints for inflexible defaults.

**Do not merge** `jntuh_btech` and `jntua_btech_r23` — Hyderabad is aggregate-only; Anantapur adds a 40% per-subject floor.

**Out of scope this epic:** JNTUK (await `jntuk.edu.in` primary). Gujarat University (secondary source only). Official ERP sync. Proxy / cheat tooling. Publishing fine/fee amounts as facts. Mid-term “2 periods credited” quirk for JNTUH (phase 2 — document in copy only if productized later).

---

## Goals

1. Student can pick a **university preset** or **Custom** during onboarding and in Settings.
2. Engine evaluates **overall and/or per-subject** thresholds from the preset.
3. Home, Mark Today impact, Forecast, Skip Planner, widgets, and notifications all use the **same** criteria engine.
4. Copy never claims college ERP/biometric is replaced.

## Non-goals

- Auto-detect university from GPS or email.
- Legal advice about condonation / detainment.
- Changing Pro pricing or free subject caps.

---

## Current baseline (do not regress)

- Single `requiredPercentage` / `defaultRequiredPercentage` in `AttendanceViewModel`.
- Market default once on first launch (`applyMarketDefaultAttendanceIfNeeded`).
- Subject risk: Safe / Warning / Critical from % vs target.
- Mark types today: Attend / Missed / Holiday (`isHoliday` only).
- Widgets mirror glance % + safe bunks.

---

## Epic stories

### US-UP-1 — Pick attendance rule preset

**As a** student in India,  
**I want** to choose my university’s attendance rule (or Custom),  
**so that** Safe/Critical and bunk counts match what my college actually enforces.

**Acceptance criteria**

1. Onboarding (or first Settings visit if skipped) offers presets: **Custom**, **UGC 75%**, **Delhi University (~66.7%)**, **Mumbai (75% avg + 50%/course)**, **Anna (75%/course)**, **VTU (85%/subject)**, **JNTUH B.Tech** (`jntuh_btech`), **JNTUA B.Tech R23** (`jntua_btech_r23`).
2. Selecting a preset writes both overall and per-subject rules into persistent settings; Custom keeps editable % fields. Engine must support **aggregate-only** (e.g. JNTUH, UGC, DU) and **dual** overall + per-subject floor (e.g. Mumbai, JNTUA).
3. Changing market (IN/US/UK) does **not** wipe a manually chosen university preset; if none chosen, keep existing market default behavior (75 / 80).
4. Settings shows current preset name + short rule summary (e.g. “75% average and ≥50% in each course”; JNTUH: “75% semester aggregate”; JNTUA: “75% aggregate and ≥40% per subject”).
5. Analytics: `attendance_preset_selected` with preset id (no PII) — use ids `jntuh_btech` / `jntua_btech_r23` exactly.
6. **No JNTUK** preset until Researcher verifies a `jntuk.edu.in` primary PDF. Do not offer a generic “JNTU” merged preset.
7. For JNTUH / JNTUA: show optional helper copy for condonation band (65%–<75% aggregate, committee + fee) and hard floor (<65% → typically detained). **v1 math uses eligibility floors only** (75% / 40%); condonation is informational, not a third engine mode.

**Edge cases**

- Returning user with only a numeric target → migrate to Custom with that number as overall; per-subject = same value (preserves today’s math).
- Empty subject list → preset still saves; risk states stay neutral until first mark (existing “0% vs target is not at risk” rule).

---

### US-UP-2 — Dual-criteria evaluation engine

**As a** student under Mumbai-style rules,  
**I want** the app to fail Safe if **either** overall **or** any course is below its floor,  
**so that** a good average doesn’t hide a sinking subject.

**Acceptance criteria**

1. Introduce a shared criteria model, e.g. `AttendanceCriteria { overallMin: Double?; perSubjectMin: Double?; aggregation: .average | .perSubjectOnly | .overallOnly }` (names flexible for Coder).
2. **Per subject status** uses `perSubjectMin` when set; else falls back to overallMin.
3. **Portfolio / Home hero status** is the worse of: (a) overall % vs overallMin when overallMin set; (b) worst subject vs its floor.
4. Safe bunk / “attend N consecutive” math must not recommend a skip that would push **any** constrained subject below its floor when `perSubjectMin` is set.
5. Forecast subject rows show both subject % and distance to **that subject’s** floor; overall strip shows overall when applicable.
6. Unit tests (or CalculationService tests) cover: Mumbai 75/50, DU 66.7 overall-only, Anna/VTU per-subject-only, JNTUH 75 aggregate-only, JNTUA 75+40 dual, Custom equal floors.

**Edge cases**

- Timetable gaps / zero scheduled week: don’t mark Critical solely from empty schedule.
- Holiday marks: continue to contribute 0 to total/attended (existing additive log rules).
- Planned bunks in Forecast: subtract from runway without double-counting holidays.

---

### US-UP-3 — Mark Today “impact of skipping this class”

**As a** student deciding this morning,  
**I want** to see what happens to my % **if I skip this subject’s class today**,  
**so that** I can choose Attend vs Missed in under 5 seconds.

**Acceptance criteria**

1. On Mark Today (single and all-subjects flow), each subject row shows current status chip (Safe / Warning / Critical) using US-UP-2 engine.
2. Before confirming Missed (or on Missed preview), show: projected % and whether status worsens; if dual criteria, call out **which** floor is violated (overall vs this course).
3. Widgets and Lock Screen metrics use the same engine (no stale single-75 assumption).
4. Ads must not block or delay this mark path (trust requirement from research; keep banners off Mark Today interaction).

**Edge cases**

- Partial day (multiple periods): impact math uses the periods being marked, not the whole week.
- Free subject cap: Pro upsell may appear after mark, not mid-impact preview.

---

### US-UP-4 — Disclaimer: personal log ≠ official ERP

**As a** student using biometric / college portal attendance,  
**I want** a clear disclaimer,  
**so that** I don’t treat Bunk Planner as the official record.

**Acceptance criteria**

1. First time after selecting any university preset, show a one-time sheet/banner: personal tracker only; college ERP/biometric is official.
2. Same line available under Settings → About / Attendance rules.
3. Copy avoids proxy, cheat, or “beat the biometric” framing.

---

## Design notes (for Designer)

- Preset picker: searchable list + “Custom” at top; each row = name + one-line rule.
- Rule summary chip on Home near hero % when dual criteria (e.g. “Mumbai 75/50”).
- Impact preview: compact, not a modal essay — % delta + status change.
- Keep India-first wording; US/UK markets still see Custom + market default unless we later add region presets.

## Pro vs free

- Presets + dual engine are **free** (trust / correctness).
- Do not gate correct thresholds behind Pro.
- Existing Pro surfaces (Forecast depth, Skip Planner, PDF, subject cap) unchanged by this epic.

## Trade-offs (flag to Manager)

1. **Scope vs ship:** Presets without condonation math (Anna medical 65%, VTU 10%) is intentional v1 — document as “eligibility floor only.”
2. **Migration:** Auto-Custom migration preserves numbers but may leave Mumbai students on wrong dual rules until they pick the preset — surface preset prompt once for India market users with default 75.
3. **P5.14 guardrail:** This epic does **not** add tabs; Settings + onboarding only.
4. **JNTU:** Ship `jntuh_btech` + `jntua_btech_r23` as separate presets (Researcher verified 2026-09-12). Hold **JNTUK**. Condonation bands = copy only in v1; eligibility floors drive Safe/Critical.

## Handoff

- **Coder:** implement criteria model + migrate defaults; wire Home / Mark Today / Forecast / widgets.
- **Designer:** preset picker + impact preview + disclaimer sheet.
- **Researcher:** JNTUH/JNTUA done; next JNTUK primary + Gujarat if productizing. Mid-term 2-period quirk = phase 2.
- **Manager:** prioritize vs 1.7.2 ship checklist and referral deploy.

## Test matrix (QA-minded)

| Case | Expect |
|------|--------|
| Mumbai preset, overall 80%, one course 45% | Portfolio Critical; that course Critical; others may be Safe |
| DU preset, overall 70% | Safe (≥66.7) |
| VTU preset, subject 84% | Critical for that subject |
| JNTUH, aggregate 70%, all subjects ok | Warning/Critical vs 75% floor; helper may mention condonation band (copy only) |
| JNTUH, aggregate 60% | Critical (below hard floor); do not invent fee amounts |
| JNTUA, aggregate 80%, one subject 35% | Portfolio Critical (per-subject 40% failed) |
| JNTUA, aggregate 70%, all subjects ≥40% | Below 75% aggregate → not Safe; dual engine applies both floors |
| Custom 75, legacy user | Same math as today |
| Skip preview that would drop subject under floor | Warn / block “safe skip” claim |
| Offline | Criteria + impact work with no network |

---


## JNTU sources (verified)

- JNTUH R22: https://jntuh.ac.in/uploads/academics/R22B.Tech.RevisedAcademicRegulations.pdf (§6)
- JNTUH R25: https://jntuh.ac.in/uploads/bulletins/R25B.Tech.AcademicRegulationsV2.pdf (§7)
- JNTUA R23: https://www.jntuacep.ac.in/departments/dept-of-ece/JNTUA%20-%20UG%20Programmes%20-%20B.Tech.%20-%20R23%20Regulations%2031.08.2023.pdf (§17)
- Researcher write-up: `/workspace/bunkplanner-research/jntu-attendance-verified-2026-09-12.md`

## Related backlog (not this doc)

See companion brief: class event types (Cancelled / Extra / OD / Medical), timetable share QR/link, restore-trust checklist — prioritized from same research brief.
