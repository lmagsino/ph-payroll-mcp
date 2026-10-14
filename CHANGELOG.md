# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/); this project uses [SemVer](https://semver.org/).

## [Unreleased]

### Changed
- The calculators and rate tables moved into the [`ph_payroll`](gem/) gem (`gem/`), which
  the server uses by path; the domain module is now `PhPayroll`. Tool behaviour and every
  figure are unchanged.

### Added
- `docs/MAINTAINING.md` (rate-update and release runbook), a gem release workflow on
  `ph_payroll/v*` tags, and a yearly "Re-verify <year> rates" issue.
- `compute_holiday_pay`: one day's pay for a daily-paid employee on an ordinary day, rest
  day, special non-working or working day, regular or double holiday, with overtime and
  night-shift hours. A date is typed by the official holiday calendar.
- `list_holidays`: a year's nationwide holidays with their proclamations.
- `get_contribution_table` serves the new `premium_pay` and `holidays` tables.

### Rates
- Premium pay: DOLE Handbook on Workers' Statutory Monetary Benefits, 2024 Edition
  (Labor Code Arts. 86, 87, 93, 94); three values inferred, marked in VERIFICATION.md.
- Holidays 2026: Proclamation No. 1006, s. 2025, with Nos. 1189 and 1264, s. 2026
  (Eid'l Fitr, Eid'l Adha). Nationwide days only.

## [0.1.0] - 2026-10-14

### Added
- **MCP server** exposing seven tools over Streamable HTTP at `POST /mcp` (official MCP
  Ruby SDK, stateless, JSON responses): `compute_sss_contribution`,
  `compute_philhealth_contribution`, `compute_pagibig_contribution`,
  `compute_withholding_tax`, `compute_13th_month_pay`, `compute_net_pay`, and
  `get_contribution_table`.
- Pure-Ruby domain layer: five agency calculators + a net-pay composite, all BigDecimal
  math with per-agency rounding, returning results cited to their source circular.
- Versioned rate tables (`config/contribution_tables/*.yml`) selected by effective date;
  schema-validated at boot and in CI (`bin/validate_tables`).
- `bin/smoke` end-to-end check (initialize + tools/list + compute_net_pay over `POST /mcp`).
- Sinatra/Rack app with `/health`; Render deploy config; GitHub Actions CI.
- `examples/`: a captured request and response for every tool, a rendered ₱30,000
  payslip, and a Claude Code session against a local server; `bin/capture_examples`
  regenerates the tool examples.
- `docs/VERIFICATION.md`: the source, circular number, check date and primary/secondary
  status of every rate value.

### Changed
- Tool input schemas are hand-written JSON Schema: money fields are `type: number`,
  `member_type` / `pay_period` / `table` are enums, `as_of` is `format: date`, and unknown
  arguments are rejected.
- Domain errors (`invalid_input`, `no_rate_table`) are returned with `isError: true`.
- Every rate table now cites its governing issuance: SSS Circular 2024-006 (with
  2024-008/-009/-010), PhilHealth Circular 2020-0005 (Rev. 1), HDMF Circular 460, and
  BIR RR 11-2018 (Annex E and Sec. 6). All values were checked on 2026-10-14 and none
  changed. Sources, and whether each one is primary or secondary, are in
  [docs/VERIFICATION.md](docs/VERIFICATION.md).

### Removed
- `fast-mcp` and its HTTP+SSE endpoints (`GET /mcp/sse`, `POST /mcp/messages`), along
  with the Rack 3 response-header workaround they needed.

### Fixed
- SSS self-employed members now pay the EC contribution (₱10 below MSC ₱15,000, ₱30
  from it) on top of the 15%, per Circular 2024-008. MSC ₱25,000 is ₱3,780, not ₱3,750.

### Known limitations
- **Rate data:** see [docs/VERIFICATION.md](docs/VERIFICATION.md) for the source of
  every figure. The Pag-IBIG figures rest on secondary sources (DBM Circular Letter
  2024-2 quoting HDMF Circular 460).
- The ₱90,000 13th-month exemption is shared with other benefits; the 13th-month tool
  applies all of it to the 13th-month pay.
- Withholding tax supports the monthly pay period only; other periods are a data TODO.

[Unreleased]: https://github.com/lmagsino/ph-payroll-mcp/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/lmagsino/ph-payroll-mcp/releases/tag/v0.1.0
