# frozen_string_literal: true

require "bigdecimal"

# Golden values computed independently from the rule (EE 1% at ≤₱1,500 else 2%,
# ER 2%, monthly ceiling ₱10,000 → max ₱200/₱200), not from the YAML (D11).
RSpec.describe Payroll::PagibigCalculator do
  subject(:calc) { described_class.new }

  def parts(result)
    a = result.amounts
    [a[:employee_share], a[:employer_share], a[:total]]
  end

  it "uses the low employee rate (1%) at or below ₱1,500" do
    expect(parts(calc.call(monthly_salary: 1_200)))
      .to eq([BigDecimal("12.00"), BigDecimal("24.00"), BigDecimal("36.00")])
  end

  it "treats exactly ₱1,500 as the low bracket (1% EE)" do
    expect(parts(calc.call(monthly_salary: 1_500)))
      .to eq([BigDecimal("15.00"), BigDecimal("30.00"), BigDecimal("45.00")])
  end

  it "uses the standard rate (2%) just above ₱1,500" do
    expect(parts(calc.call(monthly_salary: 1_501)))
      .to eq([BigDecimal("30.02"), BigDecimal("30.02"), BigDecimal("60.04")])
  end

  it "computes 2%/2% for a mid-range salary" do
    expect(parts(calc.call(monthly_salary: 5_000)))
      .to eq([BigDecimal("100.00"), BigDecimal("100.00"), BigDecimal("200.00")])
  end

  it "caps at the ₱10,000 ceiling → ₱200 / ₱200" do
    expect(parts(calc.call(monthly_salary: 50_000)))
      .to eq([BigDecimal("200.00"), BigDecimal("200.00"), BigDecimal("400.00")])
  end

  it "handles the exact ceiling boundary" do
    expect(parts(calc.call(monthly_salary: 10_000)))
      .to eq([BigDecimal("200.00"), BigDecimal("200.00"), BigDecimal("400.00")])
  end

  it "carries the citation" do
    expect(calc.call(monthly_salary: 5_000).source_circular).to match(/HDMF|Pag-IBIG/i)
  end

  it "rejects invalid input" do
    expect { calc.call(monthly_salary: -1) }.to raise_error(Payroll::InvalidInput)
    expect { calc.call(monthly_salary: 0) }.to raise_error(Payroll::InvalidInput)
  end
end
