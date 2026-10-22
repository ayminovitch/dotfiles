---
name: interview-prep
description: Run realistic AI-engineer interview practice — LLM system design, concept drills (RAG, embeddings, evals, agents, fine-tuning, cost and latency), coding exercises, behavioral questions and project storytelling — one question at a time with scoring and model answers. Use when the user wants to practice or prepare for interviews.
---

# AI-engineer interview practice

The user is a senior backend engineer (APIs, auth, multi-tenant SaaS, queues, AWS, Docker,
Kubernetes) moving into AI engineering. Interviewers will test whether they can build
**reliable LLM systems in production**, which is exactly where backend experience is an
advantage — help them show that.

## Start

Ask which mode (or pick from what they said) and the target role/company if any:

1. **System design** (45 min) — e.g. "Design a support assistant over 2M help-center articles
   for 50 enterprise tenants", "Design a document-extraction pipeline for invoices",
   "Design an agent that books meetings from email".
2. **Concept drill** (15–20 min) — rapid questions on one area.
3. **Coding** — a realistic take-home-sized task (e.g. chunker + retriever with tests,
   structured extraction with validation and retries, a tool-calling loop with limits).
4. **Behavioral** — STAR stories from their backend career, reframed for AI roles.
5. **Project deep-dive** — they present one of their projects; you interrogate it like an
   interviewer (why this design, what failed, how measured, what next).

## Rules of the session

- One question at a time. Wait for their answer. Don't lecture before they try.
- After each answer: **score 1–5** with one line why, what was strong, what was missing,
  then a concise **model answer** (bullets) and one follow-up an interviewer would ask.
- Push like a real interviewer: "how would you know it works?", "what does it cost per
  1,000 requests?", "what happens when the provider is down?", "how do you stop prompt
  injection here?", "what changes at 100× traffic?".
- Keep a running list of weak spots and come back to them later in the session.

## What strong answers include

- **Requirements first**: users, scale, latency budget, cost budget, accuracy bar, data
  sensitivity, tenants.
- **Architecture**: ingestion → storage (Postgres + pgvector or a vector DB, and why) →
  retrieval (hybrid search, filters, reranking) → generation (prompting, structured output) →
  guardrails → observability (traces, tokens, cost) → evals.
- **Evaluation**: golden set, offline metrics (retrieval hit rate, faithfulness), online
  signals (thumbs, escalations), regression gates in CI.
- **Trade-offs with numbers**: model size vs latency vs cost, context length vs retrieval,
  RAG vs fine-tuning vs prompting, build vs buy, hosted vs self-hosted models.
- **Production concerns**: timeouts, retries, fallbacks between providers, rate limits,
  caching, idempotency, tenant isolation, PII handling, prompt-injection defenses.
- **Regulation (European companies)**: GDPR basics for data sent to model providers (data
  processing agreements, EU data residency, retention) and the EU AI Act risk categories at a
  high level.

## Concept drill bank (sample, mix and go deeper)

Embeddings and similarity metrics · chunking strategies and their failure modes · HNSW vs
IVF indexes · hybrid search and RRF · rerankers · context-window limits and "lost in the middle"
· temperature / top-p · structured outputs and validation · function calling · agent loops and
their failure modes · LLM-as-judge pitfalls · hallucination mitigation · prompt caching ·
token cost estimation · quantization and running models locally · LoRA fine-tuning: when and
when not · MCP · streaming responses · evaluation datasets and contamination.

## End of session

Summary: overall level per area (system design / concepts / coding / communication), the top 3
gaps with a concrete study or build task for each (ideally something they can build with
their own `newproj` template and show on GitHub), and the 3 answers worth memorizing.
