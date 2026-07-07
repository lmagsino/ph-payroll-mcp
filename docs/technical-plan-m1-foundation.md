# Technical Plan: M1 — Foundation

**Implementation Plan:** /Users/leomagsino-shiftcare/Desktop/Developer/plans/ph-payroll-mcp.md
**Milestone:** M1 — Foundation (scaffold + shared contracts + rate-table infra)
**Date:** 2026-07-07
**Status:** Draft

## Overview
Stand up the Sinatra/Rack + `fast-mcp` skeleton and the three contracts every later
milestone depends on: the `Result` value object (carries the citation), the
`BaseCalculator` (BigDecimal math + clamp/round/validate helpers), and the `RateTables`
registry (loads versioned YAML, selects by effective_date, fails loud, validated at boot
and in CI). No tools or calculators ship in M1 — this is the frozen foundation the five
parallel calculator lanes build on.

```
config.ru ──use──▶ FastMcp::RackMiddleware (mounts /mcp)   [tools registered in later milestones]
   │  └─ Sinatra app: GET /health → 200
   ▼
app/payroll/
   Result            (amounts + effective_date + source_circular; the citation contract)
   BaseCalculator    (bd/clamp/round_centavo/validate; #result builds a Result from a table)
   RateTables        (boot-load + schema-validate all YAML; .for(agency, as_of:) → Table | raise)
   Table             (one versioned entry: agency, effective_date, source_circular, data)
   ▲
config/contribution_tables/*.yml   (versioned rate data; string-typed rates)
bin/validate_tables                (standalone schema validator: boot + CI)
```

---

### Ticket 1.1 — Project scaffold (Sinatra/Rack + fast-mcp + tooling)

**Files to Change:**
| File | Change |
|---|---|
| `Gemfile` | `fast-mcp` (pin exact version — [Layer 2], expect churn), `puma`, `rackup`, `rack-cors`, `sinatra`; group :development,:test → `rspec`, `rack-test`; `dotenv` |
| `Gemfile.lock` | committed |
| `config.ru` | Rack entry: `rack-cors` → `FastMcp::RackMiddleware` (name `ph-payroll-mcp`, version from VERSION) → Sinatra app |
| `app.rb` | tiny Sinatra app: `GET /health` → `200 "ok"` |
| `VERSION` | `0.1.0` |
| `.ruby-version` | pin Ruby (3.3.x) |
| `Procfile` / `render.yaml` | `web: bundle exec puma -p $PORT` |
| `.env.example` | documents `PORT` (no secrets — no auth in v1) |

**Architecture:**
- Pure Rack `config.ru` is the composition root. `fast-mcp` is Rack middleware
  (`use FastMcp::RackMiddleware.new(...) { |s| s.register_tool(...) }`), so it sits in
  front of a minimal Sinatra app that only serves `/health`. Tools get registered here
  in later milestones — M1 registers none.
- `rack-cors` first in the stack so cross-origin MCP clients (Claude/ChatGPT connectors)
  pass preflight. Allow all origins for v1 (public data, no auth).

**Implementation Steps:**
1. `bundle init`; add gems; `bundle install`. Pin `fast-mcp` to the exact current version.
2. `config.ru`: `require`s, `use Rack::Cors do ... allow origins '*' ... end`,
   `use FastMcp::RackMiddleware.new(name: 'ph-payroll-mcp', version: File.read('VERSION').strip)`,
   `run Sinatra::Application`.
3. `app.rb`: `get('/health') { 'ok' }`.
4. Verify locally: `bundle exec rackup`, then `curl localhost:9292/health` → `ok`,
   and `npx @modelcontextprotocol/inspector` against `localhost:9292/mcp` shows an empty tool list.

**Edge Cases & Failure Modes:**
- `fast-mcp` API drift between versions — pin the version and add a comment linking the
  README revision used. A minor-version bump silently changing the middleware signature
  would break the mount; the pin + the E2E test (M4) catch it.
- Missing `PORT` env in prod → Procfile uses `$PORT`; document default in `.env.example`.

**Performance:** middleware chain is trivial; `/health` allocates nothing. No concern.

**Security & Data Integrity:** no auth by design (public data). `rack-cors` `*` is
intentional. Disclaimer belongs on tool output/README (M4), not here.

**Migration & Deployment:** no DB, no migrations. Rolling deploy safe (stateless).
Rollback = git revert. Render cold start documented honestly (no keep-alive pinger, per D12).

**Test Plan:**
| Test File | Scenario | Type |
|---|---|---|
| `spec/health_spec.rb` | `GET /health` → 200 body "ok" | integration (rack-test) |
| `spec/mcp_mount_spec.rb` | middleware mounted; `/mcp` responds to a `tools/list` JSON-RPC with an (empty) tools array | integration |

**What's Missing (checklist):**
- [ ] `fast-mcp` version pinned with a comment
- [ ] CORS preflight verified from a browser-origin request
- [ ] `/health` returns fast enough to serve as the liveness probe

---

### Ticket 1.2 — `Result` value object (the citation contract)

**Files to Change:**
| File | Change |
|---|---|
| `app/payroll/result.rb` | new immutable value object |
| `spec/payroll/result_spec.rb` | new |

**Architecture:**
- `Payroll::Result` holds `amounts` (Hash of symbol → BigDecimal), `effective_date` (Date),
  and `source_circular` (String). It is the single place the citation contract lives (D5) —
  no tool or calculator constructs its own output hash.
- `#to_h` serializes for MCP JSON: amounts rounded to 2 dp, `effective_date` as ISO string,
  `source_circular` verbatim, plus a derived human string `as_of: "as of <date>, per <circular>"`
  so the LLM naturally surfaces the citation.

**Implementation Steps:**
1. `Result = Data.define(:amounts, :effective_date, :source_circular)` (Ruby 3.2+ `Data`),
   or a frozen `Struct` if preferring. Add `#to_h` that formats amounts.
2. Money serialization decision: emit amounts as JSON **numbers** rounded half-up to 2 dp
   (BigDecimal kept internally; `.to_f.round(2)` only at the boundary). Rationale: LLMs parse
   numbers more reliably than money-strings; values are small so 2dp float is exact for display.
   Document this in a comment. (If a downstream consumer ever needs exactness, switch to strings.)
3. Guard: `to_h` raises if `source_circular` is blank — the contract cannot ship an uncited number.

**Edge Cases & Failure Modes:**
- Blank/nil `source_circular` → raise in the constructor (fail loud; a number with no
  citation is the one thing this project must never emit).
- `effective_date` nil → raise.
- amounts containing a Float instead of BigDecimal → coerce or raise (keep the type invariant).

**Test Plan:**
| Test File | Scenario | Type |
|---|---|---|
| `spec/payroll/result_spec.rb` | `to_h` rounds amounts half-up to 2dp | unit |
| " | includes ISO effective_date + verbatim source_circular + `as_of` string | unit |
| " | blank source_circular → raises | unit |
| " | nil effective_date → raises | unit |

**What's Missing (checklist):**
- [ ] Rounding mode explicitly HALF_UP (matches agency convention)
- [ ] `as_of` human string present for the LLM to echo

---

### Ticket 1.3 — `BaseCalculator` (BigDecimal math + shared helpers)

**Files to Change:**
| File | Change |
|---|---|
| `app/payroll/base_calculator.rb` | new abstract base |
| `spec/payroll/base_calculator_spec.rb` | new |

**Architecture:**
- Abstract base for all agency calculators (D1, D5). Subclasses implement `#compute(table, **inputs)`
  and get shared helpers. `BaseCalculator` never knows agency-specific rules — only the
  cross-cutting mechanics: coercion, clamping, rounding, validation, and Result construction.
- Public entrypoint `#call(as_of: Date.today, **inputs)`: fetches the table via
  `RateTables.for(self.class.agency, as_of:)`, runs `#validate!(inputs)`, then `#compute`,
  wraps in a `Result` stamped with that table's citation. This guarantees every result is
  cited by construction.

**Implementation Steps (helpers):**
1. `bd(x)` → `BigDecimal(x.to_s)` with a guard: non-numeric or non-finite → raise `InvalidInput`.
2. `round_centavo(amount)` → `amount.round(2, BigDecimal::ROUND_HALF_UP)`.
3. `clamp(value, floor:, ceiling:)` → used ONLY for legal statutory bounds on an
   already-validated positive value (D4). Never used to "fix" invalid input.
4. `validate_positive_finite!(value, field:)` → raise `InvalidInput` on negative, zero
   (where illegal), NaN, or Infinity.
5. `result(amounts, table)` → `Payroll::Result.new(amounts:, effective_date: table.effective_date, source_circular: table.source_circular)`.
6. Define error classes: `Payroll::InvalidInput`, reuse `RateTables::MissingRateTable`.

**Edge Cases & Failure Modes:**
- `bd("abc")`, `bd(nil)`, `bd(Float::INFINITY)` → `InvalidInput` (not a silent 0).
- `clamp` called with floor > ceiling (misconfigured table) → raise (data bug, fail loud).
- Subclass forgets to implement `#compute` → `NotImplementedError` with a clear message.

**Performance:** BigDecimal ops on scalars; negligible. Helpers allocate minimally.

**Test Plan:**
| Test File | Scenario | Type |
|---|---|---|
| `spec/payroll/base_calculator_spec.rb` | `bd` coerces valid, raises on "abc"/nil/Infinity/NaN | unit |
| " | `round_centavo` rounds half-up (e.g. 1.005 → 1.01) | unit |
| " | `clamp` bounds correctly; raises if floor>ceiling | unit |
| " | `validate_positive_finite!` raises on negative/zero/non-finite | unit |
| " | `call` on a stub subclass returns a Result with the table's citation | unit |
| " | unimplemented `#compute` raises NotImplementedError | unit |

**What's Missing (checklist):**
- [ ] Rounding mode centralized here (no calculator rounds on its own)
- [ ] `InvalidInput` messages are LLM-relayable (say what was wrong)
- [ ] `clamp` documented as legal-range-only, never input-sanitizing

---

### Ticket 1.4 — `RateTables` registry + `Table` (effective-date selection, fail-loud)

**Files to Change:**
| File | Change |
|---|---|
| `app/payroll/table.rb` | new value object (one versioned table entry) |
| `app/payroll/rate_tables.rb` | new registry: boot-load + validate + select |
| `config/contribution_tables/*.yml` | seed structure (real numbers verified in M2) |
| `spec/payroll/rate_tables_spec.rb` | new |
| `spec/fixtures/contribution_tables/` | test-only YAML fixtures |

**Architecture:**
- `RateTables` loads every YAML under `config/contribution_tables/` **once at boot** into a
  frozen structure (performance: no per-request parsing). Each file yields one or more
  `Table` entries keyed by `(agency, effective_date)`.
- Selection (D10): `RateTables.for(agency, as_of: Date.today)` returns the `Table` with the
  latest `effective_date <= as_of`. If none → raise `RateTables::MissingRateTable` naming the
  latest available effective_date for that agency (D3 fail-loud). This is what stops the
  server from silently serving the wrong-period rate.
- `Table` = `Data.define(:agency, :effective_date, :source_circular, :data)`, frozen.

**YAML shape (per file, e.g. `philhealth.yml`):**
```yaml
agency: philhealth
tables:
  - effective_date: "2026-01-01"
    source_circular: "PhilHealth Circular No. XXXX-2025"
    data:
      rate: "0.05"          # strings → parsed to BigDecimal
      floor: "10000"
      ceiling: "100000"
```

**Implementation Steps:**
1. `Table` value object with a `#fetch(key)` over `data` (raises on missing key → data bug).
2. `RateTables.load!` (called at boot from `config.ru`): glob YAML, parse, build `Table`s,
   run `TableSchema.validate!` on each (ticket 1.5), sort by effective_date, freeze.
3. `RateTables.for(agency, as_of:)`: filter by agency, select latest effective_date <= as_of,
   else raise `MissingRateTable` with a message listing available dates.
4. Memoize the loaded set in a class-level constant/ivar; reload only in tests.

**Edge Cases & Failure Modes:**
- `as_of` earlier than the earliest table (e.g. asking 2019 when data starts 2023) → raise
  `MissingRateTable` (don't back-extrapolate).
- Future `as_of` (2030) → returns the latest table only if its effective_date <= as_of;
  since latest is 2026-01-01 <= 2030, it WOULD return 2026 — correct behavior is to return
  the latest known and let the caller/LLM see the effective_date is old. NOTE: this is the
  one spot where "latest applicable" is right, not fail-loud — the rule is strictly
  "latest effective_date on or before as_of," and a far-future date legitimately resolves to
  the newest table. Document this distinction explicitly (it differs from the missing-YEAR
  case in D3, which is about a table that doesn't exist at all).
- Two tables with the same effective_date for one agency → raise at load (ambiguous data).
- Empty `config/contribution_tables/` → raise at boot (misconfiguration, fail loud).
- `as_of` passed as a String → parse to Date, raise `InvalidInput` on garbage.

**Data Integrity:** the YAML files ARE the source of truth; integrity is enforced by the
schema validator (1.5) + independently-sourced golden tests (M2). No DB, no multi-tenancy.

**Performance:** one-time boot parse of a few KB; `.for` is an in-memory filter+max over a
handful of entries. Zero per-request I/O.

**Test Plan:**
| Test File | Scenario | Type |
|---|---|---|
| `spec/payroll/rate_tables_spec.rb` | `.for` returns latest effective_date ≤ as_of | unit |
| " | mid-year change: as_of before change → old table; after → new table | unit |
| " | as_of before earliest table → raises MissingRateTable naming available dates | unit |
| " | far-future as_of → returns latest table (documented behavior) | unit |
| " | duplicate effective_date for one agency → raises at load | unit |
| " | empty tables dir → raises at boot | unit |
| " | String as_of parsed; garbage → InvalidInput | unit |

**What's Missing (checklist):**
- [ ] `MissingRateTable` message lists available effective dates (LLM-relayable)
- [ ] far-future-vs-missing distinction documented in code comment
- [ ] tables frozen after load (no mutation at runtime)

---

### Ticket 1.5 — YAML schema validator + CI gate

**Files to Change:**
| File | Change |
|---|---|
| `app/payroll/table_schema.rb` | new: validates one table's shape |
| `bin/validate_tables` | new: standalone CLI (exit non-zero on any invalid table) |
| `.github/workflows/ci.yml` | new: `bundle exec rspec` + `bin/validate_tables` |
| `spec/payroll/table_schema_spec.rb` | new |

**Architecture (D6):**
- `TableSchema.validate!(table)` asserts: `agency` present + in the known set; `effective_date`
  parses to a Date; `source_circular` present and non-blank; `data` has the required keys for
  that agency's shape; every rate value is a numeric string parseable to BigDecimal.
- Runs in TWO places: at boot (via `RateTables.load!`, so a bad table never serves traffic)
  AND as a standalone CI step (`bin/validate_tables`, so a bad data PR never merges). Same
  code, two entry points.

**Implementation Steps:**
1. `TableSchema.validate!(table)` → raises `TableSchema::Invalid` with a precise message
   (`"philhealth 2026-01-01: missing source_circular"`).
2. Per-agency required-key maps (sss/philhealth/pagibig/withholding_tax) — keep alongside
   the schema; M2 fills the exact keys as calculators are built.
3. `bin/validate_tables`: load all YAML, validate each, print a summary, `exit 1` on any failure.
4. `ci.yml`: matrix on the pinned Ruby; steps = checkout, bundle, `bin/validate_tables`, rspec.

**Edge Cases & Failure Modes:**
- Missing `effective_date`/`source_circular` → `Invalid` (this is THE guardrail for the
  citation contract at the data layer).
- Rate stored as a YAML number instead of a string → warn/raise (strings enforce BigDecimal path).
- Unknown agency key → `Invalid` (typo protection).
- Malformed YAML (parse error) → caught, reported with filename.

**Migration & Deployment:** CI gate added to the repo; no runtime migration. A failing
`bin/validate_tables` blocks merge — that is the intended behavior.

**Test Plan:**
| Test File | Scenario | Type |
|---|---|---|
| `spec/payroll/table_schema_spec.rb` | valid table passes | unit |
| " | missing source_circular → Invalid with clear message | unit |
| " | missing/garbage effective_date → Invalid | unit |
| " | unknown agency → Invalid | unit |
| " | rate not parseable to BigDecimal → Invalid | unit |
| " | malformed YAML file → reported with filename | unit |
| (CI) | `bin/validate_tables` exits non-zero on a fixture bad table | integration |

**What's Missing (checklist):**
- [ ] Same validator wired into BOTH boot and CI (no drift)
- [ ] Error messages name the file + agency + effective_date
- [ ] CI runs on the pinned Ruby version

---

## Rollback Plan
M1 is greenfield scaffolding — rollback is `git revert` of the M1 commits or deleting the
branch. Nothing is deployed to users yet (tools register in later milestones), and there is
no database or external state. The only external action in M1 is provisioning the Render
service; that can be torn down independently.

## Pre-Implementation Checklist
- [ ] `fast-mcp` version pinned; mount pattern verified against that version's README
- [ ] `Result` enforces the citation contract (raises on blank source_circular)
- [ ] `BaseCalculator` centralizes BigDecimal + HALF_UP rounding + validate/clamp
- [ ] `RateTables.for` selects by effective_date and fails loud on a truly-missing table
- [ ] far-future vs missing-table distinction documented
- [ ] `TableSchema` runs at boot AND in CI (one implementation)
- [ ] `GET /health` + empty `tools/list` verified via MCP Inspector
- [ ] All M1 specs green; `bin/validate_tables` green on seed data
