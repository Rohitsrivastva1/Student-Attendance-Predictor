#!/usr/bin/env python3
"""Rebuild Student Attendance Predictor/Resources/institutions.json

Sources today:
  - Hipo university-domains-list (world universities)
  - Curated India aliases / popular campuses

To expand to full AISHE (~40k Indian colleges), drop a JSON array of
{"n": name, "c": "India", "s": optional_state} into --extra and re-run.
"""

from __future__ import annotations

import argparse
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Student Attendance Predictor" / "Resources" / "institutions.json"
HIPO = "https://raw.githubusercontent.com/Hipo/university-domains-list/master/world_universities_and_domains.json"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--extra", type=Path, help="Optional JSON list to merge")
    parser.add_argument("--hipo", type=Path, help="Local Hipo JSON instead of download")
    args = parser.parse_args()

    if args.hipo:
        world = json.loads(args.hipo.read_text())
    else:
        with urllib.request.urlopen(HIPO, timeout=120) as r:
            world = json.loads(r.read())

    records: list[dict] = []
    seen: set[tuple[str, str]] = set()

    def add(name: str, country: str, state: str | None = None, kind: str | None = None) -> None:
        name = (name or "").strip()
        country = (country or "").strip()
        if len(name) < 3:
            return
        key = (name.lower(), country.lower())
        if key in seen:
            return
        seen.add(key)
        rec: dict = {"n": name, "c": country}
        if state:
            rec["s"] = state
        if kind:
            rec["k"] = kind
        records.append(rec)

    for u in world:
        add(u.get("name") or "", u.get("country") or "", u.get("state-province"))

    if args.extra and args.extra.exists():
        extra = json.loads(args.extra.read_text())
        for item in extra:
            if isinstance(item, str):
                add(item, "India", kind="c")
            else:
                add(item.get("n") or item.get("name") or "", item.get("c") or "India", item.get("s"), item.get("k") or "c")

    # Keep existing curated India names already in OUT if present
    if OUT.exists():
        for item in json.loads(OUT.read_text()):
            if item.get("c") == "India":
                add(item.get("n") or "", "India", item.get("s"), item.get("k") or "c")

    records.sort(key=lambda r: (0 if r.get("c") == "India" else 1, r["n"].lower()))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(records, separators=(",", ":"), ensure_ascii=False), encoding="utf-8")
    india = sum(1 for r in records if r.get("c") == "India")
    print(f"Wrote {OUT} — {len(records)} total, {india} India, {OUT.stat().st_size/1024:.1f} KB")


if __name__ == "__main__":
    main()
