---
name: mcp-server
description: Build, test and connect a Model Context Protocol (MCP) server in Python so Claude Code, Claude desktop, Gemini CLI or other agents can use the user's own tools, APIs or data. Use when the user wants to expose functions, a database, an internal API or files to AI agents through MCP.
---

# Build an MCP server (Python SDK v2)

MCP lets any compatible agent call your tools. A server exposes **tools** (actions the model
can call), **resources** (read-only data addressed by URI) and **prompts** (reusable templates).

## 1. Set up

```bash
uv init --package <name> && cd <name>
uv add "mcp[cli]"
```

## 2. Server

```python
# src/<pkg>/server.py
from mcp.server import MCPServer

mcp = MCPServer("<name>")


@mcp.tool()
def search_orders(customer_email: str, limit: int = 10) -> list[dict[str, str]]:
    """Find a customer's most recent orders. Use when the user asks about order status."""
    ...


@mcp.resource("orders://{order_id}")
def order(order_id: str) -> str:
    """Full details of one order as JSON."""
    ...


if __name__ == "__main__":
    mcp.run()  # stdio by default; mcp.run("streamable-http") to serve over HTTP
```

Type hints and the docstring **are** the tool's schema and description — the model decides
when to call a tool from them, so write them for the model: what it does, when to use it,
what each argument means. Return structured data (dicts / Pydantic models), not prose.

## 3. Design rules

- Few, task-shaped tools (`search_orders`) beat thin wrappers around every endpoint.
- Validate every argument (Pydantic, enums, max lengths, `limit` caps). The caller is a model
  that can be manipulated by prompt injection in whatever text it read.
- Least privilege: read-only by default; destructive tools need explicit names
  (`delete_draft`), confirmation parameters and audit logs.
- Secrets come from environment variables, never from tool arguments or source code.
- Errors: raise with a clear message the model can act on ("order not found; check the id
  format ORD-123"), never leak stack traces or internal hosts.
- stdio servers must never print to stdout (it carries the protocol) — log to stderr.

## 4. Test

In-memory, no subprocess — fast pytest tests:

```python
import pytest
from mcp import Client

from <pkg>.server import mcp


@pytest.mark.anyio
async def test_search_orders() -> None:
    async with Client(mcp) as client:
        tools = await client.list_tools()
        assert "search_orders" in [t.name for t in tools.tools]
        result = await client.call_tool("search_orders", {"customer_email": "a@b.co"})
        assert not result.is_error
```

(The `anyio` marker comes with the SDK's `anyio` dependency.) Interactive check in the MCP
Inspector: `uv run mcp dev src/<pkg>/server.py`.

## 5. Connect it

```bash
# Claude Code (scope: local = this project only, project = shared via .mcp.json, user = everywhere)
claude mcp add --scope user --transport stdio <name> -- uv run --directory "$PWD" python -m <pkg>.server

# Gemini CLI
gemini mcp add <name> uv run --directory "$PWD" python -m <pkg>.server

# A server running over HTTP
claude mcp add --transport http <name> http://localhost:8000/mcp
```

Environment variables for the server: `claude mcp add --env API_KEY=… --transport stdio <name> -- …`.
Never commit `.mcp.json` entries that contain secrets.

## 6. Ship

Remote servers: Streamable HTTP behind HTTPS with authentication, rate limits and request
logs; package with the project Dockerfile pattern (non-root user). Third-party MCP servers get
the same scrutiny as any untrusted code — run the `repo-audit` skill before installing one.
