# Schoolabe Bunk Planner — sync API

Single endpoint for the iOS app to upsert an anonymous user profile and their subject list.

**Does not receive:** attendance marks, bunk counts, CGPA data, or device contacts.

---

## `POST /api/v1/bunk-planner/sync`

**Base URL (production):** `https://api.schoolabe.com`  
**Full path:** `https://api.schoolabe.com/api/v1/bunk-planner/sync`  
**Override in app:** Info.plist key `SchoolabeAPIBaseURL` (full URL to this path).

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
  "meta": {
    "app_version": "1.7.2",
    "market": "india",
    "platform": "ios"
  }
}
```

| Field | Required | Notes |
|-------|----------|--------|
| `client_user_id` | Yes | Stable anonymous UUID from app (`analytics.userId`) |
| `profile` | No | Omit or `null` if user skipped onboarding profile |
| `subjects` | No | Full list of subjects user has created (replace set on server) |
| `meta` | Yes | App version + market + platform |

### Response

**200 / 201** — upsert accepted

```json
{
  "ok": true,
  "client_user_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**4xx / 5xx** — app logs `schoolabe_sync_failed` and retries on next subject change.

---

## `DELETE /api/v1/bunk-planner/user-data`

Marks the user as deleted for tracking — **does not remove rows** from the database.

### Request body

```json
{
  "client_user_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Response

**200**

```json
{
  "ok": true,
  "data_deleted": true,
  "client_user_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

Server sets `data_deleted = true` and `data_deleted_at` on `bunk_planner_users`. Profile and subject rows are kept for analytics. A new sync from the app clears the flag.

### App trigger

Settings → About you → **Remove my data** — calls API, then clears local profile on device.

---

## Server implementation notes

1. **Upsert** on `client_user_id` (primary key).
2. **Replace** `subjects` array on each sync (idempotent).
3. **PII:** name, age, institution — treat per your privacy policy; allow deletion on request.
4. **Rate limit:** ~1 req/min per `client_user_id` is enough (app debounces 800ms).
5. **CORS:** not needed (native app).

---

## App trigger points

| Event | Sync |
|-------|------|
| Onboarding profile Continue (name, class, institution required) | Yes |
| Subject added / deleted | Yes (debounced) |
| Settings → About you → Save | Yes |

---

## Privacy

Update App Store privacy label and in-app Privacy Policy before enabling in production — profile fields leave the device for the first time.
