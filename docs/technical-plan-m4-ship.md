# Technical Plan: M4 — Ship

**Implementation Plan:** docs/PLAN.md
**Milestone:** M4 — make it live and discoverable
**Depends on:** M1–M3 (shipped: foundation, calculators, MCP surface).
**Date:** 2026-07-07
**Status:** Draft

## Overview
Take the working server public. Transport decision (locked): **ship HTTP+SSE now**
(fast-mcp 1.6.0, protocol 2024-11-05), verify against a real client, defer any Streamable
HTTP migration until a client actually rejects SSE. Boring / incremental / reversible.

## In-repo (done in this milestone)
- **`bin/smoke`** — end-to-end SSE handshake + tools/list + compute_net_pay over real Puma.
  The automated "a client connects and it works" gate. Passing.
- **`server.json`** — MCP registry manifest (name `io.github.lmagsino/ph-payroll-mcp`,
  SSE remote at `/mcp/sse`). VERIFY the `$schema` URL + field shape against the current
  registry spec at submission time — it is still moving.
- **`CHANGELOG.md`** — 0.1.0 Unreleased, with the rate-data + transport caveats stated.
- **README** — Transport, Deploy, and local-verification (`bin/smoke`) sections; the
  liability disclaimer is already present.

## Handoff — steps that need your accounts (not automatable here)

1. **Deploy to Render.**
   - New Web Service → connect `lmagsino/ph-payroll-mcp` → Render reads `render.yaml`
     (free plan, `bundle install`, `puma -e production`, `/health` check, Ruby 3.3.11
     from `.ruby-version`).
   - Confirm the live URL matches `server.json` / README (`https://ph-payroll-mcp.onrender.com`),
     or update both if Render assigns a different host.

2. **Verify against a real client (the real transport test).**
   - Add the custom connector in Claude: Settings → Connectors → Add → the SSE URL.
   - Ask: "compute the net pay for a ₱30,000/month employed worker in the Philippines."
   - Expect a full payslip with cited circulars. If the connector rejects the SSE
     transport, that's the signal to revisit the Streamable HTTP migration (tracked below).

3. **Submit to the registries** (after the live URL works):
   - Official MCP registry (registry.modelcontextprotocol.io) via `server.json`.
   - Smithery, MCPMarket, Glama listings.
   - Record a ~30s demo gif in the README (an LLM computing a payslip with citations).

## Gating before public use (your data-verification pass)
Every rate/bracket/threshold is flagged `CONFIRM`. Verify against the primary circulars
(sss.gov.ph, philhealth.gov.ph, pagibigfund.gov.ph, bir.gov.ph), record the circular
numbers in each `source_circular`, and update the golden test expected values from the
circular (not the YAML). This is the difference between "logic correct" and "numbers you
would stake authoritative, cited output on."

## Deferred / TODO
- Streamable HTTP (2025 spec) transport migration — swap fast-mcp for a Streamable-capable
  MCP library if/when a target client requires it.
- rack-attack rate limiting (from the eng-review TODO).
- Daily/weekly/semi-monthly RWT columns (from the eng-review TODO).

## Ship checklist
- [x] `bin/smoke` passes over real HTTP+SSE
- [x] `server.json` manifest present
- [x] CHANGELOG + README (transport, deploy, verify, disclaimer)
- [ ] Deployed to Render; live URL reachable
- [ ] Verified from a real Claude/ChatGPT connector
- [ ] Rate data verified against primary circulars
- [ ] Submitted to the MCP registries
