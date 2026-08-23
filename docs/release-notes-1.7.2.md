# Bunk Planner 1.7.2 — Release notes

**Theme:** Retention sprint + student hub hooks — keep users in the attendance loop.

- Marketing version: **1.7.2**
- Build: **20**

---

## Highlights

### Habit & notifications
- Notification deep links → Mark Today highlight or Skip Planner (not generic Home)
- Evening mark nudge if you opened the app but didn’t mark
- Notification engagement throttle for disengaged users
- Tappable FAB scrolls/highlights Mark Today or opens Skip Planner

### Student hub (Home ↔ Tools)
- Post–Mark Today → optional Focus session on that subject
- Home weekly promo card (Skip / Focus / Export / Widget)
- Tools tab as **More** — secondary hub copy
- Exam deadline warning on Home → tap through to Exam Deadlines
- Share prompt when attendance is at-risk
- Siri & Shortcuts tip in Settings after streak 3
- Widget install prompt on all mark paths (log, Siri, Mark Today)
- Guided setup coach marks fire correctly after onboarding

### Pro & monetization
- Paywall Try Again + Restore on purchase failure
- Legacy IAP restore (`com.schoolabe.bunkplanner.*`)
- Soft paywall 5-day cooldown; at-risk week 3 source
- Locked forecast free preview line before Go Pro
- At-risk Home → “Plan skips free” entry
- Banner ad quick retries + consent reset

### Academics UI
- Redesigned CGPA / GPA and Exam Deadlines empty states
- Nav bar **+** for add; cleaner cards and target CGPA fields

### Analytics (ops)
- Multi-feature WAU tracking (`multi_feature_weekly`)
- WoW review template: [analytics-wow-review.md](analytics-wow-review.md)
- Manual QA checklist: [manual-test-checklist.md](manual-test-checklist.md)

### Debug (DEBUG builds only)
- Ladybug debug tools: enable Pro, reset coach marks / prompts

---

## App Store — What’s New (suggested)

**Know before you bunk — faster.**

• Mark all subjects in one tap, then jump into a Focus session  
• Plan which day to skip from Home and notifications  
• Exam deadline reminders with a tap-through to your dates  
• Smoother Pro restore and paywall retry  
• Cleaner CGPA and exam deadline screens  

Also included: widgets, semester forecast, and More tools (Focus, grades, exports).

---

## Pre-ship checklist

- [ ] Release archive (scheme: Student Attendance Predictor, Release)
- [ ] Smoke test on device ([manual-test-checklist.md](manual-test-checklist.md))
- [ ] Sandbox Pro purchase + Restore
- [ ] TestFlight internal → production
- [ ] Firebase: mark key events in console
