# Maintaining ph-payroll-mcp

The promise of this project is that the rates are current and every one is cited. This
page is the routine that keeps that promise; [VERIFICATION.md](VERIFICATION.md) holds the
evidence.

## Two artifacts, two versions

| Artifact | Lives in | Version | Tag | Ships when |
|---|---|---|---|---|
| `ph_payroll` gem | `gem/` | `gem/lib/ph_payroll/version.rb` | `ph_payroll/v<version>` | a rate, a calculator, or the gem API changes |
| MCP server | repo root | `VERSION` | `v<version>` | a tool, the transport, or the server changes |

A rate change is a **gem patch release** (0.1.0 → 0.1.1). The server picks it up through
`path: "gem"` on the next deploy and needs no release of its own unless a tool changes.

## When a rate changes

1. Research and record it: [VERIFICATION.md → How to re-verify next year](VERIFICATION.md#how-to-re-verify-next-year).
   That covers the new table entry, the hand-derived spec values, the VERIFICATION rows
   and the regenerated `examples/`.
2. `gem/CHANGELOG.md`: a new version section with a **Rates** entry naming the circular
   and its effective date. This is the public record that the tables are maintained, so
   every table change gets one, even a citation-only correction.
3. `CHANGELOG.md` (server): the same Rates line under Unreleased.
4. Bump `PhPayroll::VERSION`, run both suites and `bin/validate_tables`, commit, push.
5. Tag and push: `git tag -a ph_payroll/v0.1.1 -m "ph_payroll 0.1.1" && git push origin ph_payroll/v0.1.1`.
   The `Release ph_payroll` workflow checks the tag against the version, runs the gem
   suite, and publishes.

## Yearly cadence

A scheduled workflow (`.github/workflows/rate-check.yml`) opens two issues a year.

- **"Re-verify <year> rates"**, every 2 January, with this checklist. Work it even when
  nothing changed: re-confirm each table, update the check dates in VERIFICATION.md, and
  say so in the gem CHANGELOG ("Rates: re-verified for 2027, no change"). An unchanged
  year still leaves a dated trace.
- **"Load the <next year> holiday calendar"**, every 1 October, by which time the coming
  year's proclamation is usually out. Until that table is loaded, dates in the new year
  are refused, not priced as ordinary days. Eid'l Fitr and Eid'l Adha are proclaimed
  separately during the year, so the issue stays open until both are added.

## First gem release (one-time, needs the maintainer's rubygems.org account)

1. rubygems.org → Profile → Trusted Publishers → add a **pending** trusted publisher:
   gem `ph_payroll`, repository `lmagsino/ph-payroll-mcp`, workflow `release-gem.yml`,
   environment `rubygems`.
2. Optional: GitHub → Settings → Environments → `rubygems` → require a reviewer, so a
   tag alone cannot publish.
3. Push `ph_payroll/v0.1.0`. The workflow publishes; the pending publisher becomes a
   normal one bound to the gem.

No API key is stored anywhere; publishing is authorized per run over OIDC.
