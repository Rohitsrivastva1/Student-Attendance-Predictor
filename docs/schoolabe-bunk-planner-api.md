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

## `DELETE /api/v1/bunk-planner/user-data`

Soft flag: `data_deleted = true` (rows kept for tracking).

---

## Tables

- `bunk_planner_users` — profile, meta, `last_active_date`, `is_pro`, soft-delete
- `bunk_planner_subjects` — replace per sync
- `bunk_planner_attendance_entries` — replace per sync when `attendance_entries` sent

Migration: `o7p8q9r0s1t2_add_bunk_planner_attendance_log.py`

```bash
alembic upgrade o7p8q9r0s1t2
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
