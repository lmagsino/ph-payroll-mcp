# Changelog

All notable changes to the `ph_payroll` gem. Format follows
[Keep a Changelog](https://keepachangelog.com/); versions follow [SemVer](https://semver.org/).
Releases that change a rate table list it under **Rates**, with the circular and the
effective date.

## [Unreleased]

### Added
- `PremiumPayCalculator`: a day's pay by day type (ordinary, special working, special
  non-working and its double, regular holiday, double holiday), on or off the rest day,
  worked or not, with overtime and night-shift hours. Overtime and the night differential
  compound on the day's rate. Takes a `date` or a `day_type`.
- `HolidayCalendar.day(date)` and `.year(year)`: day type, holiday names and
  proclamations from the nationwide calendar; a year without a calendar raises
  `MissingRateTable` instead of reusing the latest year.

### Rates
- Premium pay: DOLE Handbook on Workers' Statutory Monetary Benefits, 2024 Edition
  (Labor Code Arts. 86, 87, 93, 94), effective 2026-01-01. Three values are inferred; see
  VERIFICATION.md.
- Holidays 2026: Proclamation No. 1006, s. 2025, with Nos. 1189 and 1264, s. 2026.

## [0.1.0] - 2026-10-14

### Added
- Calculators for SSS (all four member types, with the MPF layer and EC), PhilHealth,
  Pag-IBIG, BIR monthly withholding tax, 13th-month pay, and a net-pay composite.
- Versioned rate tables effective 2026-01-01, schema-checked on load, each cited.

### Rates
- SSS: Circular No. 2024-006 (with 2024-008/-009/-010), effective January 2025.
- PhilHealth: Circular No. 2020-0005 (Revision 1), per Advisories 2025-0002 and 2026-0042.
- Pag-IBIG: HDMF Circular No. 460, effective February 2024 (secondary sources).
- BIR: RR 11-2018 Annex E (withholding, 2023 onward) and Sec. 6 (₱90,000 13th-month ceiling).
