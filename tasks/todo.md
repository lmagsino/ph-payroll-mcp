# v0.1.0 Ship — Task List

Plan and decisions: `tasks/plan.md`. One branch + PR per phase; CI green before merge.

---

## Phase M5: Transport migration — branch `feature/m5-streamable-http`

### Task 1: Mount the official gem's Streamable HTTP transport at `/mcp`

**Description:** Replace fast-mcp with the official `mcp` gem (1.7.0). `config.ru` builds an
`MCP::Server` with the 7 tools and wraps it in
`MCP::Server::Transports::StreamableHTTPTransport` in stateless mode, routed at `/mcp`
ahead of the Sinatra app (which keeps `/health`). Remove
`lib/normalize_response_headers.rb` and its `use` line. Keep `Rack::Cors`. Boot-time
`Payroll::RateTables.load!` stays.

**Acceptance criteria:**
- [x] `Gemfile` has `gem "mcp", "~> 1.7"` and no `fast-mcp`; `Gemfile.lock` regenerated
- [x] `POST /mcp` with an `initialize` request returns a JSON-RPC result naming the
      server `ph-payroll-mcp` and the `VERSION` file's version
- [x] `GET /health` still returns `ok`; unknown paths still 404 from Sinatra
- [x] `lib/normalize_response_headers.rb` deleted; plain `bundle exec rackup` in
      development serves `/mcp` without a Rack::Lint 500

**Verification:**
- [x] `bundle exec rspec spec/health_spec.rb spec/mcp_mount_spec.rb` (mount spec is
      rewritten in Task 3; until then only health must pass)
- [x] `bundle exec rackup` then `curl -X POST localhost:9292/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'` returns a result
- [x] Manual check: read the installed gem's transport source first; note in the config.ru
      comment which constructor options were used (`stateless:`, `allowed_origins:`,
      `enable_json_response:` if it exists) and why

**Dependencies:** None

**Files likely touched:**
- `Gemfile`, `Gemfile.lock`
- `config.ru`
- `lib/normalize_response_headers.rb` (delete)
- `app/mcp/tools.rb` (registration shape may change)

**Estimated scope:** Small (3-4 files)

---

### Task 2: Port the 7 tool adapters to `MCP::Tool` with typed number schemas

**Description:** `Tools::BaseTool` becomes a subclass of `MCP::Tool`. Each adapter declares
`tool_name`, `description`, and a hand-written `input_schema` (JSON Schema `properties` +
`required`) in which money fields are `type: number` and enums are `enum: [...]`. The
class-level `call(server_context:, **args)` keeps the existing `domain { }` wrapper, and
`respond` returns `MCP::Tool::Response.new([{ type: "text", text: json }])`. The
`jsonify` BigDecimal/Date coercion and the error mapping (`invalid_input`,
`no_rate_table`) are unchanged.

**Acceptance criteria:**
- [x] `tools/list` over `POST /mcp` returns 7 tools; every salary / income / deduction
      property has `"type": "number"` (no `"not": {"type": "null"}`), `member_type` and
      `table` carry `enum`, `as_of` has `format: date`
- [x] Every tool still returns a single text content block of clean JSON with
      `source_circular` (or `sources`) present
- [x] Domain errors still come back as `{error, message}` payloads, never a raised
      exception reaching the transport
- [x] `spec/mcp/tools/tools_spec.rb` passes with the `call_with_schema_validation!`
      example replaced by a `json_schemer` validation of each tool's `input_schema`
      accepting an integer salary

**Verification:**
- [x] `bundle exec rspec spec/mcp/tools/tools_spec.rb`
- [x] `bundle exec ruby -e 'require "./app/mcp/tools"; Tools::ALL.each { |t| puts t.name, JSON.pretty_generate(t.input_schema.to_h) }'` shows `number` types
- [ ] Manual check: Inspector's tool form renders numeric inputs for salary fields (verified via Inspector CLI schema only, not the web form)

**Dependencies:** Task 1

**Files likely touched:**
- `app/mcp/tools/base_tool.rb`
- `app/mcp/tools/compute_*.rb` (6 files) and `get_contribution_table.rb`
- `spec/mcp/tools/tools_spec.rb`

**Estimated scope:** Medium (9 small files, mechanical)

---

### Task 3: Rewrite `bin/smoke` and the mount spec for the new transport

**Description:** `bin/smoke` boots Puma and drives `POST /mcp` directly: `initialize`,
`notifications/initialized`, `tools/list`, `tools/call compute_net_pay`. It parses either a
JSON body or an SSE body (`data:` lines) so it holds under both response modes. Asserts 7
tools and a `net_pay` figure. `spec/mcp_mount_spec.rb` becomes a real round-trip over
rack-test (possible now that a stateless POST answers in-band): `tools/list` count and a
`tools/call` result, plus the Sinatra passthrough 404.

**Acceptance criteria:**
- [x] `bin/smoke` exits 0 and prints the 7 tool names and the net-pay figure
- [x] `spec/mcp_mount_spec.rb` asserts `tools/list` returns 7 tools and
      `tools/call compute_net_pay` returns a payload with `net_pay` and four `sources`
- [x] The lowercase-header example is dropped (no normalizer exists any more) or kept
      only if the gem emits lowercase headers on its own

**Verification:**
- [x] `bundle exec rspec`
- [x] `bin/smoke`
- [x] CI workflow unchanged and green (it already runs validate_tables + rspec)

**Dependencies:** Tasks 1, 2

**Files likely touched:**
- `bin/smoke`
- `spec/mcp_mount_spec.rb`
- `spec/spec_helper.rb` (only if the Rack::Builder parse needs adjusting)

**Estimated scope:** Small (2-3 files)

---

### Task 4: Update README transport/local sections, CHANGELOG, `server.json`

**Description:** README "Transport" section describes Streamable HTTP at `/mcp` (protocol
2025-06-18, official Ruby SDK) and the "Run locally" block shows Inspector against
`localhost:9292/mcp`. CHANGELOG Unreleased: transport swapped, fast-mcp removed, number
schemas fixed; the SSE known-limitation line goes. `server.json` remote becomes
`{"type": "streamable-http", "url": "https://ph-payroll-mcp.onrender.com/mcp"}` with the
`$schema` URL checked against the current registry schema.

**Acceptance criteria:**
- [x] No mention of `/mcp/sse`, `/mcp/messages`, fast-mcp, or protocol 2024-11-05 remains
      anywhere in README, CHANGELOG Unreleased, or `server.json`
- [x] `server.json` validates against its `$schema` (fetch and check with a JSON Schema
      validator, or `npx @modelcontextprotocol/registry validate` if available)

**Verification:**
- [x] `grep -rn "sse\|fast-mcp\|2024-11-05" README.md CHANGELOG.md server.json` is empty
      (apart from the CHANGELOG "Removed" line that names fast-mcp)
- [x] Manual check: README local-run block works copy-pasted on a clean clone

**Dependencies:** Task 3

**Files likely touched:**
- `README.md`, `CHANGELOG.md`, `server.json`

**Estimated scope:** Small (3 files)

---

## Checkpoint: After M5 (Tasks 1-4)
- [x] `bundle exec rspec` green, `bin/validate_tables` OK, `bin/smoke` PASS
- [x] Inspector lists 7 tools with `number` types on money fields
- [x] Plain development `rackup` serves `/mcp`
- [x] PR `feature/m5-streamable-http` → `main`, CI green, Leo reviews before merge

---

## Phase M6: Rate verification — branch `feature/m6-citations`

### Task 5: SSS schedule, EC threshold, and WISP/MPF boundary against sss.gov.ph

**Description:** Find the SSS circular that sets the 2025-onward schedule (15% total, ER
10% / EE 5%, MSC ₱5,000–₱35,000, MPF/"MySSS Pension Booster" above ₱20,000, OFW floor
₱8,000) on sss.gov.ph. Confirm the EC contribution threshold (secondary sources disagree:
₱14,500 vs ₱15,000) and whether MSC brackets are uniform ₱500 steps. Update `sss.yml`
citation and any contradicted value; re-derive affected golden spec values by hand from
the circular.

**Acceptance criteria:**
- [x] `config/contribution_tables/sss.yml` `source_circular` names the circular number
      and year; the file header comment no longer says CONFIRM
- [x] EC threshold and bracket shape match the circular; if changed, the spec comment shows
      the hand derivation
- [x] `spec/payroll/sss_calculator_spec.rb` green

**Verification:**
- [x] `bundle exec rspec spec/payroll/sss_calculator_spec.rb spec/payroll/net_pay_calculator_spec.rb`
- [x] `bin/validate_tables`
- [x] Manual check: the URL recorded in VERIFICATION.md opens and shows the figures

**Dependencies:** None (parallel with M5)

**Files likely touched:**
- `config/contribution_tables/sss.yml`
- `spec/payroll/sss_calculator_spec.rb` (only if a value changed)
- `docs/VERIFICATION.md` (entry; file created in Task 8 or here)

**Estimated scope:** Small (1-3 files) + research

---

### Task 6: PhilHealth and Pag-IBIG circulars

**Description:** Cite the PhilHealth premium schedule (5%, floor ₱10,000, ceiling
₱100,000) to the UHC-law circular / 2024-2025 advisory in force for 2026, and Pag-IBIG
(2%/2%, 1% EE under ₱1,500, ₱10,000 ceiling) to HDMF Circular No. 460 with its effective
date. Update both YAML citations and header comments.

**Acceptance criteria:**
- [x] `philhealth.yml` and `pagibig.yml` carry circular numbers and no CONFIRM text
- [x] Values unchanged unless a circular contradicts them (then same re-derivation rule)

**Verification:**
- [x] `bundle exec rspec spec/payroll/philhealth_calculator_spec.rb spec/payroll/pagibig_calculator_spec.rb`
- [x] `bin/validate_tables`

**Dependencies:** None

**Files likely touched:**
- `config/contribution_tables/philhealth.yml`, `config/contribution_tables/pagibig.yml`
- `docs/VERIFICATION.md`

**Estimated scope:** Small (2-3 files) + research

---

### Task 7: BIR monthly RWT table and 13th-month exemption threshold

**Description:** Cite the monthly Revised Withholding Tax table (over / base / rate rows
20,833 … 666,667) to the BIR Revenue Regulation that publishes the 2023-onward table under
TRAIN (RA 10963), and the ₱90,000 13th-month / other-benefits exemption to its RR/RMC.
Check the six monthly rows digit by digit against the BIR table.

**Acceptance criteria:**
- [x] `withholding_tax.yml` and `thirteenth_month.yml` carry RR/RMC numbers and no
      CONFIRM text
- [x] All six bracket rows match the BIR table exactly

**Verification:**
- [x] `bundle exec rspec spec/payroll/withholding_tax_calculator_spec.rb spec/payroll/thirteenth_month_calculator_spec.rb`
- [x] `bin/validate_tables`

**Dependencies:** None

**Files likely touched:**
- `config/contribution_tables/withholding_tax.yml`, `config/contribution_tables/thirteenth_month.yml`
- `docs/VERIFICATION.md`

**Estimated scope:** Small (2-3 files) + research

---

### Task 8: `docs/VERIFICATION.md` and removal of every `CONFIRM` flag

**Description:** One table per agency: value checked, figure, source URL, circular number,
date checked, primary/secondary. A short "how to re-verify next year" section explains that
a rate change is a data PR plus a new VERIFICATION.md row and a regenerated `examples/`.
Sweep the repo for leftover `CONFIRM` / "BEST-EFFORT" wording (YAML headers,
`WithholdingTaxCalculator` class comment, CHANGELOG known-limitations).

**Acceptance criteria:**
- [x] `grep -rni "confirm\|best-effort" config/ app/ README.md CHANGELOG.md` is empty
- [x] VERIFICATION.md has a row for every value in every YAML file
- [x] CHANGELOG "Known limitations" rate-data caveat replaced by a pointer to
      VERIFICATION.md

**Verification:**
- [x] `bundle exec rspec` (full)
- [x] `bin/validate_tables` prints 5 real citations

**Dependencies:** Tasks 5, 6, 7

**Files likely touched:**
- `docs/VERIFICATION.md` (new)
- `app/payroll/withholding_tax_calculator.rb` (comment only)
- `CHANGELOG.md`

**Estimated scope:** Small (3 files)

---

## Checkpoint: After M6 (Tasks 5-8)
- [x] No CONFIRM / best-effort text in config, app, README, CHANGELOG
- [x] `bin/validate_tables` shows a real circular per table
- [x] Full suite green
- [x] PR `feature/m6-citations` → `main`, CI green, Leo reviews before merge

---

## Phase M7: Showcase and release — branch `feature/m7-showcase` (after M5 + M6 merge)

### Task 9: Capture `examples/` from the running server

**Description:** A small `bin/capture_examples` script boots the server and writes
`examples/<tool>.json` for each of the 7 tools (request + response, pretty-printed) plus
`examples/payslip-30k-employed.md`, a human-readable rendering of `compute_net_pay`. Each
file records the `effective_date` it was captured under.

**Acceptance criteria:**
- [x] 7 JSON files + 1 markdown payslip under `examples/`, every response showing a real
      circular
- [x] `bin/capture_examples` is idempotent (re-running produces the same files)

**Verification:**
- [x] `bin/capture_examples && git status --short examples/` clean on a second run
- [x] Manual check: payslip figures match `bin/smoke` output

**Dependencies:** M5 + M6 merged

**Files likely touched:**
- `bin/capture_examples` (new), `examples/*` (new, 8 files)

**Estimated scope:** Medium (new script + generated files)

---

### Task 10: Claude Code localhost proof, transcript saved under `examples/`

**Description:** `claude mcp add --transport http ph-payroll http://localhost:9292/mcp`,
then ask for a ₱30,000 employed payslip and a "which circular is the SSS figure from?"
follow-up. Save the exchange as `examples/claude-code-session.md`. This is the
end-to-end proof that a real MCP client resolves the tools and cites the sources.

**Acceptance criteria:**
- [x] Transcript shows `compute_net_pay` invoked and the answer quoting the four
      circulars
- [x] If Claude Code rejects stateless mode, the fix (stateful + `workers 0`) is applied in
      the same PR and the transcript re-captured

**Verification:**
- [x] Manual check only (client interaction)

**Dependencies:** Task 9

**Files likely touched:**
- `examples/claude-code-session.md` (new)

**Estimated scope:** XS

---

### Task 11: README rewrite: local-first quickstart, gif placeholder, Render optional

**Description:** Restructure README: 60-second local quickstart first (clone, bundle,
rackup, connect from Claude Code / Claude Desktop / Cursor / Inspector with exact config
snippets), then a `![demo](docs/demo.gif)` placeholder with a one-line caption, then
`examples/` pointer, then "Optional: public URL on Render (free)" with the connector
steps, then data sources → VERIFICATION.md, disclaimer, stack, author, license.

**Acceptance criteria:**
- [x] A new reader can get `tools/list` from Inspector by following the README verbatim
- [x] Claude Desktop and Cursor config snippets are valid JSON for an HTTP server entry
- [x] Render section is clearly optional and names the cold-start tradeoff

**Verification:**
- [x] Manual check: follow the README on a fresh clone in a temp dir
- [x] `grep -n "demo.gif" README.md` finds the placeholder

**Dependencies:** Tasks 9, 10

**Files likely touched:**
- `README.md`

**Estimated scope:** Small (1 file)

---

### Task 12: CHANGELOG 0.1.0 entry, bump `VERSION`, tag `v0.1.0`

**Description:** Move Unreleased to `[0.1.0] - <merge date>`, keep `VERSION` at `0.1.0`
(already), tag after the M7 PR merges to `main`, create a GitHub release whose notes are
the CHANGELOG entry. Add the post-tag checklist from `tasks/plan.md` to the release notes.

**Acceptance criteria:**
- [x] `git tag v0.1.0` on the merge commit, pushed
- [x] `gh release view v0.1.0` shows the CHANGELOG entry and the post-tag checklist

**Verification:**
- [x] `gh release view v0.1.0`
- [x] CI green on the tagged commit

**Dependencies:** Task 11 merged

**Files likely touched:**
- `CHANGELOG.md`

**Estimated scope:** XS

---

## Checkpoint: Complete
- [x] M5 + M6 checkpoints hold on `main`
- [x] `examples/` committed with real citations
- [x] `v0.1.0` tagged and released
- [x] Post-tag checklist (gif, Render, claude.ai connector, registry) handed to Leo
