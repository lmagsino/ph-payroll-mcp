# Technical Plan: M3 — MCP Surface

**Implementation Plan:** docs/PLAN.md
**Milestone:** M3 — the 7 MCP tools + the composite + the table reader
**Depends on:** M1 (foundation) + M2 (5 calculators) — shipped.
**Date:** 2026-07-07
**Status:** Draft

## Overview
Expose the domain layer as MCP tools an LLM can call. Seven thin `FastMcp::Tool`
adapters in `app/mcp/tools/` parse args, invoke a domain calculator, and return the
`Result#to_h` (with its citation). Two new domain pieces back the composite tools:
`NetPayCalculator` (composes the four component calculators) and a small reader for
`get_contribution_table`. Tools are registered on the fast-mcp server in `config.ru`.

```
LLM → tools/call → app/mcp/tools/<tool>.rb (FastMcp::Tool)
        parse+schema (dry) → rescue Payroll::Error → domain calculator → to_h(+citation)
compute_net_pay → NetPayCalculator → SSS/PhilHealth/PagIBIG(EE) → taxable → Withholding → net
get_contribution_table → RateTables.for(agency, as_of:) → raw data + effective_date + source_circular
```

Adapters are thin by design (eng-review D1): no math in a tool, only translation.

---

### Ticket 3.1 — Tool adapter base + error mapping (DRY)

**Files:** `app/mcp/tools/base_tool.rb`, `spec/mcp/tools/base_tool_spec.rb`.

fast-mcp tools inherit `FastMcp::Tool`, declare `tool_name`, `description`, an
`arguments do … end` dry-schema block, and implement `call(**args)`. The base adds one
shared concern: map domain errors to a clean tool error the LLM relays, so no adapter
duplicates rescue logic (D5).

```ruby
class Tools::BaseTool < FastMcp::Tool
  private

  # Invoke a domain call, translating Payroll errors into a structured tool error.
  def domain
    yield
  rescue Payroll::InvalidInput => e
    { error: "invalid_input", message: e.message }
  rescue Payroll::RateTables::MissingRateTable => e
    { error: "no_rate_table", message: e.message }
  end
end
```

**VERIFY at implementation** (against fast-mcp 1.6.0, already vendored): the exact
`call` return contract (hash vs string vs content array) and how a raised error is
surfaced. Inspect `lib/mcp/tool.rb`; prefer returning the domain hash and let fast-mcp
serialize. If it needs a specific shape, wrap in the base.

**Tests:** error mapping returns the structured error for InvalidInput and
MissingRateTable; a successful yield passes the hash through untouched.

---

### Tickets 3.2–3.6 — The five single-calculator tools

One thin adapter each; identical shape. Files under `app/mcp/tools/`, specs under
`spec/mcp/tools/`.

| Tool (tool_name) | Calculator | Arguments (dry-schema) |
|---|---|---|
| `compute_sss_contribution` | SssCalculator | `monthly_salary:float`, `member_type:string(enum)` |
| `compute_philhealth_contribution` | PhilhealthCalculator | `monthly_salary:float` |
| `compute_pagibig_contribution` | PagibigCalculator | `monthly_salary:float` |
| `compute_withholding_tax` | WithholdingTaxCalculator | `monthly_taxable_income:float`, optional `pay_period:string` |
| `compute_13th_month_pay` | ThirteenthMonthCalculator | `total_basic_salary_earned_this_year:float`, `months_worked:integer` |

**Pattern (example — PhilHealth):**
```ruby
class Tools::ComputePhilhealthContribution < Tools::BaseTool
  tool_name "compute_philhealth_contribution"
  description "Compute the PhilHealth monthly premium (employee + employer share) for a " \
              "monthly salary, with the source circular and effective date."
  arguments do
    required(:monthly_salary).filled(:float).description("Monthly basic salary in PHP")
  end

  def call(monthly_salary:)
    domain { Payroll::PhilhealthCalculator.new.call(monthly_salary: monthly_salary).to_h }
  end
end
```

**Schema notes:**
- Use `:float` for money (LLMs pass numbers); the domain coerces to BigDecimal and
  rejects non-finite. dry-schema handles type/required (D4 layer 1); the domain does
  semantic validation (D4 layer 2).
- `member_type` and `pay_period` get enum descriptions so the LLM picks valid values.
- Every `description` names what the tool returns AND that it cites a circular — that
  phrasing is what makes the LLM surface the citation to the user.

**Tests (per tool):** happy path returns amounts + `effective_date` + `source_circular`;
an invalid value returns the structured `invalid_input` error (not a raise); the
citation fields are always present (this is the adapter-level guard the unit tests can't
give — a dropped citation regression).

---

### Ticket 3.7 — NetPayCalculator (composite) + compute_net_pay tool

**Files:** `app/payroll/net_pay_calculator.rb`, `app/mcp/tools/compute_net_pay.rb`,
`spec/payroll/net_pay_calculator_spec.rb`, `spec/mcp/tools/compute_net_pay_spec.rb`.

The composite is domain logic (D1), not a tool. It calls the four component calculators
directly and derives the taxable income correctly — the one real piece of composite math:

```
sss_ee        = SssCalculator (employee_share, by member_type)
philhealth_ee = PhilhealthCalculator (employee_share)
pagibig_ee    = PagibigCalculator (employee_share)
taxable       = gross - (sss_ee + philhealth_ee + pagibig_ee)   # mandatory contribs are pre-tax
withholding   = WithholdingTaxCalculator (monthly_taxable_income: taxable)
net_pay       = gross - sss_ee - philhealth_ee - pagibig_ee - withholding - other_deductions
```

**Inputs:** `gross_monthly_salary`, `member_type`, optional `other_deductions` (default 0).

**Citation for a composite:** net_pay draws on FOUR tables, each with its own
effective_date + source_circular. It does NOT collapse into a single `Result`. Instead it
returns a structure that keeps every number auditable:
```
{
  gross:, sss_employee:, philhealth_employee:, pagibig_employee:,
  taxable_income:, withholding_tax:, other_deductions:,
  total_deductions:, net_pay:,
  sources: {
    sss:            { effective_date:, source_circular: },
    philhealth:     { effective_date:, source_circular: },
    pagibig:        { effective_date:, source_circular: },
    withholding_tax:{ effective_date:, source_circular: }
  }
}
```
So the composite honors the auditability thesis: every deduction traces to its circular.

**Edge Cases:** taxable income going negative if contributions exceed gross (shouldn't
happen with clamping, but guard → floor at 0 for the withholding lookup); other_deductions
larger than gross → net can be negative, report it honestly (don't clamp net to 0 — a
negative net is real information); member_type propagates to SSS; invalid inputs bubble
the component's InvalidInput.

**Tests (golden, hand-computed):** a full worked payslip (e.g. gross 30,000 employed →
each EE share, taxable, withholding, net) reconciled by hand; other_deductions present vs
absent; a component failure (bad member_type) surfaces which component; net can be
negative with large other_deductions.

---

### Ticket 3.8 — get_contribution_table tool

**Files:** `app/mcp/tools/get_contribution_table.rb`, spec.

Thin read over `RateTables`. Lets the LLM (or user) cite the actual rule rather than
trust a black-box number — the transparency tool.

**Arguments:** `table:string` (enum: sss|philhealth|pagibig|withholding_tax|thirteenth_month),
optional `as_of:string` (ISO date; default today).

**Behavior:** `RateTables.for(table, as_of:)` → return `{ agency:, effective_date:,
source_circular:, data: table.data }`. Missing table → the structured `no_rate_table`
error (fail loud, D3). Reuses the effective-date selection from M1 — no new logic.

**Tests:** returns the data + citation for each agency; unknown/blank `as_of` handling;
a date before any table → `no_rate_table` error.

---

### Registration (config.ru)

In the existing `FastMcp.rack_middleware` block, register all seven:
```ruby
require_relative "app/mcp/tools"   # loads BaseTool + all seven
end do |server|
  server.register_tool(Tools::ComputeSssContribution)
  server.register_tool(Tools::ComputePhilhealthContribution)
  # … all 7
end
```
Add `app/mcp/tools.rb` as the loader (mirrors `app/payroll.rb`). After this, `tools/list`
returns 7 tools instead of []. The M1 mount test still passes (it asserts the route, not
the count); update it to expect 7 tools, or leave that assertion to the M4 E2E test.

---

## Rollback Plan
Each tool is one file + its registration line + its spec. Revert a tool by removing its
`register_tool` line (server still boots with the rest). NetPayCalculator revert also
removes its tool. No runtime state.

## Pre-Implementation Checklist
- [ ] VERIFY fast-mcp 1.6.0 `call` return contract + error surfacing (read lib/mcp/tool.rb)
- [ ] All 7 tools registered; tools/list returns 7
- [ ] Every tool response carries effective_date + source_circular (adapter test asserts it)
- [ ] Invalid input returns a structured error, never an unhandled raise
- [ ] NetPayCalculator derives taxable income (pre-tax contributions) and keeps per-source citations
- [ ] compute_net_pay reconciles: net == gross − each EE deduction − withholding − other
- [ ] E2E protocol round-trip deferred to M4
```
