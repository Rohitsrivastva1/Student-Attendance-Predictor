# Schoolabe — Syllabus structure API

Used by Bunk Planner **Tools → Syllabus → Make better with AI**.

Photos are OCR’d **on device**. Only student-confirmed **text** is sent here. Groq is called server-side.

---

## `POST /api/v1/bunk-planner/syllabus/structure`

**Full path:** `https://api.schoolabe.com/api/v1/bunk-planner/syllabus/structure`

### Env (Schoolabe host)

| Variable | Required | Notes |
|----------|----------|--------|
| `GROQ_SYLLABUS_API_KEY` | Yes | Dedicated Groq key for this feature only |
| `GROQ_SYLLABUS_MODEL` | No | Default `llama-3.3-70b-versatile` |

If neither `GROQ_SYLLABUS_API_KEY` nor fallback `GROQ_API_KEY` is set, return **503** with `{ "error": "ai_not_configured", "units": [] }`.

### Headers

| Header | Value |
|--------|--------|
| `Content-Type` | `application/json` |
| `User-Agent` | `BunkPlanner/iOS` |

### Request

```json
{
  "client_user_id": "550e8400-e29b-41d4-a716-446655440000",
  "raw_text": "Unit 1: Processes\n- PCB\n- Scheduling\nUnit 2: Memory\n- Paging",
  "market": "india",
  "subject_name": "Operating Systems"
}
```

- Cap `raw_text` at ~12 000 characters.
- Rate limit ~5 successful structures / `client_user_id` / day (429 when exceeded).

### Success response `200`

```json
{
  "units": [
    {
      "title": "Processes",
      "topics": ["PCB", "Scheduling"]
    },
    {
      "title": "Memory",
      "topics": ["Paging"]
    }
  ]
}
```

### Error shapes

| Status | Body |
|--------|------|
| 503 | `{ "error": "ai_not_configured", "units": [] }` |
| 429 | `{ "error": "rate_limited", "units": [] }` |
| 400 | `{ "error": "empty_text", "units": [] }` |

### Groq prompt contract

Ask the model for **JSON only**: `{ "units": [ { "title": string, "topics": string[] } ] }`.  
Normalize headings into units; bullet lines into topics. No markdown fences.

### Sample (Python / FastAPI sketch)

```python
import os
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter()
GROQ_KEY = os.environ.get("GROQ_SYLLABUS_API_KEY")
GROQ_MODEL = os.environ.get("GROQ_SYLLABUS_MODEL", "llama-3.3-70b-versatile")

class Body(BaseModel):
    client_user_id: str
    raw_text: str
    market: str | None = None
    subject_name: str | None = None

@router.post("/api/v1/bunk-planner/syllabus/structure")
async def structure(body: Body):
    if not GROQ_KEY:
        raise HTTPException(503, detail={"error": "ai_not_configured", "units": []})
    text = (body.raw_text or "").strip()
    if not text:
        raise HTTPException(400, detail={"error": "empty_text", "units": []})
    # call Groq chat.completions with GROQ_KEY / GROQ_MODEL …
    return {"units": [...]}
```

Set on the host:

```bash
export GROQ_SYLLABUS_API_KEY=gsk_...
# optional
export GROQ_SYLLABUS_MODEL=llama-3.3-70b-versatile
```
