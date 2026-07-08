# frozen_string_literal: true

require "bigdecimal"

# Golden values hand-computed for gross ₱30,000, employed (using the current flagged
# rates), reconciled: taxable = gross - mandatory EE contributions; net = gross -
# contributions - withholding - other. Values move if the underlying rates change, but
# the composition logic (pre-tax contributions, reconciliation) is pinned here.
RSpec.describe Payroll::NetPayCalculator do
  subject(:calc) { described_class.new }

  let(:result) { calc.call(gross_monthly_salary: 30_000, member_type: "employed") }

  it "derives each employee share" do
    expect(result[:sss_employee]).to eq(BigDecimal("1500.00"))       # 20000*5% + 10000*5%
    expect(result[:philhealth_employee]).to eq(BigDecimal("750.00")) # 30000*5% / 2
    expect(result[:pagibig_employee]).to eq(BigDecimal("200.00"))    # capped at 10000*2%
  end

  it "derives taxable income as gross minus mandatory contributions" do
    expect(result[:taxable_income]).to eq(BigDecimal("27550.00")) # 30000 - 2450
  end

  it "computes withholding on the taxable income" do
    expect(result[:withholding_tax]).to eq(BigDecimal("1007.55")) # 0.15*(27550-20833)
  end

  it "reconciles net pay" do
    expect(result[:total_deductions]).to eq(BigDecimal("3457.55")) # 2450 + 1007.55
    expect(result[:net_pay]).to eq(BigDecimal("26542.45"))         # 30000 - 3457.55
  end

  it "keeps a citation for every deduction source" do
    expect(result[:sources].keys).to contain_exactly(:sss, :philhealth, :pagibig, :withholding_tax)
    result[:sources].each_value do |src|
      expect(src[:source_circular]).to be_a(String)
      expect(src[:effective_date]).to be_a(Date)
    end
  end

  it "subtracts other_deductions" do
    r = calc.call(gross_monthly_salary: 30_000, member_type: "employed", other_deductions: 5_000)
    expect(r[:net_pay]).to eq(BigDecimal("21542.45"))
  end

  it "reports a negative net honestly when other_deductions exceed take-home" do
    r = calc.call(gross_monthly_salary: 30_000, member_type: "employed", other_deductions: 50_000)
    expect(r[:net_pay]).to be < 0
  end

  it "rejects invalid input" do
    expect { calc.call(gross_monthly_salary: 30_000, member_type: "gsis") }.to raise_error(Payroll::InvalidInput)
    expect { calc.call(gross_monthly_salary: -1, member_type: "employed") }.to raise_error(Payroll::InvalidInput)
    expect { calc.call(gross_monthly_salary: 30_000, member_type: "employed", other_deductions: -5) }
      .to raise_error(Payroll::InvalidInput)
  end
end
