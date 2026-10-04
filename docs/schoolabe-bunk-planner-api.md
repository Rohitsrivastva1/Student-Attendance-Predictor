# Schoolabe Bunk Planner — sync API

Single endpoint for the iOS app to upsert an anonymous user profile, subjects, **full attendance log**, and **last active date**.

---

## `POST /api/v1/bunk-planner/sync`

**Full path:** `https://api.schoolabe.com/api/v1/bunk-planner/sync`

### Headers

| Header | Value |
|--------|--------|
| `Content-Type` | `application/json` |
| `User-Agent` | `BunkPlanner/iOS` |

### Request body

```json
{
  "client_user_id": "550e8400-e29b-41d4-a716-446655440000",
  "profile": {
    "name": "Rohit",
    "age": 20,
    "class_or_degree": "B.Tech 2nd year",
    "institution_name": "ABC Engineering College"
  },
  "subjects": [
    {
      "id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
      "name": "Mathematics",
      "required_percentage": 75.0,
      "created_at": "2026-08-22T10:30:00Z"
    }
  ],
  "attendance_entries": [
    {
      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "subject_id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
      "date": "2026-08-25",
      "scheduled_classes": 2,
      "attended_classes": 1,
      "is_holiday": false,
      "updated_at": "2026-08-25T08:15:00Z"
    }
  ],
  "last_active_date": "2026-08-25",
  "meta": {
    "app_version": "1.7.2",
    "market": "india",
    "platform": "ios",
    "is_pro": false
  }
}
```

| Field | Required | Notes |
|-------|----------|--------|
| `client_user_id` | Yes | Anonymous UUID |
| `profile` | No | Omit if empty |
| `subjects` | No | Full replace set |
| `attendance_entries` | No | If present (incl. `[]`), **replace** server attendance for this user |
| `last_active_date` | No | Local calendar day `YYYY-MM-DD` — user opened the app that day (not live presence) |
| `meta` | Yes | Includes `is_pro` |

### Response

```json
{ "ok": true, "client_user_id": "550e8400-e29b-41d4-a716-446655440000" }
```

Rate limit: ~3 req/min per `client_user_id`.

---

## Invites

Same anonymous `client_user_id`. Reward is **7 days ad-free**, not Pro.

### `POST /api/v1/bunk-planner/invite/ensure`

```json
{ "client_user_id": "550e8400-e29b-41d4-a716-446655440000" }
```

```json
{
  "ok": true,
  "code": "ABC123",
  "url": "https://schoolabe.com/i/ABC123",
  "redeem_count": 0
}
```

### `POST /api/v1/bunk-planner/invite/redeem`

```json
{
  "client_user_id": "550e8400-e29b-41d4-a716-446655440000",
  "code": "ABC123"
}
```

Success: `{ "ok": true, "grant_days": 7, "code": "ABC123", "referrer_client_user_id": "…", "invitee_client_user_id": "…" }`

Each redeem writes `bunk_planner_redemptions` (who invited whom) plus analytics events `invite_redeemed` / `invite_friend_joined`.

`detail` tokens: `not-found` (404), `already_redeemed` (409), `self_redeem` (400), `cap_reached` (429).

### `POST /api/v1/bunk-planner/invite/claim`

Referrer applies pending days after friends redeem.

```json
{ "client_user_id": "uuid" }
```

```json
{ "ok": true, "granted_days": 7, "redeem_count": 1, "code": "ABC123" }
```

---

## `DELETE /api/v1/bunk-planner/user-data`

Soft flag: `data_deleted = true` (rows kept for tracking).

---

## Tables

- `bunk_planner_users` — profile, meta, `last_active_date`, `is_pro`, invite credits, soft-delete
- `bunk_planner_subjects` — replace per sync
- `bunk_planner_attendance_entries` — replace per sync when `attendance_entries` sent
- `bunk_planner_invites` / `bunk_planner_redemptions` — referral loop

Migration: `r0s1t2u3v4w5_add_bunk_planner_invites.py`

```bash
alembic upgrade r0s1t2u3v4w5
```

---

## App triggers

| Event | Sync |
|-------|------|
| App open (once per local day) | `last_active_date` + full payload |
| Mark / clear day | Attendance replace |
| Subject add/delete | Subjects + attendance |
| Profile save | Profile |

---

## Privacy

Update App Store privacy labels: attendance history and product interaction leave the device. In-app Privacy Policy must match.

---

## Related

- Syllabus AI structure (Groq): [`schoolabe-syllabus-structure-api.md`](schoolabe-syllabus-structure-api.md) — env `GROQ_SYLLABUS_API_KEY`
