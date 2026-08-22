#!/usr/bin/env python3
"""Generate the embedded Mythic+ percentile table from Raider.IO cutoffs."""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


RIO_BASE = "https://raider.io/api/v1"
EXPANSION_ID = int(os.environ.get("KALDO_MM_EXPANSION_ID", "11"))
SEASON_OVERRIDE = os.environ.get("KALDO_MM_SEASON")
REGIONS = tuple(os.environ.get("KALDO_MM_REGIONS", "us,eu,kr,tw,cn").split(","))
OUTPUT_PATH = Path(os.environ.get("KALDO_MM_OUTPUT", "data/mm_percentiles.lua"))
REQUEST_DELAY = float(os.environ.get("KALDO_MM_REQUEST_DELAY", "0.5"))


def request_json(path: str, params: dict[str, str | int] | None = None) -> dict:
    query = urllib.parse.urlencode(params or {})
    url = f"{RIO_BASE}{path}"
    if query:
        url = f"{url}?{query}"

    last_error: Exception | None = None
    for delay in (0, 1, 2, 4, 8):
        if delay:
            time.sleep(delay)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "KaldoTV-Tweaks/percentile-generator"})
            with urllib.request.urlopen(req, timeout=30) as response:
                return json.loads(response.read().decode("utf-8"))
        except Exception as exc:  # noqa: BLE001 - keep retry handling compact for CI.
            last_error = exc
    raise RuntimeError(f"failed to fetch {url}: {last_error}")


def active_season() -> dict:
    if SEASON_OVERRIDE:
        return {"slug": SEASON_OVERRIDE, "name": SEASON_OVERRIDE}

    data = request_json("/mythic-plus/static-data", {"expansion_id": EXPANSION_ID})
    now = datetime.now(timezone.utc)
    candidates = []
    for season in data.get("seasons", []):
        if not season.get("is_main_season"):
            continue
        starts = season.get("starts", {})
        ends = season.get("ends", {})
        start_text = starts.get("eu") or starts.get("us")
        end_text = ends.get("eu") or ends.get("us")
        if not start_text or not end_text:
            continue
        start = datetime.fromisoformat(start_text.replace("Z", "+00:00"))
        end = datetime.fromisoformat(end_text.replace("Z", "+00:00"))
        if start <= now < end:
            candidates.append((start, season))

    if not candidates:
        raise RuntimeError("could not find the active main Mythic+ season")

    return sorted(candidates, key=lambda item: item[0], reverse=True)[0][1]


def add_point(points: list[dict], score: float, quantile: float, total: int) -> None:
    if score <= 0 or quantile <= 0 or total <= 0:
        return
    top_percent = max(0.0, min(100.0, (1.0 - quantile) * 100.0))
    points.append({"score": float(score), "topPercent": top_percent, "total": int(total)})


def region_points(season_slug: str, region: str) -> tuple[list[dict], int, str | None]:
    time.sleep(REQUEST_DELAY)
    data = request_json("/mythic-plus/season-cutoffs", {"season": season_slug, "region": region})
    cutoffs = data.get("cutoffs", {})
    points: list[dict] = []
    total = 0
    updated = cutoffs.get("updatedAt")

    for key, value in cutoffs.items():
        if not isinstance(value, dict):
            continue
        entry = value.get("all")
        if not isinstance(entry, dict):
            nested = value.get("cutoffs")
            entry = nested.get("all") if isinstance(nested, dict) else None
        if not isinstance(entry, dict):
            continue

        score = entry.get("quantileMinValue")
        quantile = entry.get("quantile")
        population = entry.get("totalPopulationCount")
        if score is None or quantile is None or population is None:
            continue
        add_point(points, float(score), float(quantile), int(population))
        total = max(total, int(population))

    dedup: dict[int, dict] = {}
    for point in points:
        rounded_score = int(round(point["score"]))
        previous = dedup.get(rounded_score)
        if previous is None or point["topPercent"] < previous["topPercent"]:
            dedup[rounded_score] = {"score": rounded_score, "topPercent": point["topPercent"], "total": point["total"]}

    out = sorted(dedup.values(), key=lambda point: point["score"], reverse=True)
    if out:
        out.append({"score": 0, "topPercent": 100.0, "total": total})
    return out, total, updated


def interpolate(points: list[dict], score: int) -> float | None:
    if not points:
        return None
    if score >= points[0]["score"]:
        return points[0]["topPercent"]
    for i in range(len(points) - 1):
        high = points[i]
        low = points[i + 1]
        if high["score"] >= score >= low["score"]:
            if high["score"] == low["score"]:
                return high["topPercent"]
            ratio = (score - low["score"]) / (high["score"] - low["score"])
            return low["topPercent"] + (high["topPercent"] - low["topPercent"]) * ratio
    return points[-1]["topPercent"]


def world_points(regions: dict[str, dict]) -> tuple[list[dict], int]:
    scores = sorted({point["score"] for data in regions.values() for point in data["points"]}, reverse=True)
    total = sum(data["total"] for data in regions.values())
    out = []
    for score in scores:
        weighted = 0.0
        weight_total = 0
        for data in regions.values():
            pct = interpolate(data["points"], score)
            if pct is None:
                continue
            weighted += pct * data["total"]
            weight_total += data["total"]
        if weight_total > 0:
            out.append({"score": score, "topPercent": weighted / weight_total, "total": total})
    return out, total


def lua_string(value: str | None) -> str:
    if value is None:
        return "nil"
    return json.dumps(value, ensure_ascii=True)


def write_lua(season: dict, regions: dict[str, dict], updated: str | None) -> None:
    lines = [
        "-- Generated by tools/update_mm_percentiles.py. Do not edit by hand.",
        "local ADDON_NAME, NS = ...",
        "",
        "NS.MMPercentiles = {",
        '  source = "Raider.IO",',
        '  sourceUrl = "https://raider.io",',
        f"  season = {lua_string(season.get('slug'))},",
        f"  seasonName = {lua_string(season.get('name'))},",
        f"  updated = {lua_string(updated)},",
        "  regions = {",
    ]
    for region, data in sorted(regions.items()):
        lines.append(f"    {region} = {{")
        lines.append(f"      total = {int(data['total'])},")
        lines.append("      points = {")
        for point in data["points"]:
            lines.append(
                "        { score = %d, topPercent = %.3f },"
                % (int(point["score"]), float(point["topPercent"]))
            )
        lines.append("      },")
        lines.append("    },")
    lines.extend(["  },", "}", ""])

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def main() -> int:
    season = active_season()
    season_slug = season["slug"]
    regions: dict[str, dict] = {}
    updated_values: list[str] = []

    for region in REGIONS:
        region = region.strip().lower()
        if not region:
            continue
        points, total, updated = region_points(season_slug, region)
        if not points:
            print(f"warning: no percentile points for {region}", file=sys.stderr)
            continue
        regions[region] = {"points": points, "total": total}
        if updated:
            updated_values.append(updated)

    if not regions:
        raise RuntimeError("no Raider.IO percentile data fetched")

    world, world_total = world_points(regions)
    regions["world"] = {"points": world, "total": world_total}
    write_lua(season, regions, max(updated_values) if updated_values else datetime.now(timezone.utc).isoformat())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
