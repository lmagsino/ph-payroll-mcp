# frozen_string_literal: true

require "bigdecimal"

# Golden values computed from the modeled rules (MSC rounded to ₱500 steps, clamp
# 5k–35k / OFW 8k, regular 5%EE/10%ER, WISP above ₱20,000, EC 10/30 at ₱15,000,
# self/vol/ofw pay the full 15%) — not read from the YAML. When the SSS numbers are
# verified these expected values move with them, but the LOGIC is pinned here.
RSpec.describe Payroll::SssCalculator do
  subject(:calc) { described_class.new }

  def a(result) = result.amounts

  describe "employed" do
    it "splits regular + WISP for a mid salary above the WISP threshold" do
      r = calc.call(monthly_salary: 25_000, member_type: "employed")
      expect(a(r)[:msc]).to eq(BigDecimal("25000"))
      expect(a(r)[:regular_employee]).to eq(BigDecimal("1000.00")) # 20000 * 5%
      expect(a(r)[:regular_employer]).to eq(BigDecimal("2000.00")) # 20000 * 10%
      expect(a(r)[:wisp_employee]).to eq(BigDecimal("250.00"))     # 5000 * 5%
      expect(a(r)[:wisp_employer]).to eq(BigDecimal("500.00"))     # 5000 * 10%
      expect(a(r)[:ec_contribution]).to eq(BigDecimal("30"))       # msc >= 15000
      expect(a(r)[:employee_share]).to eq(BigDecimal("1250.00"))
      expect(a(r)[:employer_share]).to eq(BigDecimal("2530.00"))
      expect(a(r)[:total]).to eq(BigDecimal("3780.00"))
    end

    it "uses the low EC (₱10) below MSC ₱15,000" do
      r = calc.call(monthly_salary: 14_000, member_type: "employed")
      expect(a(r)[:msc]).to eq(BigDecimal("14000"))
      expect(a(r)[:ec_contribution]).to eq(BigDecimal("10"))
      expect(a(r)[:employer_share]).to eq(BigDecimal("1410.00")) # 1400 + 10
    end

    it "has no WISP portion exactly at the ₱20,000 threshold" do
      r = calc.call(monthly_salary: 20_000, member_type: "employed")
      expect(a(r)[:wisp_employee]).to eq(BigDecimal("0"))
      expect(a(r)[:wisp_employer]).to eq(BigDecimal("0"))
    end

    it "clamps to the ₱35,000 ceiling (full WISP band)" do
      r = calc.call(monthly_salary: 60_000, member_type: "employed")
      expect(a(r)[:msc]).to eq(BigDecimal("35000"))
      expect(a(r)[:wisp_employee]).to eq(BigDecimal("750.00")) # 15000 * 5%
      expect(a(r)[:total]).to eq(BigDecimal("5280.00"))
    end

    it "rounds salary to its MSC bracket (₱5,250 -> MSC ₱5,500)" do
      expect(a(calc.call(monthly_salary: 5_250, member_type: "employed"))[:msc]).to eq(BigDecimal("5500"))
    end
  end

  describe "non-employed members pay the full rate with no employer share" do
    it "self_employed pays 15% on the MSC, employer 0, no EC" do
      r = calc.call(monthly_salary: 25_000, member_type: "self_employed")
      expect(a(r)[:employee_share]).to eq(BigDecimal("3750.00")) # 25000 * 15%
      expect(a(r)[:employer_share]).to eq(BigDecimal("0"))
      expect(a(r)[:ec_contribution]).to eq(BigDecimal("0"))
    end

    it "OFW uses the ₱8,000 floor" do
      r = calc.call(monthly_salary: 6_000, member_type: "ofw")
      expect(a(r)[:msc]).to eq(BigDecimal("8000"))
      expect(a(r)[:employee_share]).to eq(BigDecimal("1200.00")) # 8000 * 15%
    end
  end

  it "carries the citation" do
    expect(calc.call(monthly_salary: 25_000, member_type: "employed").source_circular).to match(/SSS/)
  end

  it "rejects invalid input" do
    expect { calc.call(monthly_salary: 25_000, member_type: "gsis") }.to raise_error(Payroll::InvalidInput)
    expect { calc.call(monthly_salary: -1, member_type: "employed") }.to raise_error(Payroll::InvalidInput)
  end
end
