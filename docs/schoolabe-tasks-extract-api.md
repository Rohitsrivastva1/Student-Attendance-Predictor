# Schoolabe — Tasks extract API

Used by Bunk Planner **Home camera / Tools → Tasks**.

Photos are OCR’d **on device**. Only extracted **text** is sent here. Groq is called server-side. The iOS app falls back to a local heuristic if this endpoint is missing.

---

## `POST /api/v1/bunk-planner/tasks/extract`

**Full path:** `https://api.schoolabe.com/api/v1/bunk-planner/tasks/extract`

Same Groq env as syllabus (`GROQ_SYLLABUS_API_KEY`).

### Request

```json
{
  "client_user_id": "550e8400-e29b-41d4-a716-446655440000",
  "raw_text": "OS Assignment 3 tomorrow\nDSA quiz 28 Sep",
  "market": "india",
  "subject_names": ["Operating Systems", "DSA"],
  "today": "2026-09-24"
}
```

### Success `200`

```json
{
  "items": [
    {
      "title": "Assignment 3",
      "kind": "assignment",
      "subject_name": "Operating Systems",
      "due_date": "2026-09-25",
      "topics": []
    },
    {
      "title": "Quiz",
      "kind": "quiz",
      "subject_name": "DSA",
      "due_date": "2026-09-28",
      "topics": []
    }
  ]
}
```

`kind`: `homework` | `assignment` | `quiz` | `exam` | `other`  
`due_date`: `YYYY-MM-DD` or omit.  
For a datesheet / syllabus photo, return one `exam` per subject with `topics`.
