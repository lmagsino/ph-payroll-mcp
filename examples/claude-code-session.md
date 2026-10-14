# Claude Code session against a local server

The end-to-end check that a real MCP client finds the tools, calls them, and quotes the
circulars back. Captured 2026-10-14 with Claude Code 2.1.296 against
`bundle exec rackup` on `main` (rate tables effective 2026-01-01).

Setup: the same server entry `claude mcp add --transport http ph-payroll
http://localhost:9292/mcp` creates, passed per run instead of saved to the user config:

```json
{"mcpServers": {"ph-payroll": {"type": "http", "url": "http://localhost:9292/mcp"}}}
```

```
claude -p "<prompt>" --mcp-config mcp.json --strict-mcp-config --allowedTools "mcp__ph-payroll__*"
claude -p "<follow-up>" --resume <session-id> ...   # turn 2, same session
```

Claude Code connected over Streamable HTTP with no session ID and listed all seven tools.
Claude's answers below are verbatim; Claude Code's own tool-loading steps are omitted.

## Turn 1

**User:** I'm employed in the Philippines and earn ₱30,000 a month. Work out my monthly payslip from gross to net, and tell me which source each deduction comes from.

**Tool call:** `compute_net_pay` `{"gross_monthly_salary":30000,"member_type":"employed"}`

<details><summary>Tool result</summary>

```json
{
  "gross": 30000.0,
  "sss_employee": 1500.0,
  "philhealth_employee": 750.0,
  "pagibig_employee": 200.0,
  "taxable_income": 27550.0,
  "withholding_tax": 1007.55,
  "other_deductions": 0.0,
  "total_deductions": 3457.55,
  "net_pay": 26542.45,
  "sources": {
    "sss": {
      "effective_date": "2026-01-01",
      "source_circular": "SSS Circular No. 2024-006 (employers and employees), with Circulars 2024-008/-009/-010 (self-employed, voluntary, land-based OFW) — schedule effective January 2025"
    },
    "philhealth": {
      "effective_date": "2026-01-01",
      "source_circular": "PhilHealth Circular No. 2020-0005 (Revision 1), as restated by PhilHealth Advisories No. 2025-0002 and 2026-0042"
    },
    "pagibig": {
      "effective_date": "2026-01-01",
      "source_circular": "HDMF Circular No. 460 (15 Jan 2024, effective February 2024) — per secondary sources (DBM Circular Letter No. 2024-2)"
    },
    "withholding_tax": {
      "effective_date": "2026-01-01",
      "source_circular": "BIR Revenue Regulations No. 11-2018, Annex E — Revised Withholding Tax Table effective January 1, 2023 onwards (monthly)"
    }
  }
}
```

</details>

**Claude:**

Here is your monthly payslip at ₱30,000 gross, employed status, no other deductions.

| Line | Amount (₱) |
|---|---|
| Gross monthly salary | 30,000.00 |
| SSS employee share | (1,500.00) |
| PhilHealth employee share | (750.00) |
| Pag-IBIG employee share | (200.00) |
| Taxable income | 27,550.00 |
| BIR withholding tax | (1,007.55) |
| **Total deductions** | **3,457.55** |
| **Net pay** | **26,542.45** |

How each deduction is derived, and where it comes from:

- **SSS, ₱1,500.00.** Your monthly salary credit is ₱30,000 and the employee share is 5% of that. Source is SSS Circular No. 2024-006, the contribution schedule effective January 2025 and still in force for 2026.
- **PhilHealth, ₱750.00.** The premium is 5% of basic salary, which is ₱1,500, split equally with your employer. Source is PhilHealth Circular No. 2020-0005 (Revision 1), as restated by PhilHealth Advisories No. 2025-0002 and 2026-0042.
- **Pag-IBIG, ₱200.00.** The employee rate is 2%, but the fund salary is capped at ₱10,000. Source is HDMF Circular No. 460, effective February 2024, as reported via DBM Circular Letter No. 2024-2.
- **Withholding tax, ₱1,007.55.** Taxable income is gross minus the three mandatory contributions, giving ₱27,550. That falls in the bracket above ₱20,833, taxed at 15% of the excess. Source is BIR Revenue Regulations No. 11-2018, Annex E, the monthly withholding table effective January 2023 onward.

Your employer separately pays its own SSS, PhilHealth, and Pag-IBIG shares, which do not come out of your pay. If you have loans, HMO premiums, or absences, those would reduce the net further.

## Turn 2

**User:** Which circular is the SSS figure from? Pull up the actual SSS table so I can check the rate myself.

**Tool call:** `get_contribution_table` `{"table":"sss"}`

<details><summary>Tool result</summary>

```json
{
  "agency": "sss",
  "effective_date": "2026-01-01",
  "source_circular": "SSS Circular No. 2024-006 (employers and employees), with Circulars 2024-008/-009/-010 (self-employed, voluntary, land-based OFW) — schedule effective January 2025",
  "data": {
    "msc_floor": "5000",
    "msc_ceiling": "35000",
    "msc_step": "500",
    "ofw_msc_floor": "8000",
    "wisp_threshold": "20000",
    "rate_total": "0.15",
    "rate_employer": "0.10",
    "rate_employee": "0.05",
    "ec_low": "10",
    "ec_high": "30",
    "ec_threshold": "15000"
  }
}
```

</details>

**Claude:**

The SSS figure comes from **SSS Circular No. 2024-006**, which sets the employer and employee contribution schedule effective January 2025 and still in force for 2026. Companion circulars 2024-008, 2024-009, and 2024-010 cover self-employed, voluntary, and land-based OFW members, so they do not apply to you.

The payroll tool stores the schedule as rules rather than a printed row-by-row table. Here are those rules, straight from the tool:

| Rule | Value |
|---|---|
| Total contribution rate | 15% of monthly salary credit |
| Employer share | 10% |
| Employee share | 5% |
| MSC floor | ₱5,000 |
| MSC ceiling | ₱35,000 |
| MSC step | ₱500 |
| WISP threshold | MSC above ₱20,000 |
| EC (employer only) | ₱10 if MSC under ₱15,000, else ₱30 |

Applying those rules to your salary gives the rows around ₱30,000 as they appear in the published schedule:

| Salary range | MSC | Regular SS | WISP | Employee (5%) | Employer (10%) | EC |
|---|---|---|---|---|---|---|
| 29,250 – 29,749.99 | 29,500 | 20,000 | 9,500 | 1,475.00 | 2,950.00 | 30 |
| **29,750 – 30,249.99** | **30,000** | **20,000** | **10,000** | **1,500.00** | **3,000.00** | **30** |
| 30,250 – 30,749.99 | 30,500 | 20,000 | 10,500 | 1,525.00 | 3,050.00 | 30 |

Your ₱30,000 lands exactly on the MSC of ₱30,000. Your ₱1,500 employee share breaks down as ₱1,000 regular SS plus ₱500 WISP, the mandatory provident fund that covers MSC above ₱20,000. EC is employer-paid, so it never touches your payslip.

To check against the primary source, open Circular No. 2024-006 on the SSS website under Circulars and find the row covering ₱29,750 to ₱30,249.99.

