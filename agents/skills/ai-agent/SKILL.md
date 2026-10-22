---
name: ai-agent
description: Design and build a tool-calling AI agent (an LLM that loops — think, call tools, read results — until a task is done) in Python with LiteLLM, with step limits, typed tools, permission checks, tracing and tests. Use when the user wants an agent, an assistant that takes actions, multi-step automation, or function/tool calling.
---

# Build a tool-calling agent

Start with the simplest thing that works: one model call → a fixed pipeline → only then a loop.
Use an agent loop when the steps genuinely can't be known in advance.

## 1. Define the job

- Goal, inputs, what "done" looks like, and what the agent must **never** do.
- List the tools it needs (3–8). Each tool: name, one-line purpose, typed arguments, typed
  result, side effects, who is allowed to trigger it.

## 2. Tools

- Plain Python functions with Pydantic argument models; generate the JSON schema from the
  model (`Args.model_json_schema()`) so code and schema can't drift.
- Read-only tools run freely. Tools that write, spend money or send messages need a policy:
  dry-run first, human approval, or hard allow-lists.
- Tool results are untrusted text (web pages, emails, documents can contain injected
  instructions). Return data, truncate large results, and never let a tool result widen the
  agent's permissions.

## 3. The loop (LiteLLM, any provider)

```python
messages = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": task}]
for step in range(MAX_STEPS):                       # hard stop, e.g. 10
    response = litellm.completion(model=model, messages=messages, tools=TOOL_SCHEMAS,
                                  timeout=60, num_retries=2, **credentials)
    message = response.choices[0].message
    messages.append(message.model_dump(exclude_none=True))
    if not message.tool_calls:
        return message.content                      # final answer
    for call in message.tool_calls:
        result = run_tool(call.function.name, call.function.arguments, user=current_user)
        messages.append({"role": "tool", "tool_call_id": call.id, "content": result})
raise AgentStepLimit(task)
```

`run_tool` looks the name up in an explicit registry, validates arguments with the tool's
Pydantic model, checks permissions, catches exceptions and returns an error string the model
can recover from — it never `eval`s or imports by name.

## 4. Guardrails

- Budgets: max steps, max total tokens/cost, wall-clock timeout, max calls per tool.
- Detect loops (same tool + same arguments twice) and stop.
- Local models (`ollama/gemma4:12b`) are fine for development; verify tool-calling quality with
  evals before relying on them.

## 5. Observability

Log one trace per run: task id, every step (tool name, argument summary, result size, latency,
tokens), final status. Never log secrets or full documents. A run you can't replay from logs
can't be debugged.

## 6. Tests and evals

- Unit-test every tool on its own.
- Test the loop with a scripted fake model (monkeypatch `litellm.completion` to return a
  sequence of tool calls then a final answer): stops at the step limit, rejects unknown tools,
  survives a failing tool, refuses a tool the user lacks permission for.
- Task-level evals (`llm-evals` skill): did it reach the right final state, in how many steps,
  at what cost.

## When to reach for a framework

Only when you need what it gives (durable state, human-in-the-loop resume, multi-agent
hand-offs). Know what the plain loop above does first, so the framework isn't magic.
