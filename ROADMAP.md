# Bunk Planner: Attendance Track — Roadmap

Living tracker. Checkboxes: `[x]` done · `[~]` partial · `[ ]` not started.

---

## v1.7 — Current ship (UX + ads hygiene)

Already implemented in the working tree (ship this first).

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
- [x] Quiet mode rewarded CTA (Hide ads 24h) on Home / Insights

### Ads & notifications
- [x] Banner: shared unit + 1.5s dwell + only while tab active
- [x] Insights / Overview banners restored (active-tab gated)
- [x] App-open cold-start show fix; interstitial present snappier
- [x] 8 PM mark reminder + Mon kickoff + Fri buffer nudges
- [x] Local data survives App Store updates (Core Data / UserDefaults)

---

## v1.8 — Massive release: Habit + Semester OS

**Theme:** *Know before you bunk — track every day, plan the semester.*

### Pillar 1 — Daily loop (DAU)

| ID | Sub-task | Status |
|----|----------|--------|
| 1.1 | Home Screen widget: current % + safe bunks left | [ ] |
| 1.2 | Lock Screen widget: same glance metrics | [ ] |
| 1.3 | 8 PM “Did you mark today?” reminder | [x] |
| 1.4 | Monday kickoff reminder | [x] |
| 1.5 | Friday bunk-buffer reminder | [x] |
| 1.6 | Reminder copy uses live subject % / bunks (personalized) | [~] *generic copy today* |
| 1.7 | Streak display on Insights | [x] |
| 1.8 | Shareable streak card (“12-day streak”) | [ ] |
| 1.9 | Mark Today — single subject (one-tap) | [x] |
| 1.10 | Mark Today — **all subjects today** in one flow | [ ] |
| 1.11 | Morning / evening multi-subject prompt variants | [ ] |

**Pillar 1 progress:** 5 done · 1 partial · 5 open

---

### Pillar 2 — Semester brain (retention)

| ID | Sub-task | Status |
|----|----------|--------|
| 2.1 | Semester start/end stored (`SemesterSettings`) | [x] |
| 2.2 | Forecast weeks auto from semester end | [x] |
| 2.3 | Semester dates editable in Forecast Assumptions | [x] |
| 2.4 | “Classes left this semester” on Home / subject cards | [ ] |
| 2.5 | Classes left uses timetable × weeks − holidays − bunks | [ ] |
| 2.6 | India holiday presets (e.g. Diwali week) — light | [ ] |
| 2.7 | Apply holiday preset → College Holidays count | [ ] |
| 2.8 | Insights “This Week” attended / bunks / delta | [x] |
| 2.9 | Weekly digest **notification** (Sun/Mon summary) | [ ] |
| 2.10 | Semester progress strip (week N of M) | [ ] |

**Pillar 2 progress:** 4 done · 0 partial · 6 open

---

### Pillar 3 — Money (without killing UX)

| ID | Sub-task | Status |
|----|----------|--------|
| 3.1 | Pro IAP + restore | [x] |
| 3.2 | Rewarded “Hide ads 24h” (Settings + Home Quiet mode) | [x] |
| 3.3 | Forecast lock → watch ad / Go Pro | [x] |
| 3.4 | At-risk Home moment → Watch ad / Go Pro (contextual) | [~] *Quiet mode exists; not tied to risk state* |
| 3.5 | Forecast unlock UX feels native (less “ad wall”) | [~] *improved accordion; lock CTA still separate* |
| 3.6 | Soft paywall after 7-day streak | [ ] |
| 3.7 | Soft paywall after 3rd at-risk week | [ ] |
| 3.8 | One mediation network for India | [ ] *after show-rate check* |
| 3.9 | Measure show rate ≥40% before mediation | [ ] *ops / post-ship* |

**Pillar 3 progress:** 3 done · 2 partial · 4 open

---

### Pillar 4 — Trust / share (growth)

| ID | Sub-task | Status |
|----|----------|--------|
| 4.1 | Share result image + text from Home | [x] |
| 4.2 | Share card polish (“I can bunk N safely”) | [~] *works; needs visual refresh* |
| 4.3 | Welcome empty → Get Started first-value path | [x] |
| 4.4 | First-run: add subject → Mark Today guided | [ ] |
| 4.5 | CSV export of attendance log | [ ] |
| 4.6 | Optional PDF one-pager (later if CSV ships) | [ ] |

**Pillar 4 progress:** 2 done · 1 partial · 3 open

---

### Pillar 5 — US / UK market (expansion)

| ID | Sub-task | Status |
|----|----------|--------|
| 5.1 | Locale market detection + Settings override (`StudentMarket`) | [x] |
| 5.2 | Region-aware copy (bunk vs skip) on Home + share | [x] |
| 5.3 | Grades tab: US 4.0 GPA calculator | [x] |
| 5.4 | Exams & deadlines list with countdown | [x] |
| 5.5 | Default attendance target by market (75 IN / 80 US·UK) | [~] *suggested in Settings Region; not auto-applied on first launch* |
| 5.6 | UK module % / degree classification calculator | [ ] |
| 5.7 | Soften India-only holiday presets; add US/UK breaks later | [ ] |
| 5.8 | App Store localization (en-GB + en-US metadata) | [ ] |

**Pillar 5 progress:** 4 done · 1 partial · 3 open

---

## v1.8 totals

| Pillar | Done | Partial | Open |
|--------|------|---------|------|
| 1 Daily loop | 5 | 1 | 5 |
| 2 Semester brain | 4 | 0 | 6 |
| 3 Money | 3 | 2 | 4 |
| 4 Trust / share | 2 | 1 | 3 |
| 5 US / UK market | 4 | 1 | 3 |
| **Total** | **18** | **5** | **21** |

**~47% complete** if partial counts as half ≈ **20.5 / 44** story points.

---

## Suggested build order for v1.8

1. **1.10 + 1.11** — Multi-subject Mark Today (biggest DAU lever)  
2. **2.4 + 2.5** — Classes left this semester on Home  
3. **3.4 + 3.6** — At-risk / streak soft monetization  
4. **1.1 + 1.2** — Widgets (store “massive” signal)  
5. **2.6 + 2.9** — India holidays + weekly digest notif  
6. **1.8 + 4.2 + 4.5** — Share streak + share polish + CSV  
7. **5.6 + 5.8** — UK classification + Store metadata for US/UK  
8. **3.8** — Mediation only after show-rate data  

---

## Later backlog (not v1.8)

- [ ] iCloud / CloudKit sync  
- [ ] App Intents / Siri Shortcuts  
- [ ] Full localization  
- [ ] Surface calculation breakdown card  
- [ ] Deeper gamification seasons  

## Notes

- Attendance marks are **additive** (log ↔ subject counters stay in sync).  
- Persistence is **on-device** (Core Data + UserDefaults); App Store updates do not wipe data.  
- Update this file when a sub-task ships; move v1.7 block to “Shipped” after App Store release.
