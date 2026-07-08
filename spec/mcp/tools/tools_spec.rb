# frozen_string_literal: true

require "json"

# Adapter-level tests: tools return clean JSON content, always carry the citation, and
# translate domain errors into a structured payload instead of raising. Full statutory
# math is covered by the calculator specs; the protocol round-trip is M4.
RSpec.describe "MCP tool adapters" do
  def body(result) = JSON.parse(result[:content].first[:text])

  it "registers all seven tools" do
    expect(Tools::ALL.length).to eq(7)
  end

  describe "single-calculator tools carry amounts + citation" do
    it "compute_philhealth_contribution" do
      b = body(Tools::ComputePhilhealthContribution.new.call(monthly_salary: 30_000))
      expect(b["premium"]).to eq(1500.0)
      expect(b["source_circular"]).to match(/PhilHealth/)
    end

    it "compute_sss_contribution" do
      b = body(Tools::ComputeSssContribution.new.call(monthly_salary: 25_000, member_type: "employed"))
      expect(b["employee_share"]).to eq(1250.0)
      expect(b["source_circular"]).to match(/SSS/)
    end

    it "compute_withholding_tax" do
      b = body(Tools::ComputeWithholdingTax.new.call(monthly_taxable_income: 30_000))
      expect(b["withholding_tax"]).to eq(1375.05)
      expect(b["source_circular"]).to match(/BIR|Withholding/i)
    end

    it "compute_13th_month_pay" do
      b = body(Tools::Compute13thMonthPay.new.call(total_basic_salary_earned_this_year: 240_000, months_worked: 12))
      expect(b["thirteenth_month_pay"]).to eq(20_000.0)
    end
  end

  describe "compute_net_pay" do
    it "returns the full payslip with per-source citations" do
      b = body(Tools::ComputeNetPay.new.call(gross_monthly_salary: 30_000, member_type: "employed"))
      expect(b["net_pay"]).to eq(26_542.45)
      expect(b["sources"].keys).to contain_exactly("sss", "philhealth", "pagibig", "withholding_tax")
    end
  end

  describe "get_contribution_table" do
    it "returns the raw table + citation for an agency" do
      b = body(Tools::GetContributionTable.new.call(table: "philhealth"))
      expect(b["agency"]).to eq("philhealth")
      expect(b["data"]).to include("rate")
      expect(b["source_circular"]).to be_a(String)
    end

    it "maps an unknown table to a structured no_rate_table error" do
      b = body(Tools::GetContributionTable.new.call(table: "gsis"))
      expect(b["error"]).to eq("no_rate_table")
    end
  end

  describe "error mapping" do
    it "returns a structured invalid_input error instead of raising" do
      b = body(Tools::ComputePhilhealthContribution.new.call(monthly_salary: -5_000))
      expect(b["error"]).to eq("invalid_input")
      expect(b["message"]).to match(/greater than zero/)
    end

    it "maps an unsupported pay_period" do
      b = body(Tools::ComputeWithholdingTax.new.call(monthly_taxable_income: 30_000, pay_period: "weekly"))
      expect(b["error"]).to eq("invalid_input")
    end
  end

  describe "argument schema accepts JSON integers (not just floats)" do
    it "validates an integer salary through call_with_schema_validation!" do
      result = Tools::ComputePhilhealthContribution.new.call_with_schema_validation!(monthly_salary: 30_000).first
      expect(body(result)["premium"]).to eq(1500.0)
    end
  end
end
