# App Store ASO — Bunk Planner 1.6.6

Tuned for search reach in India first, US/UK second.
On iOS, only **Name, Subtitle, and Keywords** affect search ranking; the **description affects conversion**.

---

## Name — 30 char limit (search weight: highest)

```
Bunk Planner: Attendance, CGPA
```

Exactly 30 chars. "attendance" and "CGPA" are the two highest-volume terms; the name field ranks strongest.

---

## Subtitle — 30 char limit (search weight: second)

```
75% Calculator, GPA & Grades
```

28 chars. "Calculator" pairs with name words to form "attendance calculator" and "cgpa calculator".

---

## Keywords — 100 char limit

No spaces after commas. Do not repeat words already in Name or Subtitle.

```
skip,class,college,student,semester,lecture,absent,detention,sgpa,timetable,exam,proxy,percentage
```

99 chars. Apple auto-combines fields (e.g. "skip class", "college attendance", "sgpa calculator", "75 percentage attendance").

---

## Promotional Text — 170 char limit

Updates without app review — refresh every release. Update the social-proof number from current MAU.

```
Stay above 75% without the mental math. Instant safe-bunk count, CGPA & SGPA calculator, exam reminders — free, offline, no login. Join 600+ students this month.
```

161 chars (MAU ~631 as of late Jul 2026 — bump the number monthly).

---

## Description

```
Know exactly how many classes you can skip — without failing. Bunk Planner does the math so you don't have to.

Enter your numbers. Get your safe-bunk count in seconds. No login, no internet, no spreadsheets.

Trusted by students across India, the US, and the UK to stay above the 75% rule — or any attendance threshold your college enforces.

CALCULATE INSTANTLY

Enter total classes, attended classes, and required percentage. Bunk Planner tells you:

- How many classes you can safely skip
- Your current attendance percentage
- How many consecutive classes you need to attend to recover
- Whether you are Safe or At Risk right now

TRACK YOUR CGPA & GRADES

Attendance is half the battle. Grades are the other half.

- India: 10-point UGC CGPA with semester-wise SGPA
- US: 4.0 GPA with letter grades and credits
- UK: module marks, weighted average, and degree classification
- Target calculator — the grades you need next semester to hit your goal CGPA
- Archive semesters and watch your CGPA build over time

NEVER MISS A DEADLINE

- Add exams, assignments, and submissions per subject
- Automatic reminders 7 days, 3 days, and 1 day before — and on the day
- Exam-week warnings when your attendance is already at risk

PLAN SMARTER

Don't guess. Simulate.

- Scenario simulator — your exact percentage if you skip 1, skip 3, or attend 5
- Next class impact — skip tomorrow vs attend tomorrow, side by side
- Subject-wise semester forecast with holidays and expected absences [Pro]
- Timetable editor that auto-projects your expected class count [Pro]

NEVER GET SURPRISED

- Risk alerts — Stable, Warning, or Critical based on your buffer
- Notifications when your bunk buffer runs dangerously low
- Recovery deadline reminders so you never get detained
- Daily reminders to stay on track

BUILT FOR HOW YOU ACTUALLY STUDY

- Multi-subject tracking — every subject separately
- Attendance trend graph over time [Pro]
- Parent-ready PDF report — attendance + grades in one document [Pro]
- Quick presets — tap 75%, 80%, or 85% to set your minimum
- Share your attendance status with friends
- Works 100% offline — no account, no login, ever
- Core features free forever

BUNK PLANNER PRO — PAY ONCE, KEEP FOREVER

No subscriptions. One purchase, lifetime access.

- Unlimited subjects (free plan: 3 subjects)
- Attendance trend graph
- Subject-wise semester forecast
- Timetable editor with auto-projection
- PDF report with attendance + grades
- No ads, ever

PERFECT FOR

Engineering, medical, law, commerce — if your college takes attendance, this app pays for itself. If you have ever done the mental math before bunking a class, this app was built for you.

No guessing. No math. No panic. Just open, check, and plan.
```

---

## What's New (1.6.6)

```
- Fewer interruptions — no more ad after marking your attendance
- Smoother, faster app experience
- Bug fixes and performance improvements

Staying above 75% just got easier. Update and check your safe bunks now.
```

---

## Notes that move downloads more than copy

1. **Ratings volume** — trigger `SKStoreReviewController` after a "Safe" result on the 3rd+ session.
2. **Screenshots** — first two should show the safe-bunk answer ("Skip 4 classes safely") and the CGPA screen with big caption text.

## Accuracy checklist (before pasting into App Store Connect)

- Free plan: **3 subjects**
- Pro: **one-time lifetime** only (no monthly/annual)
- No "Faculty & admin dashboard" claim
- Update promotional-text social proof from current MAU each release
