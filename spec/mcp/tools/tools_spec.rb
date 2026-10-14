# frozen_string_literal: true

require "json"

require "json_schemer"

# Adapter-level tests: tools return clean JSON content, always carry the citation, and
# translate domain errors into a structured payload instead of raising. Full statutory
# math is covered by the calculator specs; the protocol round-trip is spec/mcp_mount_spec.rb.
RSpec.describe "MCP tool adapters" do
  def body(response) = JSON.parse(response.content.first[:text])

  it "registers all seven tools" do
    expect(Tools::ALL.length).to eq(7)
  end

  describe "single-calculator tools carry amounts + citation" do
    it "compute_philhealth_contribution" do
      b = body(Tools::ComputePhilhealthContribution.call(monthly_salary: 30_000))
      expect(b["premium"]).to eq(1500.0)
      expect(b["source_circular"]).to match(/PhilHealth/)
    end

    it "compute_sss_contribution" do
      b = body(Tools::ComputeSssContribution.call(monthly_salary: 25_000, member_type: "employed"))
      expect(b["employee_share"]).to eq(1250.0)
      expect(b["source_circular"]).to match(/SSS/)
    end

    it "compute_withholding_tax" do
      b = body(Tools::ComputeWithholdingTax.call(monthly_taxable_income: 30_000))
      expect(b["withholding_tax"]).to eq(1375.05)
      expect(b["source_circular"]).to match(/BIR|Withholding/i)
    end

    it "compute_13th_month_pay" do
      b = body(Tools::Compute13thMonthPay.call(total_basic_salary_earned_this_year: 240_000, months_worked: 12))
      expect(b["thirteenth_month_pay"]).to eq(20_000.0)
    end
  end

  describe "compute_net_pay" do
    it "returns the full payslip with per-source citations" do
      b = body(Tools::ComputeNetPay.call(gross_monthly_salary: 30_000, member_type: "employed"))
      expect(b["net_pay"]).to eq(26_542.45)
      expect(b["sources"].keys).to contain_exactly("sss", "philhealth", "pagibig", "withholding_tax")
    end
  end

  describe "get_contribution_table" do
    it "returns the raw table + citation for an agency" do
      b = body(Tools::GetContributionTable.call(table: "philhealth"))
      expect(b["agency"]).to eq("philhealth")
      expect(b["data"]).to include("rate")
      expect(b["source_circular"]).to be_a(String)
    end

    it "maps an unknown table to a structured no_rate_table error" do
      b = body(Tools::GetContributionTable.call(table: "gsis"))
      expect(b["error"]).to eq("no_rate_table")
    end
  end

  describe "error mapping" do
    it "returns a structured invalid_input error instead of raising" do
      response = Tools::ComputePhilhealthContribution.call(monthly_salary: -5_000)
      b = body(response)
      expect(response).to be_error
      expect(b["error"]).to eq("invalid_input")
      expect(b["message"]).to match(/greater than zero/)
    end

    it "maps an unsupported pay_period" do
      b = body(Tools::ComputeWithholdingTax.call(monthly_taxable_income: 30_000, pay_period: "weekly"))
      expect(b["error"]).to eq("invalid_input")
    end
  end

  describe "input schemas" do
    (Tools::ALL - [Tools::GetContributionTable]).each do |tool|
      it "#{tool.tool_name} types every money field as a plain number" do
        money = tool.input_schema.to_h[:properties].select { |_, prop| prop[:type] == "number" }

        expect(money).not_to be_empty
        money.each_value { |prop| expect(prop.keys).not_to include(:not) }
      end
    end

    it "accepts an integer salary (LLMs send integers as often as floats)" do
      schemer = JSONSchemer.schema(Tools::ComputeNetPay.input_schema.to_h)

      expect(schemer.valid?({ "gross_monthly_salary" => 30_000, "member_type" => "employed" })).to be(true)
    end

    it "constrains member_type and table to their enums" do
      expect(Tools::ComputeNetPay.input_schema.to_h.dig(:properties, :member_type, :enum))
        .to eq(PhPayroll::SssCalculator::MEMBER_TYPES)
      expect(Tools::GetContributionTable.input_schema.to_h.dig(:properties, :table, :enum))
        .to contain_exactly("sss", "philhealth", "pagibig", "withholding_tax", "thirteenth_month")
    end
  end
end
