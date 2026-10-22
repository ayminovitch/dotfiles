"""Collects eval results and writes a summary per run (compared against results/baseline.json)."""

import json
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest

from __PKG__.config import get_settings

RESULTS_DIR = Path(__file__).parent / "results"
_results: list[dict[str, Any]] = []


@pytest.fixture
def record() -> Callable[[dict[str, Any]], None]:
    """Call record({...}) once per case with its outcome."""
    return _results.append


def _summary() -> dict[str, Any]:
    scores = [r["score"] for r in _results if r.get("score") is not None]
    latencies = sorted(r["seconds"] for r in _results)
    return {
        "model": get_settings().llm_model,
        "cases": len(_results),
        "pass_rate": round(sum(r["passed"] for r in _results) / len(_results), 3),
        "mean_judge_score": round(sum(scores) / len(scores), 2) if scores else None,
        "p50_seconds": round(latencies[len(latencies) // 2], 2),
        "max_seconds": round(latencies[-1], 2),
    }


def pytest_sessionfinish(session: pytest.Session, exitstatus: int) -> None:
    if not _results:
        return
    summary = _summary()
    RESULTS_DIR.mkdir(exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    name = summary["model"].replace("/", "_").replace(":", "-")
    out = RESULTS_DIR / f"{stamp}-{name}.json"
    out.write_text(json.dumps({"summary": summary, "cases": _results}, indent=2))

    lines = [f"\nEvals: {summary}", f"Saved: evals/results/{out.name}"]
    baseline = "evals/results/baseline.json"
    if (RESULTS_DIR / "baseline.json").exists():
        base = json.loads((RESULTS_DIR / "baseline.json").read_text())["summary"]
        for key in ("pass_rate", "mean_judge_score", "p50_seconds"):
            if base.get(key) is not None and summary.get(key) is not None:
                lines.append(f"  {key}: {base[key]} → {summary[key]}")
    else:
        lines.append(
            f"No baseline yet. Happy with this run? cp evals/results/{out.name} {baseline}"
        )
    print("\n".join(lines))
