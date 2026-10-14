# ph_payroll

Philippine statutory payroll math — SSS, PhilHealth, Pag-IBIG, BIR monthly withholding
tax, 13th-month pay and net pay — computed from versioned rate tables, with every result
cited to the agency circular it came from.

It is the calculator core of [ph-payroll-mcp](https://github.com/lmagsino/ph-payroll-mcp),
the MCP server that gives AI assistants these numbers, packaged for plain Ruby.

## Install

```sh
gem install ph_payroll
```

or in a Gemfile: `gem "ph_payroll"`. Ruby 3.1 or later.

## Usage

Each calculator returns a `PhPayroll::Result`: `BigDecimal` amounts plus the
`effective_date` and `source_circular` of the rate table that produced them.

```ruby
require "ph_payroll"

sss = PhPayroll::SssCalculator.new.call(monthly_salary: 25_000, member_type: "employed")
sss.amounts[:employee_share]  # => 0.125e4 (₱1,250.00)
sss.effective_date            # => #<Date: 2026-01-01>
sss.source_circular           # => "SSS Circular No. 2024-006 (employers and employees), ..."
sss.to_h                      # => 2-decimal floats, ISO date, citation, and an `as_of` sentence

PhPayroll::PhilhealthCalculator.new.call(monthly_salary: 30_000)
PhPayroll::PagibigCalculator.new.call(monthly_salary: 30_000)
PhPayroll::WithholdingTaxCalculator.new.call(monthly_taxable_income: 30_000)
PhPayroll::ThirteenthMonthCalculator.new.call(total_basic_salary_earned_this_year: 1_200_000,
                                              months_worked: 12)
```

A full payslip, each deduction cited under `:sources`:

```ruby
slip = PhPayroll::NetPayCalculator.new.call(gross_monthly_salary: 30_000, member_type: "employed")
slip[:net_pay]          # => 0.2654245e5 (₱26,542.45)
slip[:sources].keys     # => [:sss, :philhealth, :pagibig, :withholding_tax]
```

Every calculator takes `as_of:` (a `Date` or ISO string, default today) and uses the
table in effect on that date. The raw tables are available too:

```ruby
table = PhPayroll::RateTables.for("philhealth", as_of: Date.new(2026, 6, 1))
table.data             # => {"rate"=>"0.05", "floor"=>"10000", "ceiling"=>"100000"}
table.source_circular  # => "PhilHealth Circular No. 2020-0005 (Revision 1), ..."
```

Invalid input raises `PhPayroll::InvalidInput`; a date with no table in effect raises
`PhPayroll::RateTables::MissingRateTable`. Both inherit from `PhPayroll::Error`.

## Member types

`SssCalculator` and `NetPayCalculator` take `member_type`: `employed`, `self_employed`,
`voluntary` or `ofw`. Employed members split the contribution with the employer, who also
pays EC. Self-employed members pay the full rate plus EC; voluntary and OFW members pay the
full rate with no EC.

## Where the numbers come from

The tables ship in `data/contribution_tables/*.yml`, each with its `effective_date` and
`source_circular`. [VERIFICATION.md](https://github.com/lmagsino/ph-payroll-mcp/blob/main/docs/VERIFICATION.md)
records, for every value, the source URL, circular number, the date it was checked, and
whether the source is primary or secondary. A rate change ships as a patch release.

## Disclaimer

Informational and educational use only — not tax, legal, or payroll advice. Verify every
figure against the cited circular before relying on it for remittance or filing.

## License

MIT
