# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/); this project uses [SemVer](https://semver.org/).

## [Unreleased]

### Added
- **MCP server** exposing seven tools over the HTTP+SSE transport (protocol 2024-11-05,
  via `fast-mcp`): `compute_sss_contribution`, `compute_philhealth_contribution`,
  `compute_pagibig_contribution`, `compute_withholding_tax`, `compute_13th_month_pay`,
  `compute_net_pay`, and `get_contribution_table`.
- Pure-Ruby domain layer: five agency calculators + a net-pay composite, all BigDecimal
  math with per-agency rounding, returning results cited to their source circular.
- Versioned rate tables (`config/contribution_tables/*.yml`) selected by effective date;
  schema-validated at boot and in CI (`bin/validate_tables`).
- `bin/smoke` end-to-end check (SSE handshake + tools/list + compute_net_pay).
- Sinatra/Rack app with `/health`; Render deploy config; GitHub Actions CI.

### Known limitations
- **Rate data is BEST-EFFORT and flagged `CONFIRM`.** Every SSS/PhilHealth/Pag-IBIG/BIR
  value must be verified against the primary agency circular before production use.
- Transport is HTTP+SSE (2024-11-05), not Streamable HTTP (2025). Compatible with
  SSE-capable clients; a migration is tracked for broader/newer client support.
- Withholding tax supports the monthly pay period only; other periods are a data TODO.
