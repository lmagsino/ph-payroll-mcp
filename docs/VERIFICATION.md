# Rate verification

Every value in `gem/data/contribution_tables/*.yml`, the figure it holds, and where that
figure was checked. All rows were checked on **2026-10-14** against the tables in force
for the `2026-01-01` effective date.

**Primary** means the issuing agency's own document, read directly. **Secondary** means
the figure reached us through someone else's restatement. That can be another
government body quoting the circular, or a private summary. A secondary row's
`source_circular` says "per secondary sources".

## SSS: `gem/data/contribution_tables/sss.yml`

Sources:

- **SSS Circular No. 2024-006**, *Schedule of SSS Contributions Effective January 2025*,
  for business employers and employees. Dated 19 Dec 2024.
  <https://www.sss.gov.ph/wp-content/uploads/2024/12/CI-2024-006-Publication.pdf>
- **SSS Circular No. 2024-008**, self-employed members:
  <https://www.sss.gov.ph/wp-content/uploads/2024/12/CI-2024-008-Publication.pdf>
- **SSS Circular No. 2024-009**, voluntary and non-working spouse members:
  <https://www.sss.gov.ph/wp-content/uploads/2024/12/CI-2024-009-Publication.pdf>
- **SSS Circular No. 2024-010**, land-based OFW members:
  <https://www.sss.gov.ph/wp-content/uploads/2024/12/CI-2024-010-Publication.pdf>
- Circular index: <https://www.sss.gov.ph/sss-circulars/>. No contribution-schedule
  circular was issued after 2024-010. The 2025 and 2026 circulars cover loans, pensions
  and collecting agents.

The PDFs are scans. The figures were read from the rendered pages, not from extracted
text.

| Key | Figure | Where in the source | Circular | Checked | Type |
|---|---|---|---|---|---|
| `rate_total` | 0.15 | §I.A.1 "contribution rate to 15%"; table totals | 2024-006 | 2026-10-14 | Primary |
| `rate_employer` | 0.10 | Table, Employer Regular SS (e.g. MSC 10,000 → 1,000.00) | 2024-006 | 2026-10-14 | Primary |
| `rate_employee` | 0.05 | Table, Employee Regular SS (e.g. MSC 10,000 → 500.00) | 2024-006 | 2026-10-14 | Primary |
| `msc_floor` | 5000 | §I.A.2; row "Below 5,250 → 5,000.00" | 2024-006 | 2026-10-14 | Primary |
| `msc_ceiling` | 35000 | §I.A.3; row "34,750 – Over → 35,000.00" | 2024-006 | 2026-10-14 | Primary |
| `msc_step` | 500 | Every row: compensation MSC−250 … MSC+249.99 → MSC, uniform ₱500 steps | 2024-006 | 2026-10-14 | Primary |
| `wisp_threshold` | 20000 | §II.B.2: MSC above ₱20,000 up to ₱35,000 goes to the MPF | 2024-006 | 2026-10-14 | Primary |
| `ofw_msc_floor` | 8000 | Row "Below 8,250 → 8,000.00" | 2024-010 | 2026-10-14 | Primary |
| `ec_low` | 10 | EC column, MSC 5,000 to 14,500 | 2024-006 | 2026-10-14 | Primary |
| `ec_high` | 30 | EC column, MSC 15,000 to 35,000 | 2024-006 | 2026-10-14 | Primary |
| `ec_threshold` | 15000 | First ₱30 row: compensation 14,750–15,249.99 → MSC 15,000 | 2024-006 | 2026-10-14 | Primary |

**EC threshold.** Secondary sources give either ₱14,500 or ₱15,000. The circular settles
it: EC is ₱30 from **MSC** ₱15,000, which starts at compensation ₱14,750. ₱14,500 is
the last MSC that still pays ₱10. The calculator compares the MSC, so `15000` is
correct.

**Golden values.** Every employed figure in `spec/payroll/sss_calculator_spec.rb` is also
a row of the 2024-006 table. MSC 25,000 gives ER 2,530.00, EE 1,250.00, total 3,780.00.
MSC 35,000 gives a total of 5,280.00. MSC 14,000 gives ER 1,410.00. The OFW figure (MSC
8,000 → 1,200.00) is a row of 2024-010.

**Self-employed EC.** Circular 2024-008's table charges self-employed members EC too:
₱10 below MSC 15,000 and ₱30 from it, paid by the member on top of the 15%. At MSC
25,000 that is 3,000 + 750 MPF + 30 EC = **₱3,780**, which the calculator returns.
Voluntary members (2024-009) and OFW members (2024-010) pay no EC.

## PhilHealth: `gem/data/contribution_tables/philhealth.yml`

Sources:

- **PhilHealth Circular No. 2020-0005**, *Premium Contribution Schedule in the NHIP
  Pursuant to R.A. No. 11223 (Revision 1)*:
  <https://www.philhealth.gov.ph/circulars/2020/circ2020-0005.pdf>
- **PhilHealth Advisory No. 2025-0002**, *Premium Contribution for All Direct
  Contributors for CY 2025*:
  <https://www.philhealth.gov.ph/advisories/2025/PA2025-0002.pdf>
- **PhilHealth Advisory No. 2026-0042**, signed 21 Jul 2026:
  <https://www.philhealth.gov.ph/advisories/2026/PA2026-0042.pdf>

| Key | Figure | Where in the source | Circular | Checked | Type |
|---|---|---|---|---|---|
| `rate` | 0.05 | §V.A table, "2024 to 2025: 5.00%"; PA 2025-0002; PA 2026-0042 ("5.0% … effective January 2025") | 2020-0005 (Rev. 1) | 2026-10-14 | Primary |
| `floor` | 10000 | §V.A table "₱10,000.00 → ₱500.00"; §V.C | 2020-0005 (Rev. 1) | 2026-10-14 | Primary |
| `ceiling` | 100000 | §V.A table "₱100,000.00 → ₱5,000.00"; §V.C | 2020-0005 (Rev. 1) | 2026-10-14 | Primary |

The 50/50 split is in §V.B ("equally shared between the employee and employer"). The
circular sets no centavo rule. The calculator gives the odd centavo to the employer,
and that is this project's own convention.

The circular's table ends at "2024 to 2025", and PhilHealth has issued no CY 2026
schedule. The 2026 rate rests on Advisory 2026-0042, which still applies 5%.

## Pag-IBIG (HDMF): `gem/data/contribution_tables/pagibig.yml`

Sources:

- **HDMF Circular No. 460**, *Guidelines on the Pag-IBIG Fund's Implementation of
  Increase in the Maximum Fund Salary (MFS) Effective February 2024*, dated 15 Jan 2024.
  HDMF's own copy **could not be reached** on pagibigfund.gov.ph.
- **DBM Circular Letter No. 2024-2**, dated 1 Feb 2024. It quotes Circular 460 §C and
  the MFS increase. It is an official government issuance, but it is a restatement, so
  this table counts it as secondary.
  <https://www.dbm.gov.ph/wp-content/uploads/Issuances/2024/Circular-Letter/CIRCULAR-LETTER-NO-2024-2-DATED-FEBRUARY-01-2024.pdf>
- Forvis Mazars, *PAG-IBIG increases the Maximum Fund Salary* (secondary,
  corroborating):
  <https://www.forvismazars.com/ph/en/insights/hr-payroll-alerts/pag-ibig-circular-460>

| Key | Figure | Where in the source | Circular | Checked | Type |
|---|---|---|---|---|---|
| `low_rate_ee` | 0.01 | DBM CL 2024-2 ¶2.0 quoting Circ. 460 §C: "₱1,500 and below — Employee 1.0%" | HDMF 460 | 2026-10-14 | Secondary (DBM; Forvis Mazars) |
| `rate_ee` | 0.02 | Same table: "Over ₱1,500 — Employee 2.0%" | HDMF 460 | 2026-10-14 | Secondary (DBM; Forvis Mazars) |
| `rate_er` | 0.02 | Same table: "Employer 2.0%" in both rows | HDMF 460 | 2026-10-14 | Secondary (DBM; Forvis Mazars) |
| `low_threshold` | 1500 | Same table: "₱1,500 and below" | HDMF 460 | 2026-10-14 | Secondary (DBM; Forvis Mazars) |
| `ceiling` | 10000 | DBM CL 2024-2 ¶2.0: MFS "increased from ₱5,000 to ₱10,000 per month" | HDMF 460 | 2026-10-14 | Secondary (DBM; Forvis Mazars) |

No later HDMF circular changing the MFS or the rates was found. Current guides
still cite Circular 460.

## BIR withholding tax: `gem/data/contribution_tables/withholding_tax.yml`

Sources:

- **Revenue Regulations No. 11-2018, Annex "E"**, *Revised Withholding Tax Table,
  effective January 1, 2023 and onwards*:
  <https://bir-cdn.bir.gov.ph/local/pdf/Annex%20E%20RR%2011-2018.pdf>
- **RR No. 11-2018**, full text. Sec. 7 amends RR 2-98 Sec. 2.79(B)(1), which names
  Annex "E" for compensation paid from 1 Jan 2023:
  <https://bir-cdn.bir.gov.ph/local/pdf/RR%20No.%2011-2018.pdf>

Checked against the MONTHLY row of Annex E.

| Row | `over` | `base` | `rate` | Annex E monthly column | Checked | Type |
|---|---|---|---|---|---|---|
| 1 | 0 | 0 | 0 | "₱20,833 and below → 0.00" | 2026-10-14 | Primary |
| 2 | 20833 | 0 | 0.15 | "₱20,833 – ₱33,332 → 0.00 + 15% over ₱20,833" | 2026-10-14 | Primary |
| 3 | 33333 | 1875 | 0.20 | "₱33,333 – ₱66,666 → ₱1,875.00 + 20% over ₱33,333" | 2026-10-14 | Primary |
| 4 | 66667 | 8541.80 | 0.25 | "₱66,667 – ₱166,666 → ₱8,541.80 + 25% over ₱66,667" | 2026-10-14 | Primary |
| 5 | 166667 | 33541.80 | 0.30 | "₱166,667 – ₱666,666 → ₱33,541.80 + 30% over ₱166,667" | 2026-10-14 | Primary |
| 6 | 666667 | 183541.80 | 0.35 | "₱666,667 and above → ₱183,541.80 + 35% over ₱666,667" | 2026-10-14 | Primary |

All six rows match digit for digit. No 2025 or 2026 RR replacing Annex E was found.

## BIR 13th-month exemption: `gem/data/contribution_tables/thirteenth_month.yml`

Source: **RR No. 11-2018, Sec. 6**, amending RR 2-98 Sec. 2.78.1(B)(11), *Thirteenth
month pay and other benefits*:
<https://bir-cdn.bir.gov.ph/local/pdf/RR%20No.%2011-2018.pdf>

| Key | Figure | Where in the source | Circular | Checked | Type |
|---|---|---|---|---|---|
| `exempt_threshold` | 90000 | §2.78.1(B)(11): "the total amount shall not exceed ninety thousand pesos (₱90,000)" | RR 11-2018 | 2026-10-14 | Primary |

The ceiling covers 13th-month pay **and** other benefits (Christmas bonus, productivity
incentives, gifts) combined. The calculator applies all of it to the 13th-month pay.

Nothing has raised the ceiling since. RR 29-2025 (22 Dec 2025) raised de minimis
ceilings only. House Bill 7661, filed Feb 2026, proposes ₱150,000 but is a pending bill,
not law (per news reports, e.g. diskurso.ph, 10 Feb 2026).

## How to re-verify next year

1. Find the issuance index for each agency, and check whether anything newer than the
   circulars above changes a figure:
   - SSS: <https://www.sss.gov.ph/sss-circulars/>
   - PhilHealth: <https://www.philhealth.gov.ph/advisories/> and `/circulars/`
   - Pag-IBIG: <https://www.pagibigfund.gov.ph/>. If the circular PDF is still
     unreachable, fall back to the DBM circular letter that funds the government share.
   - BIR: <https://www.bir.gov.ph/> (Revenue Regulations, by year)
2. Read the figure from the agency's own PDF. Many SSS and PhilHealth PDFs are scans,
   so render the page and read the table rather than trusting extracted text.
3. A changed rate is a **data PR, not a code change**:
   - Add a new `tables:` entry with the new `effective_date` and `source_circular`.
     Keep the old entry so past dates still resolve.
   - Re-derive the affected golden values in `spec/payroll/` by hand from the circular,
     and show the derivation in a spec comment.
   - Add or update this file's rows with the new figure, URL, circular number and check
     date. Mark them Primary or Secondary honestly.
   - Regenerate `examples/`, because each example records the `effective_date` it was
     captured under.
   - Note the change in `CHANGELOG.md`.
4. Run `bundle exec rspec` and `bundle exec ruby bin/validate_tables` before opening the
   PR.
