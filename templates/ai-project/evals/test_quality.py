"""Quality evals: real calls to the model in LLM_MODEL. Run with `just eval` (not in `just test`).

Add a line to cases.jsonl for every real question your app must handle well, and for every bad
answer you find. Each case can check:
    must_contain / must_not_contain   exact text checks (cheap, deterministic)
    rubric (+ min_score, default 4)   an LLM judge scores the answer 1-5 against your rubric
"""

import json
import os
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from pydantic import BaseModel, Field

from __PKG__.llm import complete, complete_json

CASES = [
    json.loads(line)
    for line in (Path(__file__).parent / "cases.jsonl").read_text().splitlines()
    if line.strip()
]
# Judge with a stronger model than the one under test when you can, e.g. groq/<model> (free tier)
JUDGE_MODEL = os.environ.get("EVAL_JUDGE_MODEL") or None


class Verdict(BaseModel):
    reason: str
    score: int = Field(ge=1, le=5)


def judge(question: str, answer: str, rubric: str) -> Verdict:
    prompt = (
        "Grade the ANSWER to the QUESTION using the RUBRIC. Explain your reason first, then give "
        "a score from 1 (worst) to 5 (best).\n\n"
        f"<question>{question}</question>\n<answer>{answer}</answer>\n<rubric>{rubric}</rubric>"
    )
    return complete_json(prompt, Verdict, model=JUDGE_MODEL)


@pytest.mark.parametrize("case", CASES, ids=[c["id"] for c in CASES])
def test_case(case: dict[str, Any], record: Callable[[dict[str, Any]], None]) -> None:
    started = time.perf_counter()
    answer = complete(case["prompt"], system=case.get("system"))
    seconds = time.perf_counter() - started

    problems = [
        f"missing {s!r}" for s in case.get("must_contain", []) if s.lower() not in answer.lower()
    ]
    problems += [
        f"contains {s!r}" for s in case.get("must_not_contain", []) if s.lower() in answer.lower()
    ]
    score = None
    if "rubric" in case:
        verdict = judge(case["prompt"], answer, case["rubric"])
        score = verdict.score
        if score < case.get("min_score", 4):
            problems.append(f"judge score {score}: {verdict.reason}")

    record(
        {
            "id": case["id"],
            "tags": case.get("tags", []),
            "passed": not problems,
            "score": score,
            "seconds": round(seconds, 2),
            "problems": problems,
            "answer": answer[:2000],
        }
    )
    assert not problems, f"{problems}\nanswer: {answer[:500]!r}"
