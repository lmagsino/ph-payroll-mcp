# frozen_string_literal: true

require "bigdecimal"

# Golden values computed from the rule (total_basic / 12; exempt up to ₱90,000).
RSpec.describe Payroll::ThirteenthMonthCalculator do
  subject(:calc) { described_class.new }

  def run(total, months = 12) = calc.call(total_basic_salary_earned_this_year: total, months_worked: months)

  it "is fully exempt below the threshold" do
    r = run(240_000)
    expect(r.amounts[:thirteenth_month_pay]).to eq(BigDecimal("20000.00"))
    expect(r.amounts[:tax_exempt_portion]).to eq(BigDecimal("20000.00"))
    expect(r.amounts[:taxable_portion]).to eq(BigDecimal("0"))
  end

  it "taxes the excess above ₱90,000" do
    r = run(1_300_000)
    expect(r.amounts[:thirteenth_month_pay]).to eq(BigDecimal("108333.33"))
    expect(r.amounts[:tax_exempt_portion]).to eq(BigDecimal("90000"))
    expect(r.amounts[:taxable_portion]).to eq(BigDecimal("18333.33"))
  end

  it "is fully exempt exactly at the ₱90,000 boundary" do
    r = run(1_080_000)
    expect(r.amounts[:thirteenth_month_pay]).to eq(BigDecimal("90000.00"))
    expect(r.amounts[:taxable_portion]).to eq(BigDecimal("0"))
  end

  it "carries the citation" do
    expect(run(240_000).source_circular).to match(/13th-month|BIR/i)
  end

  it "rejects invalid months_worked and non-positive total" do
    expect { run(240_000, 0) }.to raise_error(Payroll::InvalidInput)
    expect { run(240_000, 13) }.to raise_error(Payroll::InvalidInput)
    expect { run(240_000, 6.5) }.to raise_error(Payroll::InvalidInput)
    expect { run(-1, 12) }.to raise_error(Payroll::InvalidInput)
  end
end
