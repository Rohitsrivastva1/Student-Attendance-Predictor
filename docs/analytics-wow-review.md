# Weekly analytics review (WoW)

Export **Firebase Analytics** (Events + Overview) and **AdMob** (Monetization → Reports) every **Saturday** for the prior Mon–Sun window. Fill this template and compare to the prior week.

---

## 1. Headline metrics

| Metric | This week | Last week | WoW % | Target |
|--------|-----------|-----------|-------|--------|
| WAU (unique users) | | | | — |
| DAU avg | | | | — |
| `day_marked` events | | | | ↑ |
| `day_marked` / WAU | | | | ≥ 2.0 |
| D1 retention (new installs) | | | | ≥ 25% |
| Pro revenue (₹ / $) | | | | **$8+ / ₹700+** |
| Ad revenue | | | | **$2+** |
| **Total revenue** | | | | **$10+ (5× baseline)** |
| Pro purchases succeeded | | | | ≥ 4 |
| Pro checkout success rate | | | | ≥ 40% |
| Banner load rate (`banner_loaded` / `banner_requested`) | | | | ≥ 35% |
| Notification open rate (`notif_opened` / scheduled*) | | | | ≥ 15% |
| Multi-feature WAU (`is_multi_feature_user` = true) | | | | ≥ 20% WAU |
| `skip_planner_viewed` / WAU | | | | ≥ 15% (guardrail) |

\*Scheduled = local notifications delivered (estimate from `notif_scheduled` or device cohort if available).

---

## 2. Key Firebase events (mark as Key events in console)

| Event | Purpose | Key event? |
|-------|---------|------------|
| `day_marked` | Core habit loop | ✅ |
| `notif_opened` | Notification engagement | ✅ |
| `pro_purchase_succeeded` | Revenue | ✅ |
| `skip_planner_viewed` | Hub feature adoption | ✅ |
| `focus_timer_started` | Focus loop entry | ✅ |
| `tools_viewed` | Secondary hub discovery | ✅ |
| `multi_feature_weekly` | 2+ features in ISO week | ✅ |
| `post_mark_focus_prompt_accepted` | Mark → Focus bridge | |
| `focus_timer_completed` | Focus completion | |
| `focus_mark_prompt_used` | Focus → Mark return | |
| `home_promo_shown` / `home_promo_tapped` | Home promo cards | |
| `widget_prompt_shown` | Widget install funnel | |
| `at_risk_share_prompt_tapped` | Viral loop | |
| `soft_paywall_shown` | Monetization entry | |

**User properties to watch:** `multi_feature_count_week`, `is_multi_feature_user`, `attendance_status`, `days_since_install`.

---

## 3. Funnels (Firebase Explorations)

### 3.1 Notification → mark

```
notif_scheduled (or evening_mark / risk types)
  → notif_opened
  → deep_link_opened (route: mark_today | skip_planner)
  → day_marked (within 30 min of open)
```

**Healthy:** open ≥ 12%, deep-link → mark ≥ 35% of opens.

### 3.2 Soft paywall → Pro

```
soft_paywall_shown (reason: at_risk_week_3 | subject_cap | …)
  → paywall_viewed
  → pro_purchase_started
  → pro_purchase_succeeded | pro_purchase_failed
```

Segment **failed** by `error_code` / reason. Target: started → succeeded ≥ 40%.

### 3.3 Banner ads

```
banner_requested (placement: home | …)
  → banner_loaded
  → banner_shown
  → banner_click (optional)
```

Segment by `placement`. Do **not** enable mediation until home load rate ≥ 40%.

### 3.4 Focus completion loop

```
day_marked
  → post_mark_focus_prompt_shown
  → post_mark_focus_prompt_accepted
  → focus_timer_started
  → focus_timer_completed
  → focus_mark_prompt_used (optional return mark)
  → day_marked (next calendar day)
```

### 3.5 Multi-feature hub

```
Any of: day_marked | skip_planner_viewed | focus_timer_started | forecast_viewed | widget_prompt_shown
  → multi_feature_weekly (feature_count ≥ 2)
```

---

## 4. AdMob ↔ Firebase (unified ARPDAU)

Firebase does not ingest AdMob revenue automatically. Link manually each week:

1. **AdMob** → Reports → Estimated earnings (same date range as Firebase).
2. **Firebase** → Analytics → Events → note `ad_impression` / custom ad events if logged.
3. **Spreadsheet columns:** Date | DAU | AdMob $ | Pro $ | Total $ | ARPDAU (Total / DAU).

Optional upgrade path:

- Enable [AdMob–Firebase linking](https://support.google.com/admob/answer/6383165) in AdMob → Settings → Linked services.
- After link, Ad impression revenue appears in Firebase under **Monetization** (may lag 24–48h).

**Unified ARPDAU** = (AdMob earnings + Pro net) / average DAU.

---

## 5. Five× revenue targets (1-week sprint)

Baseline week (Aug 15–21): ~**$2.30** total (~$0.28 ads + ~$2 Pro).

| Lever | Current | 5× target | Action if red |
|-------|---------|-----------|---------------|
| Pro sales | 2/wk | **4+ / wk** | Paywall retry, at-risk soft paywall, forecast preview |
| Pro conversion | ~17% | **≥ 40%** | Fix StoreKit failures, restore legacy IAP |
| Ad impressions | low | **2× impressions** | Fix banner load (consent, retries) |
| `day_marked` / WAU | ~1.5 | **≥ 2.0** | Evening nudge, notif deep links, Mark Today highlight |
| Skip planner WAU | ~0% | **≥ 15%** | Home promo, at-risk card, notif routes |
| Multi-feature WAU | — | **≥ 20%** | Post-mark Focus, promo cards, widget prompt |

**Ship gate:** Total revenue **≥ $10** OR Pro **≥ 4 sales** at ≥ ₹69 avg.

---

## 6. Cohort compare (post-ship)

After merging `feature/retention-monetization-sprint`:

| Cohort | Version | WAU | day_marked/WAU | skip_planner/WAU | Pro $ |
|--------|---------|-----|-----------------|------------------|-------|
| Control | 1.7.1 | | | | |
| Treatment | 1.7.x+sprint | | | | |

Firebase → Audiences → User property `app_version` or first_open week.

---

## 7. Weekly notes (free text)

**Wins:**

**Regressions:**

**Ship / no-ship for next week:**

**Guardrail:** Do **not** add new tabs until `skip_planner_viewed` ≥ **15% WAU** for **2 consecutive weeks**.

---

## 8. Export checklist

- [ ] Firebase Events CSV (Mon–Sun)
- [ ] Firebase Overview / retention
- [ ] AdMob earnings report
- [ ] App Store Connect units + proceeds (if available)
- [ ] This template filled + saved as `docs/reviews/YYYY-MM-DD-wow.md` (optional)
