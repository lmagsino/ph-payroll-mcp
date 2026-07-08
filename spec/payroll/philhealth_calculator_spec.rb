# frozen_string_literal: true

require "bigdecimal"

# Golden values are computed independently from the rule (5% of clamped monthly basic,
# split 50/50, floor ₱10,000 / ceiling ₱100,000) — NOT read back from the YAML — so a
# transcription error in the rate table would fail these tests (eng-review D11).
RSpec.describe Payroll::PhilhealthCalculator do
  subject(:calc) { described_class.new }

  def premium(result) = result.amounts[:premium]
  def shares(result) = [result.amounts[:employee_share], result.amounts[:employer_share]]

  it "computes 5% split 50/50 for a mid-range salary" do
    r = calc.call(monthly_salary: 30_000)
    expect(premium(r)).to eq(BigDecimal("1500.00"))
    expect(shares(r)).to eq([BigDecimal("750.00"), BigDecimal("750.00")])
  end

  it "applies the floor: below ₱10,000 → fixed ₱500 premium" do
    expect(premium(calc.call(monthly_salary: 8_000))).to eq(BigDecimal("500.00"))
  end

  it "applies the ceiling: above ₱100,000 → fixed ₱5,000 premium" do
    r = calc.call(monthly_salary: 150_000)
    expect(premium(r)).to eq(BigDecimal("5000.00"))
    expect(shares(r)).to eq([BigDecimal("2500.00"), BigDecimal("2500.00")])
  end

  it "handles the exact floor and ceiling boundaries" do
    expect(premium(calc.call(monthly_salary: 10_000))).to eq(BigDecimal("500.00"))
    expect(premium(calc.call(monthly_salary: 100_000))).to eq(BigDecimal("5000.00"))
  end

  it "reconciles EE + ER to the premium even with an odd centavo" do
    r = calc.call(monthly_salary: 10_001) # premium 500.05, not evenly halved
    ee, er = shares(r)
    expect(ee + er).to eq(premium(r))
    expect(premium(r)).to eq(BigDecimal("500.05"))
  end

  it "carries the citation" do
    expect(calc.call(monthly_salary: 30_000).source_circular).to match(/PhilHealth/)
  end

  it "rejects invalid input" do
    expect { calc.call(monthly_salary: -5_000) }.to raise_error(Payroll::InvalidInput)
    expect { calc.call(monthly_salary: 0) }.to raise_error(Payroll::InvalidInput)
    expect { calc.call(monthly_salary: "abc") }.to raise_error(Payroll::InvalidInput)
  end
end
