# More / Tools — align with day-to-day study
Designer note (2026-09-20). Source: `ToolsView.swift`, ROADMAP P5, analytics wow review.

## What ships today
**More** tab → hub titled “More tools” with subtitle “Focus, grades, and extras. Skip planner stays on Plan.”

| Section | Rows |
|---------|------|
| **Study** | Focus Timer · CGPA/GPA/Module Marks · Exam Deadlines |
| **Reports** | Export Reports (Pro lock) |

Skip Planner / Forecast live on **Plan**, not More. Correct — don’t move them.

## Day-to-day study jobs (India-first)
1. **Morning / before class** — Can I bunk / mark today? → **Today + Plan** (not More)
2. **Between classes / evening** — Focus a block on the subject I just marked → **Focus**
3. **Exam season** — What’s due + am I short on that paper? → **Deadlines × attendance**
4. **Semester checkpoints** — Where’s my CGPA / target? → **Grades**
5. **Parents / proof** — Export → **Reports** (occasional)

So More should feel like **“study extras that support the attendance loop”**, not a second product.

## Problems
1. **Directory, not a day.** Flat list; no “what should I do next for study today?”
2. **Weak subject glue.** Focus can tag subjects, but More doesn’t surface *which* subject is at risk / next exam.
3. **CGPA competes with bunk JTBD.** Fine as secondary; shouldn’t look equal to Focus during a normal weekday.
4. **Deadlines feel separate from %.** Student mental model: “OS exam Friday + I’m at 60%.”
5. **P5.14.** No new tabs. Improve More *in place*; keep Skip on Plan.

## Design direction (no new tabs)

### A. Reframe header (S)
- Title: **Study** (or keep “More” in tab, change hub to **Study tools**)
- Subtitle: **Focus after you mark. Grades and exams when you need them.**
- Keep one line: Skip Planner stays on Plan.

### B. “Today’s study” hero card (S–M) — top of More
One contextual card, not a new tool:

| State | Hero | CTA |
|-------|------|-----|
| Focus running | Session live on Lock Screen | Open Focus |
| Just marked / post-mark | Focus 25m on **[last marked subject]** | Start Focus |
| Deadline ≤7d + subject at risk | **[Exam]** · subject at **X%** — attend before you bunk | Open deadline / Today |
| Deadline ≤7d, safe | Exam in N days · buffer OK | Open deadlines |
| Idle weekday | Start a focus block | Focus Timer |
| Idle + empty grades | Optional soft: Add CGPA courses | Grades |

Uses existing stores (FocusTimer, DeadlineStore, subjects). No new tab.

### C. Reorder / weight Study rows (S)
Weekday default order:
1. **Focus Timer** (daily habit) — keep live subtitle (minutes / running)
2. **Exam Deadlines** — bump when `upcoming > 0` or ≤7d exists (swap above CGPA)
3. **CGPA / GPA** — semester tool; demote visually when no courses OR not exam season

Optional chip on deadline row: **“2 this week”** / **“OS Fri”** (already partly in subtitle).

### D. Attendance × deadline collision (M) — inside Deadlines / hero
On deadline rows (or hero): if linked subject is Warning/Critical, show risk chip with BrandColor SoT (`#FFB86B` / `#E11D48`) + “Attend N more” from recovery math. Deep link already exists from Home warnings — mirror that honesty in More.

### E. Focus = default “study” verb (S)
- Empty Focus subtitle stays Pomodoro line
- Prefer **subject-prefilled** entry from last Mark Today (P5.2 already) — surface that in the hub subtitle: “Ready for Operating Systems”
- Don’t add white-noise / new Focus chrome until P5.14 clears

### F. Reports stays last (S)
Parents / mid-sem proof only. Keep Pro lock. Don’t lead More with Export.

### G. Explicitly do **not** add yet
Homework hub, notes, timetable share, new tabs, “student OS” laundry list — wait for multi-feature WAU + P5.14. ROADMAP: connect to attendance loop first.

## Success (design)
- More opens → user knows **next study action in <3s**
- Focus / deadlines usage rises without stealing Mark Today / Skip Planner
- CGPA stays available but doesn’t become the hero of a normal weekday
- Still **5 tabs**; Skip stays on Plan

## Hand to
- **BA:** AC for contextual hero + deadline×risk chip
- **Coder:** S/M sizing after AC
- **Marketer:** More is not ASO lead; keep “also included”
