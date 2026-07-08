# Technical Plan: M2 — Domain Calculators

**Implementation Plan:** docs/PLAN.md
**Milestone:** M2 — the five agency calculators
**Depends on:** M1 (BaseCalculator, Result, RateTables, Table, TableSchema) — all shipped.
**Date:** 2026-07-07
**Status:** Draft

## Overview
Implement the five pure-Ruby calculators that do the statutory math, each a
`BaseCalculator` subclass in `app/payroll/`. They consume versioned YAML rate tables
and return `Result`s with citations. The composite `NetPayCalculator` and
`get_contribution_table` are M3 (they compose these). No MCP/tool code here.

**The critical-path work of this milestone is DATA, not code.** Every rate, bracket,
threshold, and effective_date must be verified against the PRIMARY agency circular and
the circular number recorded in `source_circular`. The seed tables from M1 are
`UNVERIFIED PLACEHOLDER`s — replacing them with verified numbers is the gating task, and
the golden-value tests (D11) must use expected values computed independently from the
circular, never read back from the YAML.

```
BaseCalculator#call(as_of:, **inputs)
  → RateTables.for(agency, as_of:)         # M1: effective-date select, fail loud
  → validate!(**inputs)                    # per-calculator: reject bad input (D4)
  → compute(table, **inputs)               # per-calculator: the statutory math (BigDecimal)
  → Result(amounts, effective_date, source_circular)   # M1: citation by construction
```

Per-calculator required-key validation is added to `TableSchema` in this milestone
(M1 left it generic): each ticket extends `TableSchema` with the keys its agency needs,
so a table missing a bracket fails at boot + CI.

---

### Ticket 2.1 — SssCalculator (regular SS + EC + WISP, member types)

The hardest calculator. SSS is a stepped **Monthly Salary Credit (MSC)** schedule, not a
linear rate, plus the **WISP/MPF** layer above MSC ₱20,000 (eng-review D9) and an
Employees' Compensation (EC) employer add-on.

**Files:**
| File | Change |
|---|---|
| `app/payroll/sss_calculator.rb` | new `BaseCalculator` subclass, `agency "sss"` |
| `config/contribution_tables/sss.yml` | replace placeholder with VERIFIED MSC schedule + WISP + EC |
| `app/payroll/table_schema.rb` | add per-agency required-key check for `sss` |
| `spec/payroll/sss_calculator_spec.rb` | new, golden values from the circular |

**Inputs:** `{ monthly_salary:, member_type: }` where member_type ∈
`employed | self_employed | voluntary | ofw`.

**Algorithm (verify each rule against the SSS circular before coding the numbers):**
1. Determine MSC: round `monthly_salary` to its MSC bracket per the schedule; clamp to
   floor (₱5,000; OFW floor ₱8,000) and ceiling (₱35,000).
2. Split MSC into regular-program MSC (≤ ₱20,000) and WISP MSC (the ₱20,001–₱35,000 portion).
3. Apply the total contribution rate. For `employed`: employer + employee shares per the
   schedule (2025-scheduled 15% total = ER 10% / EE 5% — VERIFY the 2026 figure). For
   `self_employed | voluntary | ofw`: member pays the full rate; no employer share.
4. WISP portion contributions computed on the WISP MSC and reported separately.
5. EC (employer only, `employed` only): ₱10 if MSC below the EC threshold, ₱30 at/above it — VERIFY.
6. Round every peso amount HALF_UP to centavo via `round_centavo`.

**YAML shape the calculator expects (fill with verified data):**
```yaml
agency: sss
tables:
  - effective_date: "2026-01-01"
    source_circular: "SSS Circular No. ____ (VERIFIED)"
    data:
      msc_floor: "5000"
      msc_ceiling: "35000"
      msc_step: "500"            # bracket width, or an explicit brackets: list if non-uniform
      ofw_msc_floor: "8000"
      wisp_threshold: "20000"
      rate_total: "0.15"         # VERIFY 2026
      rate_employer: "0.10"      # VERIFY
      rate_employee: "0.05"      # VERIFY
      ec_low: "10"
      ec_high: "30"
      ec_threshold: "15000"      # VERIFY exact boundary
```
If the MSC schedule is non-uniform at the edges, store an explicit `brackets:` list of
`{ msc, ... }` rows instead of a step; `TableSchema` validates whichever is present.

**Edge Cases & Failure Modes:**
- member_type not in the enum → `InvalidInput` (validate!).
- monthly_salary ≤ 0 / non-finite → `InvalidInput`.
- salary below floor → clamp to floor MSC; OFW uses the higher ₱8,000 floor.
- salary above ceiling → clamp to ceiling MSC (₱35,000).
- exactly at MSC bracket boundaries, exactly at ₱20,000 WISP threshold, exactly at EC threshold.
- self_employed/voluntary/ofw → employer_share must be 0 and member pays full.

**Test Plan (golden values hand-computed from the circular, per D11):**
| Scenario | Input | Expected (independently computed) |
|---|---|---|
| employed mid-range | 25,000 | regular + WISP split, ER/EE shares, EC — hand-verified |
| employed at floor | 3,000 | clamps to ₱5,000 MSC |
| employed at ceiling | 60,000 | clamps to ₱35,000 MSC, full WISP |
| WISP boundary | 20,000 | no WISP portion |
| WISP boundary +1 bracket | 20,500 | WISP portion begins |
| EC low vs high | around ec_threshold | ₱10 vs ₱30 |
| OFW min | 6,000 | clamps to ₱8,000 OFW floor |
| self_employed | 25,000 | employer_share == 0, member pays full |
| invalid | -1 / "x" / member_type "gsis" | InvalidInput |

**What's Missing (checklist):**
- [ ] VERIFY 2026 rate (15% vs higher), MSC schedule, WISP mechanics, EC threshold vs SSS circular
- [ ] Record the exact circular number in source_circular
- [ ] Golden values computed from the circular, NOT the YAML

---

### Ticket 2.2 — PhilhealthCalculator

Simplest: flat 5% of monthly basic within a floor/ceiling, split 50/50.

**Files:** `app/payroll/philhealth_calculator.rb`, verified `philhealth.yml`,
`table_schema.rb` (philhealth keys), `spec/payroll/philhealth_calculator_spec.rb`.

**Inputs:** `{ monthly_salary: }`.

**Algorithm:**
1. `base = clamp(monthly_salary, floor: 10_000, ceiling: 100_000)`.
2. `premium = round_centavo(base * rate)` (rate 5% — VERIFY 2026 UHC step).
3. `employee_share = employer_share = round_centavo(premium / 2)`.
   Guard: if the 50/50 split leaves a centavo remainder, assign it deterministically
   (e.g. employee gets the odd centavo) and document — premium must equal EE + ER exactly.

**Edge Cases:** below floor → fixed ₱500 premium; above ceiling → fixed ₱5,000; exactly
₱10,000 and ₱100,000; odd-centavo split reconciles to the premium; invalid input → InvalidInput.

**Test Plan (golden):** mid-range (e.g. 30,000 → 1,500 premium, 750/750); floor 8,000 →
500; ceiling 150,000 → 5,000; boundary 10,000 and 100,000; a salary whose premium is odd
in centavos → EE+ER == premium; negatives → InvalidInput.

**What's Missing:** [ ] VERIFY 5% is the 2026 rate and the floor/ceiling vs PhilHealth circular; [ ] odd-centavo rule documented + tested.

---

### Ticket 2.3 — PagibigCalculator

Split depends on a comp threshold; ceiling caps the contribution.

**Files:** `app/payroll/pagibig_calculator.rb`, verified `pagibig.yml`,
`table_schema.rb` (pagibig keys), `spec/payroll/pagibig_calculator_spec.rb`.

**Inputs:** `{ monthly_salary: }`.

**Algorithm:**
1. `base = clamp(monthly_salary, floor: 0, ceiling: 10_000)` (ceiling ₱10,000 per HDMF Circular 460 — VERIFY).
2. If `monthly_salary <= 1_500`: employee 1%, employer 2%. Else: employee 2%, employer 2%.
   (Threshold uses the ACTUAL comp, not the clamped base — VERIFY which value the rule keys on.)
3. `employee_share = round_centavo(base * ee_rate)`, `employer_share = round_centavo(base * er_rate)`,
   `total = employee_share + employer_share`. Max ₱200 EE / ₱200 ER at the ceiling.

**Edge Cases:** ≤ ₱1,500 (1%/2%); just over ₱1,500 (2%/2%); exactly ₱1,500; above ₱10,000
→ capped ₱200/₱200; exactly ₱10,000; invalid → InvalidInput.

**Test Plan (golden):** 1,200 → 1%/2%; 1,500 → boundary rule; 5,000 → 2%/2% (100/100);
50,000 → capped 200/200; negatives → InvalidInput.

**What's Missing:** [ ] VERIFY ceiling ₱10,000, the ₱1,500 threshold, and whether it keys on raw comp or clamped base.

---

### Ticket 2.4 — WithholdingTaxCalculator (period-based RWT, monthly)

Per eng-review D8: model BIR's **Revised Withholding Tax Table** (monthly column for
v1), NOT the annual TRAIN brackets. Its own citation, its own bracket rows.

**Files:** `app/payroll/withholding_tax_calculator.rb`, verified `withholding_tax.yml`
(monthly RWT brackets), `table_schema.rb` (withholding keys + bracket shape),
`spec/payroll/withholding_tax_calculator_spec.rb`.

**Inputs:** `{ monthly_taxable_income:, pay_period: "monthly" }` (pay_period fixed to
`monthly` for v1; the param exists so daily/weekly/semi-monthly are a data-only addition — TODO).

**Algorithm:**
1. Reject `pay_period` other than `monthly` (v1) with a clear InvalidInput naming the supported value.
2. Find the bracket where `over <= income` (highest such row).
3. `tax = round_centavo(base + (income - over) * rate)`.
4. 0% bracket returns 0.

**YAML shape:**
```yaml
agency: withholding_tax
tables:
  - effective_date: "2026-01-01"
    source_circular: "BIR RR __ Revised Withholding Tax Table, monthly (VERIFIED)"
    data:
      monthly:
        brackets:
          - { over: "0",     base: "0",       rate: "0"    }
          - { over: "20833", base: "0",       rate: "0.15" }
          # ... remaining monthly RWT rows — VERIFY against the BIR table
```
(Numbers above are illustrative of the SHAPE only — the real monthly RWT boundaries and
base amounts must be transcribed and verified from the BIR table.)

**Edge Cases:** income in the 0% band → 0; each bracket boundary + just-over; top bracket;
`pay_period` not monthly → InvalidInput; negative income → InvalidInput; income exactly on
a boundary (which bracket wins — document `over <=`).

**Test Plan (golden, from the BIR monthly RWT table):** one case per bracket + each
boundary + just-over; 0% case; top bracket; invalid pay_period; negative income.

**What's Missing:** [ ] TRANSCRIBE + VERIFY the monthly RWT rows from BIR (the real work);
[ ] boundary tie-break (`over <=`) documented; [ ] TableSchema validates bracket row shape.

---

### Ticket 2.5 — ThirteenthMonthCalculator

Annual, not per-period. Basic salary / 12, prorated, with the ₱90,000 tax-exempt cap.

**Files:** `app/payroll/thirteenth_month_calculator.rb`, a small `thirteenth_month.yml`
(holds the exempt threshold + citation), `table_schema.rb`, `spec/...`.

**Inputs:** `{ total_basic_salary_earned_this_year:, months_worked: }`.

**Algorithm:**
1. Validate months_worked in 1..12 (integer), total_basic > 0.
2. `thirteenth = round_centavo(total_basic / 12)` (proration is inherent — total_basic
   already reflects months worked; months_worked used for validation/context — VERIFY the
   intended proration semantics against BIR guidance).
3. `exempt = min(thirteenth, threshold)`; `taxable = thirteenth - exempt`. Threshold ₱90,000 — VERIFY.

**Store the ₱90,000 threshold as versioned data** with its own effective_date +
source_circular (it has changed historically), consistent with the effective-date design.

**Edge Cases:** below threshold → all exempt, taxable 0; above → excess taxable; exactly
₱90,000; months_worked out of 1..12 → InvalidInput; non-integer months → InvalidInput.

**Test Plan (golden):** annual basic 240,000 → 20,000 (all exempt); annual 1,300,000 →
~108,333 (18,333 taxable above 90k); exactly 1,080,000 → 90,000 (all exempt, boundary);
months_worked 0 / 13 / 6.5 → InvalidInput.

**What's Missing:** [ ] VERIFY the ₱90,000 threshold + proration semantics vs BIR;
[ ] threshold stored as versioned data with citation.

---

## TableSchema per-agency extension (spans all tickets)
M1 shipped a generic schema. In M2, extend `TableSchema.validate!` with a per-agency
required-key map so a table missing a rate/bracket/threshold fails at boot AND in CI:
```
REQUIRED = {
  "philhealth"      => %w[rate floor ceiling],
  "pagibig"         => %w[low_rate_ee rate_ee rate_er low_threshold ceiling],
  "sss"             => %w[msc_floor msc_ceiling wisp_threshold rate_total ec_low ec_high ec_threshold],
  "withholding_tax" => %w[monthly],   # + validate monthly.brackets row shape
  "thirteenth_month"=> %w[exempt_threshold],
}
```
Add `thirteenth_month` to `KNOWN_AGENCIES`. Each ticket adds its keys as it lands.

## Rollback Plan
Each calculator is an independent file + its YAML + its spec. Revert a single ticket
without touching the others (they only share BaseCalculator/RateTables from M1). No
deploy/runtime state.

## Pre-Implementation Checklist
- [ ] Every rate/bracket/threshold VERIFIED against the primary circular; circular number in source_circular
- [ ] Golden test values computed independently from the circular (never from the YAML)
- [ ] TableSchema per-agency keys enforced (boot + CI)
- [ ] BigDecimal + HALF_UP everywhere; EE+ER reconciles to the total/premium exactly
- [ ] Every calculator: invalid-input rejection tested; all bracket/threshold boundaries tested
- [ ] compute_net_pay + get_contribution_table deferred to M3 (compose these)
```
