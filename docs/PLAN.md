# ph-payroll-mcp — Design Plan

**Project:** An MCP (Model Context Protocol) server that gives any MCP-compatible LLM (Claude, ChatGPT, Gemini, Copilot, Cursor, and others) accurate, current-year Philippine payroll compliance math — SSS, PhilHealth, Pag-IBIG, and BIR withholding tax — instead of guessing from stale training data.

**Owner:** Leo Magsino ([github.com/lmagsino](https://github.com/lmagsino) · [linkedin.com/in/leomagsinojr](https://linkedin.com/in/leomagsinojr))

**Stack:** Ruby on Rails (API-only) + `fast-mcp` gem, deployed on Render

---

## 1. Why this project

Philippine statutory contribution brackets (SSS, PhilHealth, Pag-IBIG) and BIR withholding tax rules change yearly via agency circulars. An LLM asked to compute a payslip either hallucinates a plausible-looking bracket or answers with an outdated rate, stated with full confidence — because it's working from memory, not a calculator. This server fixes that by giving any MCP-compatible LLM real compute tools with cited sources.

MCP is an open, vendor-neutral standard — not a Claude-specific feature. Anthropic open-sourced it in November 2024 and donated it to the Linux Foundation's Agentic AI Foundation in December 2025, with OpenAI and Block as co-founders and Google, Microsoft, AWS, and Cloudflare as supporting members. A single server built to spec works unmodified with Claude, ChatGPT, Gemini, Copilot, Cursor, and any other MCP client — this project is written as generic infrastructure, not a Claude integration.

Picked over five other MCP ideas (QR Ph decoder, bank statement reconciler, remittance comparator, PhilHealth case-rate lookup, compliance deadline tracker) because it's the only one with zero external dependencies: no third-party API, no scraping, no sample data to source, no auth. Pure public reference data + arithmetic.

---

## 2. What "MCP server" means here, in practice

MCP is a protocol, not a hosting model — think REST/GraphQL, not serverless. You write a normal Rails app with real methods (SSS bracket lookup, tax calc, etc). MCP's contribution is a contract layer on top: each function is described as a "tool" with a name, plain-English description, and a JSON schema for inputs/outputs. The host LLM (Claude, ChatGPT, Gemini, or any other MCP client) reads that tool list and decides, mid-conversation, when to call which tool and with what arguments — no human ever reads a Swagger doc. The `fast-mcp` gem handles the JSON-RPC plumbing (handshake, tool listing, request/response) so you only write tool classes with a `call` method.

Users connect it once — through whichever host's connector settings (e.g. claude.ai/Desktop/Cowork → Settings → Connectors, or ChatGPT's connector settings, or an MCP config file for Cursor/VS Code) — paste the server URL, and from then on just talk to their assistant normally; it calls the right tool automatically. Nothing in the server code is host-specific, so the same deployed URL serves all of them.

---

## 3. Tool definitions

### `compute_sss_contribution`
- **In:** `{ monthly_salary: number, member_type: "employed" | "self_employed" | "voluntary" | "ofw" }`
- **Out:** `{ msc, employee_share, employer_share, ec_contribution, total, effective_date, source }`
- Clamp salary to MSC floor/ceiling, round to bracket, apply 15% split per member type.

### `compute_philhealth_contribution`
- **In:** `{ monthly_salary: number }`
- **Out:** `{ premium, employee_share, employer_share, effective_date, source }`
- Clamp to ₱10,000–₱100,000, apply 5% (2.5/2.5 split).

### `compute_pagibig_contribution`
- **In:** `{ monthly_salary: number }`
- **Out:** `{ employee_share, employer_share, total, effective_date, source }`
- 1%/2% split under ₱1,500, else 2%/2%, capped at ₱200/₱200 on ₱10,000 ceiling.

### `compute_withholding_tax`
- **In:** `{ annual_taxable_income: number }` or `{ monthly_taxable_income: number }` (support both — monthly is the more common real call)
- **Out:** `{ annual_tax, monthly_tax, bracket, effective_date, source }`
- Bracket lookup per TRAIN Law Phase 2 table.

### `compute_13th_month_pay`
- **In:** `{ total_basic_salary_earned_this_year: number, months_worked: number }`
- **Out:** `{ thirteenth_month_pay, taxable_portion, tax_exempt_portion }`
- Total basic salary ÷ 12; apply the tax-exempt threshold (confirm current ₱90,000 figure against BIR before shipping).

### `compute_net_pay` — composite tool, calls the four above internally
Likely the most-used tool; polish first.
- **In:** `{ gross_monthly_salary: number, member_type: string, other_deductions: number (optional) }`
- **Out:** `{ gross, sss, philhealth, pagibig, withholding_tax, other_deductions, net_pay }`

### `get_contribution_table`
- **In:** `{ table: "sss" | "philhealth" | "pagibig" | "withholding_tax", year: number (optional) }`
- **Out:** raw bracket table + `effective_date` + `source_circular` — lets the LLM (or the user) cite the actual rule instead of trusting a black-box number.

---

## 4. Rate data (researched Jul 3, 2026 — verify against primary circulars before shipping)

Sources below are secondary (payroll/HR sites), not primary agency circulars. Confirm each against sss.gov.ph, philhealth.gov.ph, pagibigfund.gov.ph, bir.gov.ph and store the circular number as a citation field in seed data.

- **SSS (2026):** 15% of Monthly Salary Credit total — employer 10%, employee 5%, plus employer EC contribution (₱10 if MSC < ₱15,000, ₱30 if ≥ ₱15,000). MSC floor ₱5,000, ceiling ₱35,000. Self-employed/voluntary/OFW pay the full 15%; OFW minimum MSC ₱8,000.
- **PhilHealth (2026):** 5% of monthly basic income, 2.5%/2.5% split. Floor ₱10,000 (fixed ₱500/mo), ceiling ₱100,000 (fixed ₱5,000/mo). Final scheduled step under the UHC Law.
- **Pag-IBIG/HDMF (2026):** 2%/2% employee/employer (1%/2% if monthly comp ≤ ₱1,500). Ceiling ₱10,000 → max ₱200 employee + ₱200 employer. Unchanged since HDMF Circular No. 460 (Feb 2024).
- **BIR withholding tax (TRAIN Law, RA 10963, Phase 2, effective Jan 2023, unchanged into 2026), annual brackets:**

| Bracket | Tax |
|---|---|
| ₱0 – ₱250,000 | 0% |
| ₱250,001 – ₱400,000 | 15% of excess over ₱250,000 |
| ₱400,001 – ₱800,000 | ₱22,500 + 20% of excess over ₱400,000 |
| ₱800,001 – ₱2,000,000 | ₱102,500 + 25% of excess over ₱800,000 |
| ₱2,000,001 – ₱8,000,000 | ₱402,500 + 30% of excess over ₱2,000,000 |
| above ₱8,000,000 | ₱2,202,500 + 35% of excess over ₱8,000,000 (not fully confirmed — verify against BIR's own table) |

Store all four tables as versioned data (YAML/JSON with `effective_date` and `source_circular`), not hardcoded constants — next year's update should be a data PR, not a code change.

---

## 5. Technical setup

```
rails new ph-payroll-mcp --api --skip-active-storage --skip-action-mailer
```

**Gems:** `fast-mcp` (MCP server, mountable Rack endpoint), `rack-cors` (host infra — Claude, ChatGPT, etc. — calls cross-origin), `rspec-rails` + `factory_bot_rails` (test the bracket math thoroughly — wrong math is worse than no tool), `dotenv-rails`.

No database needed — contribution tables are static YAML files loaded into memory. Mount `fast-mcp`'s `StreamableHTTPTransport` at `/mcp` in `routes.rb`. Define tools in `app/mcp/tools/*.rb`, one class per tool.

**Auth:** none for v1 — stateless public-data compute tools, no reason to gate access. Skip OAuth entirely. Add `rack-attack` throttling later only if abuse becomes an issue.

**Local testing:** `npx @modelcontextprotocol/inspector` against `localhost:3000/mcp` before connecting any real client — Claude, ChatGPT, or otherwise.

**Deploy:** Render free tier to start (simplest, predictable; cold-start sleep on free tier is a minor demo annoyance, fine for portfolio use).

---

## 6. README template

```markdown
# ph-payroll-mcp

An MCP server that gives any MCP-compatible LLM accurate, current-year
Philippine statutory payroll math — SSS, PhilHealth, Pag-IBIG, and BIR
withholding tax — instead of guessing from stale training data.

## Why this exists
Philippine contribution brackets change yearly via agency circulars. LLMs
either hallucinate plausible-looking numbers or answer with last year's
rates, stated with total confidence. This server does the arithmetic
correctly and cites the source circular for every number.

MCP is an open standard, not a Claude-specific feature — this server works
with any MCP client: Claude, ChatGPT, Gemini, Copilot, Cursor, and more.

## Tools
| Tool | What it does |
|---|---|
| `compute_sss_contribution` | SSS contribution by MSC bracket and member type |
| `compute_philhealth_contribution` | PhilHealth premium (5% split, floor/ceiling) |
| `compute_pagibig_contribution` | Pag-IBIG (HDMF) contribution |
| `compute_withholding_tax` | BIR TRAIN Law withholding tax |
| `compute_13th_month_pay` | 13th month pay + tax-exempt portion |
| `compute_net_pay` | Full payslip: gross → net |
| `get_contribution_table` | Raw bracket table + effective date + source circular |

## Connect it to your AI assistant
URL: `https://ph-payroll-mcp.onrender.com/mcp` — no auth required.

- **Claude** (claude.ai / Desktop / Cowork): Settings → Connectors → Add custom connector → paste the URL
- **ChatGPT**: Settings → Connectors → Add MCP server → paste the URL
- **Cursor / VS Code / other IDEs**: add the URL to your MCP config file
- Any other MCP client: same URL, standard MCP handshake

## Run locally
\`\`\`
bundle install
rails server
npx @modelcontextprotocol/inspector
# point Inspector at http://localhost:3000/mcp
\`\`\`

## Data sources
Contribution tables sourced from SSS, PhilHealth, Pag-IBIG, and BIR
circulars — see `config/contribution_tables/` for exact citations and
effective dates.

## Stack
Ruby on Rails (API-only) + fast-mcp. Deployed on Render.

## Author
Leo Magsino — github.com/lmagsino · linkedin.com/in/leomagsinojr
```

---

## 7. Eng Review Decisions (2026-07-07, /plan-eng-review)

Locked decisions from architecture/code-quality/test/performance review + an independent
outside-voice challenge. These supersede conflicting details above.

**Stack change:** Sinatra/Rack (NOT Rails) + `fast-mcp` (mounts as a Rack endpoint).
Rails is too heavy for 7 stateless pure functions on a 512MB free tier. Drop the
keep-alive pinger (ban risk + doesn't fix boot time); document Render cold start
honestly in the README, or note the paid tier as the real fix.

**Architecture**
- **Domain layer + thin adapters (D1):** pure-Ruby calculators in `app/payroll/`
  (one per agency) do the math and load YAML; MCP tool classes in `app/mcp/tools/`
  are thin adapters (parse → validate → call calculator → format Result).
  `compute_net_pay` calls the four calculators directly, never the tool objects.
- **Money (D2):** BigDecimal everywhere; explicit per-agency rounding rules
  (SSS → MSC bracket lookup; PhilHealth/Pag-IBIG → round half-up to centavo).
  Store YAML rates as strings, parse to BigDecimal.
- **Missing data (D3 + D10):** key tables by **effective_date**, not year. Select the
  latest table whose effective_date ≤ the (optional) as-of date, default today. No
  matching table → **fail loud** with a clear error naming the latest available.
- **Input validation (D4):** JSON-schema (fast-mcp) rejects wrong types/missing fields;
  semantic validation rejects nonsense (salary < 0, non-finite, bad enum) with a clear
  error. Clamp ONLY the legal statutory floor/ceiling on a valid positive salary.
- **DRY (D5):** shared `Payroll::Result` value object (amounts + effective_date +
  source_circular) + `BaseCalculator` for clamp/round/validate/citation. Citation
  contract enforced in one place.

**Data correctness (from outside voice — these are the real work)**
- **Withholding (D8):** model BIR's period-based **Revised Withholding Tax Table**
  (v1: monthly column) with its own citation and a pay-period param — NOT the annual
  TRAIN brackets divided by 12.
- **SSS (D9):** model the **regular SS program + the WISP/MPF layer above MSC ₱20,000**
  separately, each with its rate + citation. Not a single flat split across ₱5k–₱35k.
- **Period semantics:** define `compute_net_pay` explicitly as one monthly payroll
  period (document the assumption).
- **Verification is critical path:** EVERY rate table must be verified against the
  primary agency circular before shipping — not just the ₱90k threshold and top BIR
  bracket. Store the circular number as a citation field.

**Data safety (D6):** YAML schema + load-time validator (fail fast on malformed /
missing effective_date / missing source_circular) AND a CI check so a bad data PR
never merges. Load tables once at boot into frozen structures (perf).

**Tests**
- **Depth (D7):** unit (all calculator branches + bracket boundaries) + adapter
  (schema rejection + citation presence on all 7 tools) + one E2E protocol round-trip
  (tools/list + compute_net_pay tools/call + /health).
- **Oracle (D11):** expected values are **independently sourced** — hand-computed from
  the circular and spot-checked against an established calculator (e.g. Sweldong Pinoy),
  NEVER derived from the YAML. Plus a few full golden-payslip fixtures.

**In scope (added):** a **disclaimer** on output/README — public authoritative
statutory output must not invite blind reliance (under-remittance risk).

**NOT in scope:** auth/OAuth; rate limiting (TODO); daily/weekly/semi-monthly RWT
columns (TODO); non-taxable allowances/de minimis modeling; historical-year backfill;
GSIS/government employees.

## 8. Deferred TODOs
- **Rate limiting (`rack-attack`):** unauthenticated public endpoint; add if abuse
  appears. Low blast radius on read-only math. Depends on: nothing.
- **RWT extra pay-period columns (daily/weekly/semi-monthly):** v1 ships monthly;
  semi-monthly is very common in PH payroll. Data + golden-value tests per period,
  not a redesign (calculator already takes a pay-period param). Depends on: D8 monthly landing first.