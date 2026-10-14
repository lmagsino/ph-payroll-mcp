# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/); this project uses [SemVer](https://semver.org/).

## [Unreleased]

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

### Changed
- Tool input schemas are hand-written JSON Schema: money fields are `type: number`,
  `member_type` / `pay_period` / `table` are enums, `as_of` is `format: date`, and unknown
  arguments are rejected.
- Domain errors (`invalid_input`, `no_rate_table`) are returned with `isError: true`.

### Removed
- `fast-mcp` and its HTTP+SSE endpoints (`GET /mcp/sse`, `POST /mcp/messages`), along
  with the Rack 3 response-header workaround they needed.

### Known limitations
- **Rate data is BEST-EFFORT and flagged `CONFIRM`.** Every SSS/PhilHealth/Pag-IBIG/BIR
  value must be verified against the primary agency circular before production use.
- Withholding tax supports the monthly pay period only; other periods are a data TODO.
