# Implementation Plan: v0.1.0 Ship

**Date:** 2026-10-14
**Status:** Shipped as v0.1.0 on 2026-10-14 (decisions grilled 2026-10-14)
**Supersedes:** the M4 handoff in `docs/technical-plan-m4-ship.md` (Render was never connected; the SSE transport is now deprecated by Claude's connector docs).

## Overview

Take the working server (7 tools, 92 green specs, passing `bin/smoke`) from "runs on a
deprecated transport with placeholder citations and a dead URL" to a showcase-ready
v0.1.0: official MCP Ruby SDK on Streamable HTTP, every rate table cited to its real
agency circular with a verification log, a local-first README anyone can follow in two
minutes, captured examples in the repo, and a tagged release. Hosting stays $0.

## Architecture Decisions

- **Transport: clean swap to the official `mcp` gem (1.7.0), Streamable HTTP, stateless.**
  One `POST /mcp` endpoint, no `Mcp-Session-Id`, no SSE endpoints kept. fast-mcp and
  `lib/normalize_response_headers.rb` (a fast-mcp Rack 3 workaround) are removed.
  Stateless mode has no in-memory session state, so Puma worker count stops mattering.
- **Local-first, Render free tier optional.** README leads with `bundle exec rackup` +
  Claude Code / Claude Desktop / Cursor / MCP Inspector against `localhost:9292/mcp`.
  `render.yaml` stays for a $0 public URL whenever Leo connects the repo in the Render
  dashboard. Fly.io dropped (can bill). No tunnel script in the repo.
- **Citations are real or honestly flagged.** Each of the 5 tables gets its primary
  circular number after checking the agency site. `docs/VERIFICATION.md` records what
  was checked, where, when, and whether the source was primary or secondary. No
  `CONFIRM` placeholder survives into v0.1.0.
- **Showcase = `examples/` + a recording.** Captured JSON request/response per tool and a
  sample payslip live in the repo; the README embeds a ~30s gif Leo records post-tag.
- **Registry gated on a live URL.** `server.json` is updated to the new transport now;
  submission to registry.modelcontextprotocol.io / Smithery / Glama happens only after
  Render answers.
- **Git flow: one branch + PR per milestone, CI green before squash-merge.**
- **Tag v0.1.0 on local proof.** Recording, Render, and registry are post-tag items for
  Leo. Scope fence: nothing from the deferred list (semi-monthly RWT, rack-attack) is in.
- **Domain layer untouched.** `app/payroll/` and its specs do not change in M5 or M7;
  only citation strings (and any value the circular contradicts) change in M6.

## Dependency Graph

```
M5 transport swap (gem, config.ru, adapters, smoke, mount spec)
    │
    ├── M6 citations (independent of M5 — data + domain specs only)
    │
    └── M7 showcase (needs M5 for Streamable HTTP examples; needs M6 so
        │            captured examples carry real citations)
        └── tag v0.1.0 → post-tag: gif, Render, registry (Leo)
```

M5 and M6 can run in parallel on separate branches; M7 starts after both merge.

## Task List

### Phase M5: Transport migration (branch `feature/m5-streamable-http`)
- [x] Task 1: Mount the official gem's Streamable HTTP transport at `/mcp`
- [x] Task 2: Port the 7 tool adapters to `MCP::Tool` with typed number schemas
- [x] Task 3: Rewrite `bin/smoke` and the mount spec for the new transport
- [x] Task 4: Update README transport/local sections, CHANGELOG, `server.json`

### Checkpoint: M5
- [x] `bundle exec rspec` green, `bin/validate_tables` OK, `bin/smoke` PASS over `POST /mcp`
- [x] `npx @modelcontextprotocol/inspector` against `localhost:9292/mcp` lists 7 tools and
      shows `type: number` on salary fields
- [x] Plain `bundle exec rackup` (development, Rack::Lint on) serves `/mcp` without a 500
- [x] PR opened, CI green, Leo reviews before merge

### Phase M6: Rate verification (branch `feature/m6-citations`)
- [x] Task 5: SSS schedule, EC threshold, and WISP/MPF boundary against sss.gov.ph
- [x] Task 6: PhilHealth and Pag-IBIG circulars
- [x] Task 7: BIR monthly RWT table and 13th-month exemption threshold
- [x] Task 8: `docs/VERIFICATION.md` and removal of every `CONFIRM` flag

### Checkpoint: M6
- [x] `grep -ri confirm config/ app/` returns nothing
- [x] `bin/validate_tables` prints 5 tables, each with a real circular in the citation
- [x] Domain specs green; any expected value that changed is re-derived from the circular
      in the spec, never from the YAML
- [x] PR opened, CI green, Leo reviews before merge

### Phase M7: Showcase and release (branch `feature/m7-showcase`)
- [x] Task 9: Capture `examples/` from the running server
- [x] Task 10: Claude Code localhost proof, transcript saved under `examples/`
- [x] Task 11: README rewrite: local-first quickstart, gif placeholder, Render optional
- [x] Task 12: CHANGELOG 0.1.0 entry, bump `VERSION`, tag `v0.1.0`

### Checkpoint: Complete
- [x] All M5 + M6 checkpoints still hold on `main`
- [x] `examples/` contains one request + response per tool with real citations
- [x] Tag `v0.1.0` pushed; GitHub release notes = CHANGELOG entry
- [x] Post-tag checklist handed to Leo (below)

## Post-tag checklist (needs Leo's accounts / keyboard)
1. Record a ~30s clip of Claude Code or Claude Desktop computing a payslip with
   citations; drop it at `docs/demo.gif` (README already references it).
2. Render dashboard → New Web Service → connect `lmagsino/ph-payroll-mcp`; confirm
   `https://ph-payroll-mcp.onrender.com/health` returns `ok`.
3. claude.ai → Settings → Connectors → add `https://ph-payroll-mcp.onrender.com/mcp`;
   ask for a ₱30,000 employed payslip; expect net ₱26,542.45 (or the M6-corrected
   figure) with four cited circulars.
4. Submit `server.json` to the official registry; list on Smithery / Glama.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Official gem 1.7 API differs from the docs page (e.g. `call` signature, `input_schema` keywords, `enable_json_response` default) | Med | Task 1 starts by reading the installed gem's `lib/mcp/server/transports/streamable_http_transport.rb` and `lib/mcp/tool.rb`, not the docs; write against the source |
| Stateless mode rejected by a client that insists on `Mcp-Session-Id` | Med | Inspector + Claude Code are both verified in M5/M7 checkpoints; if one balks, flip to stateful with Puma `workers 0` (one-line change, documented in Task 1) |
| Agency site unreachable or circular not published as a stable URL | Med | Cite the circular number from the agency's own page or PDF; if only secondary sources reach it, the citation string says "per secondary sources" and VERIFICATION.md names them. Never silently upgrade a secondary to primary |
| A verified circular contradicts a current value (EC threshold ₱14,500 vs ₱15,000; irregular MSC brackets) | Med | Fix the YAML, re-derive the affected golden values by hand from the circular, update the spec with the derivation in a comment; CHANGELOG notes the correction |
| Rack 3 lowercase-header Lint failure returns with the new gem | Low | M5 checkpoint runs plain `rackup` in development; reintroduce a header normalizer only if the gem actually emits capitalized names |
| `examples/` drift once rates change next year | Low | Each example file carries the `effective_date` it was captured under; the M6 verification doc says to regenerate on a data PR |

## Open Questions

None blocking. Decisions already taken (2026-10-14): transport swap, local-first + Render
optional, real citations + verification doc, examples + recording, registry gated on live
URL, no scope additions, branch + PR per milestone, tag on local proof.
