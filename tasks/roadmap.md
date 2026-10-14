# Roadmap: after v0.1.0

**Date:** 2026-10-14
**Status:** Approved 2026-10-14 — all five open questions settled (see Decisions).
**Goal:** make ph-payroll-mcp the Philippine payroll reference: the computations people
actually get wrong (holiday and premium pay, final pay), a calculator core usable outside
MCP, listings where MCP users look, and a visible record that the rates stay current.

## What already exists

- 13th-month pay ships in v0.1.0 (`compute_13th_month_pay`, RR 11-2018 ₱90,000 ceiling).
  Final pay (R3) reuses it for the prorated 13th month; nothing new to build for it alone.
- Every rate lives in a versioned YAML table with a citation, checked at boot and in CI,
  and recorded in `docs/VERIFICATION.md`. New rule sets follow the same pattern.

## Architecture decisions

- **Gem first, then features.** Extract `app/payroll/` + `config/contribution_tables/`
  into a `ph_payroll` gem (name is free on rubygems.org as of 2026-10-14) *before* adding
  calculators, so holiday and final pay are born in the gem instead of moving twice. The
  MCP server becomes a thin consumer of the gem.
- **Same repo, `gem/` is the gem root:** one CI and one VERIFICATION.md; the server's
  Gemfile points at it with `path:`. The gem keeps its own version and CHANGELOG
  (starting at 0.1.0, tagged `ph_payroll/v*`), so a rate update ships as a gem patch
  release without a server release.
- **Rules are data, like rates.** Premium-pay multipliers and the holiday calendar are
  YAML tables with `effective_date` + `source_circular`, validated by the same schema
  machinery. A new year's holiday proclamation is a data PR.
- **Compute what the law fixes; flag what depends on facts the tool cannot see.** E.g.
  holiday-pay eligibility (present the day before), exempt establishments, and the tax
  on final pay depend on the employee's records — the tool takes them as inputs or
  states them as assumptions in the result, never guesses.
- **Small commits straight to `main`,** each one green (specs, `bin/validate_tables`,
  `bin/smoke`) before it is pushed; CI runs on every push.

## Phases

### R1: `ph_payroll` gem extraction (server v0.2.0, gem v0.1.0)

- [ ] T1: Scaffold the gem in `gem/` (gemspec, `lib/ph_payroll.rb`, version, README stub)
- [ ] T2: Rename `Payroll::` → `PhPayroll::`, then move `app/payroll/*` →
      `gem/lib/ph_payroll/` (no alias: the server is the only consumer)
- [ ] T3: Move the rate tables + `TableSchema` into the gem; table path resolves inside the gem
- [ ] T4: Move the domain specs into `gem/spec`; CI runs both suites
- [ ] T5: Server depends on the gem via `path:`; tools require `ph_payroll`
- [ ] T6: Gem README with plain-Ruby usage; `gem build` passes; release workflow on tag
      (publish needs Leo's rubygems.org account + MFA — he runs the first push)

**Acceptance:** `gem install ph_payroll` (local `.gem`) and
`PhPayroll::NetPayCalculator.new.call(gross_monthly_salary: 30_000, member_type: "employed")`
returns net ₱26,542.45 with four citations; server specs, smoke, and examples unchanged.

### R2: Holiday and premium pay

The rule people get wrong: regular holiday vs special non-working day, and how a rest
day, overtime and night work stack on top.

- [ ] T7: Research + VERIFICATION rows: Labor Code Arts. 86 (night differential), 87
      (overtime), 93 (rest day / special day), 94 (regular holiday); DOLE Handbook on
      Workers' Statutory Monetary Benefits; the current DOLE holiday-pay advisory; the
      2026 holiday proclamation. Primary sources only, or flagged.
- [ ] T8: `premium_pay.yml`: multipliers per day type (ordinary, rest day, special
      non-working, special on rest day, regular holiday, regular on rest day, double
      holiday, double on rest day), the overtime premium on each, night differential,
      and the unworked-day rule for each type
- [ ] T9: `holidays/2026.yml`: dated calendar from the proclamation, each date typed
      (regular / special non-working / special working), cited
- [ ] T10: `PremiumPayCalculator`: inputs daily rate, day type *or* date (looked up in
      the calendar), rest-day flag, worked?, hours, overtime hours, night hours →
      itemized pay + multiplier used + citation. Golden values hand-derived from the
      DOLE handbook's worked examples, never from the YAML
- [ ] T11: MCP tools `compute_holiday_pay` and `list_holidays(year)`; examples captured
- [ ] T12: README tools table, CHANGELOG, VERIFICATION.md

**Acceptance:** each of the eight day types, worked and unworked, with and without
overtime and night hours, matches a hand derivation in the spec; an unknown 2027 date
returns `no_rate_table`, not a guess.

### R3: Final pay / back pay

- [ ] T13: Research + VERIFICATION rows: DOLE Labor Advisory No. 06-2020 (components,
      30-day release), Labor Code Art. 95 (service incentive leave), Arts. 298–299
      (separation pay for authorized causes: one month vs half a month per year, fraction
      of six months or more counts as a year), PD 851 (13th month for separated
      employees), tax exemption of separation pay for causes beyond the employee's control
- [ ] T14: `FinalPayCalculator`: unpaid salary, prorated 13th month (reuses
      `ThirteenthMonthCalculator`), cash conversion of unused leave, separation pay by
      cause → itemized gross with each line's taxability flagged and cited
- [ ] T15: MCP tool `compute_final_pay`; payslip-style example; docs

**Scope fence:** gross components and taxability flags only. The annualized final
withholding tax needs year-to-date payroll the tool does not have.

### R4: Discoverability (ops, mostly Leo's accounts)

- [ ] T16: Render free tier live (v0.1.0 post-release checklist items 2–3)
- [ ] T17: Official MCP registry: publish `server.json` with the Render remote (the
      registry's package types are npm / pypi / oci / nuget / mcpb, not rubygems; an OCI
      image was considered and declined)
- [ ] T18: mcp.so, Glama (claim the auto-indexed entry), Smithery, and a PR to
      awesome-mcp-servers
- [ ] T19: Demo gif (v0.1.0 checklist item 1) — listings convert better with it

### R5: Visible maintenance (ships alongside R1)

- [ ] T20: `docs/MAINTAINING.md`: the rate-update runbook (data PR → VERIFICATION row →
      `bin/capture_examples` → CHANGELOG `### Rates` entry → gem patch release)
- [ ] T21: CHANGELOG convention: a `### Rates` section in every release that touches a
      table, naming the circular and the effective date
- [ ] T22: Scheduled workflow that opens a "Re-verify <year> rates" issue each January
      and a "Load <year> holiday proclamation" issue each November, with the runbook
      checklist in the body

## Order and dependencies

```
R1 gem ──▶ R2 premium pay ──▶ R3 final pay
  │
  └─ R5 maintenance (same PR series as R1)
R4 discoverability: independent; T16 (Render) unblocks T17
```

## Decisions (2026-10-14)

1. **Order:** gem first. R1 extracts `ph_payroll`; R2 and R3 are built inside it.
2. **Gem location:** `gem/` subdirectory of this repo; the server uses it via `path:`.
3. **Final-pay tax:** gross components + taxability flags, no annualized tax.
4. **Registry:** wait for Render and list the remote; no OCI image.
5. **Premium-pay input:** daily rate only; no monthly conversion factor is defaulted.
