# Project status

**As of:** 2026-10-14 · `main` at `98099c6`, CI green (server 32 specs; gem 137 specs on
Ruby 3.2, 3.3, 3.4) · Released: `v0.1.0` (server). The `ph_payroll` gem is not yet
published.

Plans this page summarises: [`plan.md`](plan.md) (v0.1.0, shipped) and
[`roadmap.md`](roadmap.md) (everything after it).

## Done

| Phase | What shipped | Where |
|---|---|---|
| M5 | Official MCP Ruby SDK, Streamable HTTP at `POST /mcp` (stateless, JSON responses); typed tool schemas; fast-mcp removed | PR #1, merged |
| M6 | Every rate cited to its circular, `docs/VERIFICATION.md`; SSS self-employed EC fixed (₱3,780 at MSC ₱25,000) | PR #2, merged |
| M7 | `examples/` + `bin/capture_examples`, Claude Code session transcript, local-first README, `v0.1.0` tag and GitHub release | `main` |
| R1 | Calculators + rate tables extracted into the `ph_payroll` gem (`gem/`), `PhPayroll::` module, gem CI on 3 Rubies, release workflow on `ph_payroll/v*` tags | `main` |
| R5 | `docs/MAINTAINING.md`; CHANGELOG **Rates** convention; scheduled issues: "Re-verify <year> rates" (2 Jan) and "Load the <next year> holiday calendar" (1 Oct) | `main` |
| R2 | Holiday and premium pay: `premium_pay.yml` (DOLE Handbook 2024), 2026 `holidays.yml` (Proclamations 1006, 1189, 1264), `PremiumPayCalculator`, `HolidayCalendar`, MCP tools `compute_holiday_pay` and `list_holidays` | `main` |

The server now exposes nine tools: `compute_sss_contribution`,
`compute_philhealth_contribution`, `compute_pagibig_contribution`,
`compute_withholding_tax`, `compute_13th_month_pay`, `compute_net_pay`,
`get_contribution_table`, `compute_holiday_pay`, `list_holidays`.

## In progress

- **R3, final pay.** Research running into `tmp/r3-research.md` (git-ignored): DOLE Labor
  Advisory 06-2020, prorated 13th month (PD 851), service incentive leave cash
  conversion (Art. 95), separation pay by cause (Arts. 298–299), BIR taxability. No code
  yet. Design agreed in the roadmap: gross components with taxability flags, no
  annualized final tax; daily rate is an input, no days-per-year factor defaulted.
- **2027 holiday calendar.** Proclamation No. 1427, s. 2026 (8 Sep 2026) is out; the same
  research run collects it. Adding it is a data-only change to `holidays.yml`.

## Pending — needs Leo (accounts or keyboard)

1. **Regenerate `examples/`**: `bin/capture_examples`. The two R2 tools have no captured
   example yet. Local runs were paused for endpoint-security reasons; this runs the app
   in-process from the repo.
2. **Run `bin/smoke`** once, from the repo, to confirm nine tools over a booted Puma.
3. **Publish the gem**: add a pending trusted publisher on rubygems.org (gem `ph_payroll`,
   workflow `release-gem.yml`, environment `rubygems`), bump `PhPayroll::VERSION`
   (R2 added features, so 0.2.0 rather than 0.1.0 is the honest first number), tag
   `ph_payroll/v<version>`. Steps: `docs/MAINTAINING.md`.
4. **Server release v0.2.0** when ready: move CHANGELOG Unreleased to a dated section,
   bump `VERSION`, tag `v0.2.0`.
5. **Demo gif** at `docs/demo.gif` (the README already references it).
6. **Render free tier**: connect the repo, confirm `/health`, then add
   `https://ph-payroll-mcp.onrender.com/mcp` as a claude.ai connector.
7. **Registry listings** once Render answers: official MCP registry (`server.json`),
   mcp.so, Glama, Smithery, awesome-mcp-servers (roadmap R4).
8. **Inspector web form check**: confirm money fields render as numeric inputs (only the
   CLI schema output was verified).
9. `ANTHROPIC_API_KEY` in the shell profile is rejected by the API ("Invalid API key").

## Pending — development

- R3 final pay: `final_pay.yml`, `FinalPayCalculator`, MCP tool `compute_final_pay`,
  VERIFICATION rows, docs (roadmap T13–T15).
- 2027 `holidays.yml` table; Eid'l Fitr / Eid'l Adha 2027 get added when proclaimed.
- Later, not planned yet: semi-monthly/weekly withholding periods, other final-pay
  extras (retirement pay under RA 7641 is out of scope for R3).

## Known caveats in the data

- **Pag-IBIG** rests on secondary sources (DBM Circular Letter 2024-2 quoting HDMF
  Circular 460); HDMF's own copy was unreachable.
- **PhilHealth 2026** rests on Advisory 2026-0042; Circular 2020-0005's table ends at 2025.
- **Premium pay**: three multipliers are inferred, not stated by the Handbook (unworked
  regular/double holiday on a rest day; special working day on a rest day). Marked
  "Inferred" in `VERIFICATION.md` and the YAML header.
- **DOLE 2026 labor advisories** were seen only through news and payroll-firm reports
  (DOLE sites block automated reads). They restate the Handbook multipliers.
- **Holiday calendar is nationwide only**; regional days (e.g. NCR 16–18 Nov 2026,
  Proclamation No. 1447) are not loaded.
- **13th-month ₱90,000 ceiling** is shared with other benefits; the tool applies all of it
  to the 13th-month pay.

## Working rules for this repo

- Small commits straight to `main`; push only when asked; CI runs on every push.
- Use the personal GitHub account without switching the global one:
  `GH_TOKEN=$(gh auth token --user lmagsino) gh ...`.
- Endpoint security (CrowdStrike): run the app only from this checkout (`bundle exec`,
  `bin/*`), never as a program in `/tmp`; scratch files go in the git-ignored `tmp/`, not
  `/tmp`; no background servers started from an assistant session.
- Every figure needs a citation and a VERIFICATION row; secondary or inferred values are
  labelled as such, never upgraded.

## Resume checklist

1. Read this page and the open items in `roadmap.md`.
2. If `tmp/r3-research.md` exists, R3 can start from it; otherwise rerun that research.
3. `git log --oneline -15` to see the latest commits.
