# frozen_string_literal: true

require "bigdecimal"

# Golden values computed from the monthly RWT formula (base + rate*(income - over))
# using the TRAIN Phase-2 rows — not read from the YAML.
RSpec.describe Payroll::WithholdingTaxCalculator do
  subject(:calc) { described_class.new }

  def tax(income) = calc.call(monthly_taxable_income: income).amounts[:withholding_tax]

  it "is zero in the 0% band" do
    expect(tax(20_000)).to eq(BigDecimal("0"))
    expect(tax(0)).to eq(BigDecimal("0"))
  end

  it "is zero exactly at the ₱20,833 boundary (continuous)" do
    expect(tax(20_833)).to eq(BigDecimal("0"))
  end

  it "applies 15% over ₱20,833" do
    expect(tax(30_000)).to eq(BigDecimal("1375.05")) # 0.15 * (30000 - 20833)
  end

  it "applies the ₱33,333 bracket (base 1,875 + 20%)" do
    expect(tax(50_000)).to eq(BigDecimal("5208.40")) # 1875 + 0.20*(50000-33333)
  end

  it "applies the top bracket (base 183,541.80 + 35%)" do
    expect(tax(700_000)).to eq(BigDecimal("195208.35")) # 183541.80 + 0.35*(700000-666667)
  end

  it "carries the citation" do
    expect(calc.call(monthly_taxable_income: 30_000).source_circular).to match(/BIR|Withholding/i)
  end

  it "rejects an unsupported pay_period and negative income" do
    expect { calc.call(monthly_taxable_income: 30_000, pay_period: "weekly") }.to raise_error(Payroll::InvalidInput)
    expect { calc.call(monthly_taxable_income: -1) }.to raise_error(Payroll::InvalidInput)
  end
end
