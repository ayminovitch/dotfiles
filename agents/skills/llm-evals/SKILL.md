---
name: llm-evals
description: Create or run an evaluation suite for an LLM feature, prompt, RAG pipeline or agent — golden dataset, deterministic checks, LLM-as-judge with a rubric, scores compared against a baseline. Use when the user changes a prompt or model, asks "is this better?", wants to compare providers (OpenAI vs Claude vs Gemini vs Ollama), or needs quality numbers.
---

# LLM evals

Unit tests prove the code works; evals measure how good the model's answers are. Without them,
every prompt or model change is a guess.

## Layout

```
evals/
  data/<feature>.jsonl       # one case per line: {"id", "input", "expected", "tags"}
  test_<feature>.py          # pytest file that runs the cases and scores them
  results/                   # JSON results per run (git-ignored except baseline.json)
```

Keep `evals/` outside `tests/` so `just test` stays fast and free. Add to the justfile:

```
# Run the eval suite (calls real models — costs money unless LLM_MODEL is ollama/*)
eval *args:
    uv run pytest evals -q {{args}}
```

## 1. Dataset

- Start with 20–50 real or realistic cases; grow it every time a bug or bad answer is found.
- Cover: typical cases, edge cases (empty, very long, other language), adversarial cases
  (prompt injection, requests to ignore rules), and cases where the right answer is "I don't know".
- Tag cases (`"tags": ["edge", "injection"]`) to see where quality drops.

## 2. Scoring — cheapest reliable check first

1. **Deterministic**: schema validates, exact/contains match, numbers within tolerance,
   required citations present, forbidden strings absent, length limits.
2. **LLM-as-judge** only for what code can't check (faithfulness, helpfulness, tone):
   - Use `complete_json` with a judge schema `{score: 1-5, reason: str}` and a written rubric
     describing each score level.
   - Judge with a different, stronger model than the one being tested when possible.
   - Give the judge the input, the expected answer and the actual answer; ask for the reason
     before the score.
   - Spot-check ~10 judge verdicts by hand before trusting it.
3. **Cost and speed**: record tokens and latency per case (`litellm.completion_cost` works
   on the response for hosted models).

## 3. Runner

- Parametrize pytest over the JSONL cases; each case asserts its deterministic checks and
  records judge scores.
- Write a summary to `evals/results/<timestamp>-<model>.json`: pass rate, mean judge score per
  tag, p50/p95 latency, total cost.
- Compare against `evals/results/baseline.json` and print the difference. Fail when the pass
  rate or mean score drops by more than an agreed threshold.
- Same suite, different `LLM_MODEL` → provider comparison:
  `LLM_MODEL=ollama/gemma4:12b just eval` vs `LLM_MODEL=groq/<model> just eval` (free tier).

## 4. Use it

- Run before merging any prompt, model, chunking or retrieval change; paste the before/after
  table in the PR.
- When a change wins, update `baseline.json` in the same PR.
- Set `temperature=0` where the provider allows it, and run flaky cases 3× to see the spread.

## Report back

A table: metric · baseline · new · change, then the 3 worst cases with input, expected,
actual and why they failed.
