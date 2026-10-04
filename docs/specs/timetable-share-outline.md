# Outline (PARKED): Timetable share (QR / link)

**Status:** Parked outline only — no handoff, no ROADMAP flip.  
**Source:** Researcher brief (SilverBook / BunkMate share; RollCall users request link share).  
**Owner:** BunkPlanner BA  
**Date:** 2026-09-12  
**Sequence:** After university presets + class event types (Manager default).  
**Constraints:** P5.14-safe; campus growth loop; no account required to *receive* if possible.

---

## Job to be done

“My classmate already typed the timetable — I shouldn’t re-enter every period.”

## Proposed v1 scope

1. **Export:** Pro or free? Recommendation: **free export** (growth), optional Pro polish later. Manager to decide.
2. **Payload:** subjects (name + weekly period hours) only — **no** attendance %, marks, or personal name by default.
3. **Formats:** (a) in-app QR showing payload; (b) share sheet link (Universal Link / Hosting) that opens app or landing → “Add to Bunk Planner”.
4. **Import:** review screen before merge; resolve name collisions (skip / replace / keep both).
5. **Privacy:** explicit “sharing schedule only” copy; no proxy/cheat framing.
6. **Backend:** prefer existing Firebase Hosting / Functions patterns used by referral (4.7); short-lived tokens.

## Non-goals v1

- Live collaborative editing.
- College ERP sync.
- Sharing attendance logs or Pro entitlements.

## Stories (sketch — expand when unparked)

- US-TS-1 Share my timetable (QR + system share sheet)  
- US-TS-2 Import from QR / link with confirm merge  
- US-TS-3 Expired / invalid link empty states  
- US-TS-4 Analytics: `timetable_share_created`, `timetable_import_completed` (no PII)

## Open questions for Manager / Rohit

1. Free vs Pro on export?  
2. Must receiver already have the app installed?  
3. Subject limit: importing past free cap → soft paywall after import preview?

## Dependencies

- Stable `WeeklySchedule` period model (already shipped).  
- Referral/Hosting deploy path useful but not strictly blocking for QR-only offline share.

---

*Parked outline — expand to full AC when prioritized.*
