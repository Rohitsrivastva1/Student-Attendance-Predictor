# Manual test checklist — Bunk Planner

Use a **DEBUG build** on device or simulator. Open **Debug tools** via the orange ladybug on Home (or Settings → Debug tools) to toggle **Premium (Pro)** without paying.

**Pass criteria:** Expected result happens · No crash · Correct analytics event in Xcode console (DEBUG) or Firebase DebugView.

---

## 0. Setup

| Step | Action | Expected |
|------|--------|----------|
| 0.1 | Fresh install (delete app) | Onboarding 4 screens → Get Started |
| 0.2 | Skip onboarding | Home loads; guided setup banner “Step 1 · Add a subject” |
| 0.3 | Debug → Enable Premium | Pro ON; ads hidden; skip planner unlocked |
| 0.4 | Debug → Reset guided setup | Coach mark reappears on Home |

---

## 1. Home — daily loop

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| H1 | Add subject | Books icon → add subject | Subject appears; guided setup → Step 2 |
| H2 | Mark Today — attended | Mark Today → Yes on one subject | % updates; celebration; `day_marked` |
| H3 | Mark Today — all subjects | Mark remaining subjects | Post-mark Focus prompt; widget prompt (first time) |
| H4 | Post-mark Focus | Accept “Focus 25 min” | Focus sheet opens; subject tagged |
| H5 | Mark Today highlight | Notification/deep link `mark_today` | Scroll/highlight Mark Today card |
| H6 | Subject picker | Tap subject chip | Bottom sheet; switch subject |
| H7 | Hero metrics | After marks | %, bunks left, status update |
| H8 | Semester strip | Set semester dates in Forecast | “Week N of M” on Home |
| H9 | Contextual FAB | Morning / evening / at-risk states | FAB copy changes; tap → Mark or Skip Planner |
| H10 | At-risk card | Drop attendance below target | “Plan skips free” → Skip Planner sheet |
| H11 | At-risk share | Status = risk | Share card → Share sheet |
| H12 | Pro upsell (Free) | Disable Pro in Debug | Upsell card on Home |
| H13 | Home promo card | View weekly promo | Tap → Skip / Focus / Export / Widget action |
| H14 | Exam warning | Add exam deadline ≤7 days (Tools) | Orange warning on Home → tap → Exam Deadlines |
| H15 | Share result | Share from Home | Share sheet with bunk/skip text |
| H16 | Banner ad (Free) | Disable Pro; stay on Home 2s | Banner loads (or retry); hidden when Pro ON |

---

## 2. Mark Today (multi-subject)

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| M1 | Single tap attended | Yes on subject | Row checkmark; counters sync |
| M2 | Missed | Missed on subject | Attendance drops |
| M3 | Holiday | Holiday toggle | No class impact |
| M4 | Mark all flow | Multiple subjects same day | Auto-advance; all-done celebration |
| M5 | Re-mark | Change choice same day | Counters adjust (additive log) |

---

## 3. Log tab

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| L1 | Calendar view | Open Log | Month grid per subject |
| L2 | Edit day | Tap day → Save attended/missed | `day_marked` source `day_editor`; widget prompt |
| L3 | Clear day | Clear this day | Entry removed; totals recalc |
| L4 | Holiday in log | Mark holiday in editor | Excluded from % |

---

## 4. Insights

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| I1 | This Week summary | Mark some days | Attended / missed / delta |
| I2 | Streak | Consecutive attended days | Streak count; share streak card |
| I3 | Forecast accordion | Expand subject | Safe / Warning / Critical |
| I4 | Planned bunks input | Change planned bunks | Forecast recalculates |
| I5 | Locked forecast (Free) | Disable Pro | Preview line + Go Pro |
| I6 | Forecast unlocked (Pro) | Enable Pro | Full semester forecast |
| I7 | Semester assumptions | Edit end date | Weeks remaining updates |
| I8 | Holiday preset | Apply India preset | College holidays applied |
| I9 | Banner (Free) | Tab to Insights | Banner only while tab active |

---

## 5. Overview (All subjects)

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| O1 | Dashboard cards | 2+ subjects | Safe/risk per subject |
| O2 | Add / delete subject | Manage subjects | Free: max 3 subjects; Pro: unlimited |
| O3 | Timetable | Edit classes/week | Mark Today uses schedule |
| O4 | Subject limit (Free) | Add 4th subject | Limit alert → Pro paywall |

---

## 6. More (Tools) tab

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| T1 | Tab label | Open More tab | “More tools” header; `tools_viewed` |
| T2 | Focus Timer | Start 25 min session | Timer runs; Live Activity on device |
| T3 | Focus subject tag | Tag subject before start | Subject on Live Activity |
| T4 | Focus complete | Finish session | Mark prompt on Live Activity |
| T5 | Pro duration (Free) | Try 90 min focus | Locked / clamp to 25 |
| T6 | Grades / CGPA | Add course + grade | GPA/CGPA calculates |
| T7 | Exam deadlines | Add exam T+3 days | Countdown; T-7/T-3/T-1 notifications |
| T8 | Skip Planner (Pro) | Open from Tools | Week calendar; safe/mixed/unsafe days |
| T9 | Skip Planner (Free) | Disable Pro | Locked overlay → paywall |
| T10 | Export PDF (Pro) | Export Reports → PDF | Share PDF |
| T11 | Export CSV (Pro) | Export CSV | Share file |
| T12 | Export locked (Free) | Tap export | Pro paywall |

---

## 7. Skip Planner

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| S1 | From at-risk card | Home → Plan skips | Sheet with today’s evaluation |
| S2 | From promo / FAB | Tap skip entry points | `skip_planner_viewed` |
| S3 | Day tap | Select day in planner | Per-subject safe/unsafe if Pro |
| S4 | From notification | Open risk notif | Lands on Skip Planner (not generic Home) |

---

## 8. Pro & paywall

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| P1 | Debug Pro toggle | Debug → Premium ON | All Pro features; ads off |
| P2 | Paywall (Free) | Forecast lock / subject cap | Outcome copy; price shown |
| P3 | Purchase (sandbox) | Buy Pro on device sandbox | Restore; `pro_purchase_succeeded` |
| P4 | Restore | Paywall → Restore | Legacy IAP IDs honored |
| P5 | Try Again on fail | Simulate failed purchase | Retry + Restore buttons |
| P6 | Soft paywall | 7-day streak / at-risk week 3 | Soft paywall after delay |

---

## 9. Notifications

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| N1 | Permission | First launch / settings | Permission prompt |
| N2 | 8 PM mark nudge | Open app, don’t mark | Evening notification |
| N3 | Open notification | Tap notif | Deep link → Mark Today or Skip Planner |
| N4 | Witty copy toggle | Settings off witty | Plain reminder text |
| N5 | Exam reminders | Deadline in 3 days | T-3 notification |
| N6 | Sunday digest (Pro) | Pro + notifications on | Weekly digest scheduled |
| N7 | Engagement throttle | 5+ sends, 0 opens | Reduced to 1/week |

---

## 10. Widgets & Siri

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| W1 | Widget prompt | First mark any path | Alert with install instructions |
| W2 | Home Screen widget | Add widget | Shows % and safe bunks |
| W3 | Lock Screen widget | Add lock widget | Glance metrics |
| W4 | Siri mark all | “Mark all attended in Bunk Planner” | All today’s subjects marked |
| W5 | Siri safest skip | “Safest skip this week” | Spoken day recommendation |
| W6 | Siri tip | Streak ≥3 → Settings | Siri & Shortcuts section |

---

## 11. Settings

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| ST1 | Default % | Change default required % | New subjects use default |
| ST2 | Region override | Pick market | Bunk vs skip copy changes |
| ST3 | Notifications toggle | Off | Risk reminders cancelled |
| ST4 | Reset inputs | Reset | Calculator cleared |
| ST5 | Privacy / Terms | Open links | Pages load |
| ST6 | Debug tools | Ladybug / Settings Debug | Pro toggle + resets |

---

## 12. Onboarding & guided setup

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| G1 | First run onboarding | Delete app; install | 4 screens; `onboarding_completed` |
| G2 | Guided Step 1 | 0 subjects after onboarding | Banner; tap → subjects sheet |
| G3 | Guided Step 2 | Subject, no mark | “Mark today” banner |
| G4 | Guided complete | Mark today | Banner gone; `guided_setup_completed` |
| G5 | Dismiss guide | Tap ✕ on banner | `guided_setup_dismissed` |

---

## 13. Analytics smoke (DEBUG console)

After each flow, confirm event names:

| Event | Trigger |
|-------|---------|
| `day_marked` | Any mark |
| `skip_planner_viewed` | Open planner |
| `focus_timer_started` | Start focus |
| `tools_viewed` | Open More tab |
| `exam_attendance_warning_tapped` | Tap exam card |
| `guided_setup_started` | First coach mark |
| `multi_feature_weekly` | 2+ features same week |
| `widget_prompt_shown` | After first mark |
| `post_mark_focus_prompt_accepted` | Accept focus after mark |

---

## 14. Regression — data & ads

| ID | Test | Expected |
|----|------|----------|
| R1 | Kill app after mark | Data persists (Core Data) |
| R2 | Tab switch | Banners only on active tab |
| R3 | Pro ON | No banner / interstitial / app-open ads |
| R4 | App update simulation | Reinstall over existing data path — no wipe |

---

## Quick smoke (15 min)

1. Onboarding → add subject → mark today  
2. Debug Pro ON → Skip Planner → Forecast → PDF export  
3. Focus 25 min → complete → mark prompt  
4. Add exam deadline → Home warning → tap through to deadlines  
5. Debug Pro OFF → confirm paywall on locked features  
6. Notification tap → Mark Today highlight  

---

**Note:** Debug tools (ladybug) appear only in **Debug** configuration, not App Store / Release builds.
